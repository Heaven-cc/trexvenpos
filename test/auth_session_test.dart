import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/auth/permission_service.dart';

// Synthetic transport only. The test never contacts a Supabase project.
Map<String, dynamic> sessionJson(String user) {
  String encode(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.${encode({'sub': user, 'exp': 4102444800})}.synthetic',
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': user,
      'aud': 'authenticated',
      'role': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {'role': 'owner', 'business_id': 'forged'},
    },
  };
}

Map<String, dynamic> contextJson({
  String user = 'user',
  String business = 'business',
  String role = 'sales_employee',
  String status = 'active',
  List<String> denied = const [],
}) => {
  'business': {
    'id': business,
    'owner_id': role == 'owner' ? user : 'owner',
    'business_name': 'Synthetic $business',
    'currency': 'NGN',
  },
  'employee': {
    'id': 'employee-$business',
    'membership_id': 'member-$business',
    'user_id': user,
    'business_id': business,
    'name': 'Synthetic employee',
    'employee_code': 'TEST',
    'role': role,
    'status': status,
    'permissions': ['pos_access', 'complete_sales', 'view_inventory'],
    'denied_permissions': denied,
  },
};

class Transport {
  List<Map<String, dynamic>> contexts = [contextJson()];
  final calls = <Map<String, dynamic>>[];
  Completer<List<Map<String, dynamic>>>? pendingContexts;
  Completer<void>? pendingLogin;
  String loginUser = 'user';
  Object? rpcFailure;
  int? rpcStatus;
  late final client = SupabaseClient(
    'https://example.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      Object body;
      if (request.url.path.endsWith('/rpc/get_trexven_pos_context')) {
        calls.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
        if (rpcFailure != null) throw rpcFailure!;
        if (rpcStatus != null)
          return http.Response(
            jsonEncode({'code': '42501', 'message': 'Denied'}),
            rpcStatus!,
            headers: {'content-type': 'application/json'},
          );
        body = pendingContexts == null
            ? contexts
            : await pendingContexts!.future;
      } else if (request.url.path.endsWith('/token')) {
        if (pendingLogin != null) await pendingLogin!.future;
        body = sessionJson(loginUser);
      } else if (request.url.path.endsWith('/logout')) {
        return http.Response('', 204, request: request);
      } else {
        throw StateError('Unexpected synthetic request: ${request.url.path}');
      }
      return http.Response(
        jsonEncode(body),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

Future<void> settleUntil(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(done(), isTrue, reason: 'Expected authentication operation to settle');
}

void main() {
  test(
    'Restored session retrieves trusted context and ignores editable metadata',
    () async {
      final transport = Transport();
      await transport.client.auth.setInitialSession(
        jsonEncode(sessionJson('user')),
      );
      final auth = AuthNotifier(transport.client);
      await settleUntil(() => !auth.state.isLoading);
      expect(auth.state.employee?.membershipId, 'member-business');
      expect(auth.state.activeBusiness?.id, 'business');
      expect(PermissionService(auth.state.employee).isOwner, isFalse);
      expect(transport.calls.single, {'p_business_id': null});
      auth.dispose();
      await transport.client.dispose();
    },
  );

  test(
    'Revoked permissions replace previous defaults on revalidation',
    () async {
      final transport = Transport();
      await transport.client.auth.setInitialSession(
        jsonEncode(sessionJson('user')),
      );
      final auth = AuthNotifier(transport.client, observeSession: false);
      await auth.restoreSession();
      expect(PermissionService(auth.state.employee).canCompleteSales, isTrue);
      transport.contexts = [
        contextJson(denied: ['complete_sales']),
      ];
      await auth.restoreSession();
      expect(PermissionService(auth.state.employee).canCompleteSales, isFalse);
      transport.contexts = [];
      await auth.restoreSession();
      expect(auth.state.employee, isNull);
      expect(auth.state.activeBusiness, isNull);
      expect(auth.state.error, contains('Pending transactions are retained'));
      auth.dispose();
      await transport.client.dispose();
    },
  );

  for (final invalid in [
    'unknown_role',
    'inactive',
    'wrong_user',
    'wrong_business',
    'false_owner',
    'empty_member',
  ]) {
    test('Rejects invalid context: $invalid', () async {
      final transport = Transport();
      final row = contextJson();
      final employee = row['employee'] as Map<String, dynamic>;
      switch (invalid) {
        case 'unknown_role':
          employee['role'] = 'root';
        case 'inactive':
          employee['status'] = 'inactive';
        case 'wrong_user':
          employee['user_id'] = 'another-user';
        case 'wrong_business':
          employee['business_id'] = 'another-business';
        case 'false_owner':
          employee['role'] = 'owner';
        case 'empty_member':
          employee['membership_id'] = '';
      }
      transport.contexts = [row];
      await transport.client.auth.setInitialSession(
        jsonEncode(sessionJson('user')),
      );
      final auth = AuthNotifier(transport.client, observeSession: false);
      await auth.restoreSession();
      expect(auth.state.employee, isNull);
      expect(auth.state.contexts, isEmpty);
      auth.dispose();
      await transport.client.dispose();
    });
  }

  test(
    'Requested business cannot be substituted by another response context',
    () async {
      final transport = Transport();
      await transport.client.auth.setInitialSession(
        jsonEncode(sessionJson('user')),
      );
      final auth = AuthNotifier(transport.client, observeSession: false);
      await auth.restoreSession(businessId: 'forged');
      expect(transport.calls.single['p_business_id'], 'forged');
      expect(auth.state.employee, isNull);
      auth.dispose();
      await transport.client.dispose();
    },
  );

  test(
    'Owner sign-in requires explicit selection among owned businesses',
    () async {
      final transport = Transport()
        ..contexts = [
          contextJson(role: 'owner', business: 'a'),
          contextJson(role: 'owner', business: 'b'),
          contextJson(business: 'staff-business'),
        ];
      final auth = AuthNotifier(transport.client);
      await auth.loginOwner('synthetic@example.invalid', 'synthetic-password');
      expect(auth.state.employee, isNull);
      expect(auth.state.contexts, hasLength(2));
      transport.contexts = [contextJson(role: 'owner', business: 'b')];
      await auth.restoreSession(businessId: 'b');
      expect(auth.state.activeBusiness?.id, 'b');
      expect(PermissionService(auth.state.employee).isOwner, isTrue);
      auth.dispose();
      await transport.client.dispose();
    },
  );

  test(
    'Owner sign-in cannot accept an employee context or forge a choice',
    () async {
      final transport = Transport();
      final auth = AuthNotifier(transport.client);
      await auth.loginOwner('synthetic@example.invalid', 'synthetic-password');
      expect(auth.state.employee, isNull);
      expect(auth.state.contexts, isEmpty);
      await auth.restoreSession(businessId: 'business');
      expect(auth.state.employee, isNull);
      auth.dispose();
      await transport.client.dispose();
    },
  );

  test('Late context response cannot restore a signed-out actor', () async {
    final transport = Transport()..pendingContexts = Completer();
    await transport.client.auth.setInitialSession(
      jsonEncode(sessionJson('user')),
    );
    final auth = AuthNotifier(transport.client, observeSession: false);
    final restore = auth.restoreSession();
    await settleUntil(() => transport.calls.isNotEmpty);
    await auth.logout();
    transport.pendingContexts!.complete([contextJson()]);
    await restore;
    expect(auth.state.employee, isNull);
    expect(transport.client.auth.currentSession, isNull);
    auth.dispose();
    await transport.client.dispose();
  });

  test(
    'Late password response cannot restore a session after sign-out',
    () async {
      final transport = Transport()..pendingLogin = Completer();
      final auth = AuthNotifier(transport.client);
      final login = auth.loginOwner(
        'synthetic@example.invalid',
        'synthetic-password',
      );
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      transport.pendingLogin!.complete();
      await login;
      expect(auth.state.employee, isNull);
      expect(transport.client.auth.currentSession, isNull);
      expect(transport.calls, isEmpty);
      auth.dispose();
      await transport.client.dispose();
    },
  );

  test(
    'Transport failure permits only bounded cash context, then requires live restoration',
    () async {
      final transport = Transport()
        ..rpcFailure = const SocketException('Synthetic offline');
      await transport.client.auth.setInitialSession(
        jsonEncode(sessionJson('user')),
      );
      final auth = AuthNotifier(
        transport.client,
        observeSession: false,
        offlineContext: (user) async => contextJson(user: user, role: 'owner'),
      );
      await auth.restoreSession();
      expect(auth.state.offlineCashOnly, isTrue);
      final access = PermissionService(
        auth.state.employee,
        offlineCashOnly: true,
      );
      expect(access.canCompleteSales, isTrue);
      expect(access.isOwner, isFalse);
      expect(access.canOverridePrice, isFalse);
      expect(access.hasPermission('view_inventory'), isFalse);
      transport.rpcFailure = null;
      await auth.restoreSession();
      expect(auth.state.offlineCashOnly, isFalse);
      expect(auth.state.employee?.membershipId, 'member-business');
      auth.dispose();
      await transport.client.dispose();
    },
  );

  for (final rejected in ['denied', 'revoked', 'invalid']) {
    test(
      'Authoritative $rejected response cannot fall back to a cached lease',
      () async {
        final transport = Transport();
        if (rejected == 'denied') transport.rpcStatus = 403;
        if (rejected == 'revoked') transport.contexts = [];
        if (rejected == 'invalid')
          transport.contexts = [contextJson(user: 'another')];
        await transport.client.auth.setInitialSession(
          jsonEncode(sessionJson('user')),
        );
        var offlineCalls = 0;
        final auth = AuthNotifier(
          transport.client,
          observeSession: false,
          offlineContext: (user) async {
            offlineCalls++;
            return contextJson(user: user);
          },
        );
        await auth.restoreSession();
        expect(auth.state.employee, isNull);
        expect(auth.state.offlineCashOnly, isFalse);
        expect(offlineCalls, 0);
        auth.dispose();
        await transport.client.dispose();
      },
    );
  }
}
