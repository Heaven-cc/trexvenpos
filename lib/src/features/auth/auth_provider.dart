import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase
    show AuthState;

import '../../models/employee.dart';
import '../../models/business.dart';
import '../../services/offline_session.dart';
import '../../services/network_failure.dart'
    if (dart.library.io) '../../services/network_failure_native.dart'
    as network;

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(supabaseProvider),
    offlineContext: loadOfflineCashContext,
  );
});

class AuthState {
  final bool isLoading;
  final Employee? employee;
  final Business? activeBusiness;
  final String? error;
  final List<Map<String, dynamic>> contexts;
  final bool offlineCashOnly;

  AuthState({
    this.isLoading = false,
    this.employee,
    this.activeBusiness,
    this.error,
    this.contexts = const [],
    this.offlineCashOnly = false,
  });

  AuthState copyWith({
    bool? isLoading,
    Employee? employee,
    Business? activeBusiness,
    String? error,
    bool clearEmployee = false,
    bool clearBusiness = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      employee: clearEmployee ? null : (employee ?? this.employee),
      activeBusiness: clearBusiness
          ? null
          : (activeBusiness ?? this.activeBusiness),
      error: clearError ? null : error,
      contexts: contexts,
      offlineCashOnly: offlineCashOnly,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;
  StreamSubscription<supabase.AuthState>? _authEvents;
  int _generation = 0;
  bool _signingIn = false;
  bool _ownerOnly = false;
  final Future<Map<String, dynamic>?> Function(String userId)? _offlineContext;

  AuthNotifier(
    this._supabase, {
    bool observeSession = true,
    Future<Map<String, dynamic>?> Function(String userId)? offlineContext,
  }) : _offlineContext = offlineContext,
       super(AuthState()) {
    if (!observeSession) return;
    _authEvents = _supabase.auth.onAuthStateChange.listen(
      (event) {
        if (event.event == AuthChangeEvent.signedOut) {
          _generation++;
          if (mounted) state = AuthState();
        } else if (!_signingIn &&
            (event.event == AuthChangeEvent.tokenRefreshed ||
                event.event == AuthChangeEvent.signedIn ||
                event.event == AuthChangeEvent.userUpdated)) {
          unawaited(restoreSession());
        }
      },
      onError: (Object error, StackTrace stack) {
        _generation++;
        if (mounted) {
          state = AuthState(error: _verificationError);
          if (!_signingIn) unawaited(restoreSession());
        }
      },
    );
    if (_supabase.auth.currentSession != null) unawaited(restoreSession());
  }

  Future<void> restoreSession({String? businessId, bool? ownerOnly}) async {
    final generation = ++_generation;
    final user = _supabase.auth.currentUser?.id;
    if (user == null) {
      if (mounted) state = AuthState();
      return;
    }
    if (!mounted) return;
    if (ownerOnly != null) _ownerOnly = ownerOnly;
    final selected = businessId ?? state.activeBusiness?.id;
    state = AuthState(isLoading: true);
    try {
      final response = await _supabase.rpc(
        'get_trexven_pos_context',
        params: {'p_business_id': selected},
      );
      if (!mounted ||
          generation != _generation ||
          user != _supabase.auth.currentUser?.id) {
        return;
      }
      var contexts = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      for (final context in contexts) {
        _validateContext(context, user, selected);
      }
      if (_ownerOnly) {
        contexts = contexts
            .where((row) => (row['employee'] as Map)['role'] == 'owner')
            .toList();
      }
      if (contexts.isEmpty) {
        throw StateError('No active authorized POS membership.');
      }
      if (contexts.length > 1) {
        state = AuthState(
          contexts: contexts,
          error: 'Select your authorized business.',
        );
        return;
      }
      final context = contexts.single;
      final employee = Employee.fromJson(
        Map<String, dynamic>.from(context['employee'] as Map),
      );
      final business = Business.fromJson(
        Map<String, dynamic>.from(context['business'] as Map),
      );
      state = AuthState(
        employee: employee,
        activeBusiness: business,
        contexts: contexts,
      );
    } catch (error) {
      if (mounted &&
          generation == _generation &&
          user == _supabase.auth.currentUser?.id &&
          (error is TimeoutException ||
              error is http.ClientException ||
              network.isNetworkFailure(error))) {
        try {
          final cached = await _offlineContext?.call(user);
          if (!mounted ||
              generation != _generation ||
              user != _supabase.auth.currentUser?.id)
            return;
          if (cached != null) {
            _validateContext(cached, user, selected);
            final employee = Employee.fromJson(
              Map<String, dynamic>.from(cached['employee'] as Map),
            );
            if (_ownerOnly && employee.role != EmployeeRole.owner)
              throw StateError('Owner required');
            state = AuthState(
              employee: employee,
              activeBusiness: Business.fromJson(
                Map<String, dynamic>.from(cached['business'] as Map),
              ),
              offlineCashOnly: true,
            );
            return;
          }
        } catch (_) {
          // Invalid or unavailable authenticated storage stays closed.
        }
      }
      if (mounted && generation == _generation) {
        state = AuthState(error: _verificationError);
      }
    }
  }

  Future<void> loginOwner(String email, String password) async {
    if (_signingIn) return;
    _signingIn = true;
    _ownerOnly = true;
    final generation = ++_generation;
    state = AuthState(isLoading: true);
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (!await _retainLogin(generation, response.user?.id)) return;
      await restoreSession(ownerOnly: true);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = AuthState(
          error: 'Owner sign-in failed. Check your details and connection.',
        );
      }
    } finally {
      _signingIn = false;
    }
  }

  static const _verificationError =
      'Unable to verify your current access. Connect and retry sign-in. Pending transactions are retained.';

  void _validateContext(
    Map<String, dynamic> context,
    String user,
    String? selected,
  ) {
    final employeeJson = Map<String, dynamic>.from(context['employee'] as Map);
    final employee = Employee.fromJson(employeeJson);
    final business = Business.fromJson(
      Map<String, dynamic>.from(context['business'] as Map),
    );
    const roles = {
      'owner',
      'manager',
      'sales_employee',
      'inventory_employee',
      'employee',
    };
    if (!roles.contains(employeeJson['role']) ||
        !employee.isActive ||
        !employee.canAccessPOS ||
        employee.id.isEmpty ||
        employee.membershipId.isEmpty ||
        employee.userId != user ||
        business.id.isEmpty ||
        employee.businessId != business.id ||
        (selected != null && selected != business.id) ||
        (employee.role == EmployeeRole.owner && business.ownerId != user)) {
      throw StateError('Invalid authenticated business context.');
    }
  }

  // A completed HTTP sign-in must not resurrect a session after sign-out or
  // disposal. No journal or encryption key is touched by authentication.
  Future<bool> _retainLogin(int generation, String? userId) async {
    if (mounted && generation == _generation) return true;
    if (userId != null && _supabase.auth.currentUser?.id == userId) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
    return false;
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_authEvents?.cancel());
    super.dispose();
  }

  // ============================================================
  // EMPLOYEE LOGIN
  // ============================================================

  Future<void> login(String employeeId, String password) async {
    if (_signingIn) return;
    _signingIn = true;
    _ownerOnly = false;
    final generation = ++_generation;
    state = AuthState(isLoading: true);

    try {
      final cleanEmployeeId = employeeId.trim().toUpperCase();
      final cleanPassword = password;

      if (cleanEmployeeId.isEmpty) {
        _setError('Enter your Employee ID');
        return;
      }

      if (cleanPassword.isEmpty) {
        _setError('Enter your password');
        return;
      }

      final response = await _supabase.functions.invoke(
        'employee-login',
        body: {'employee_id': cleanEmployeeId, 'password': cleanPassword},
      );
      if (!mounted || generation != _generation) return;

      if (response.status != 200) {
        String message = 'Invalid Employee ID or password';

        if (response.data is Map) {
          final errorData = Map<String, dynamic>.from(response.data as Map);

          final serverError = errorData['error']?.toString();

          if (serverError != null && serverError.isNotEmpty) {
            message = serverError;
          }
        }

        _setError(message);
        return;
      }

      if (response.data == null || response.data is! Map) {
        _setError('Login failed: Invalid server response');
        return;
      }

      final data = Map<String, dynamic>.from(response.data as Map);

      if (data['success'] != true) {
        _setError(data['error']?.toString() ?? 'Unable to login');
        return;
      }

      final employeeData = data['employee'];
      if (employeeData == null || employeeData is! Map) {
        _setError('Login succeeded but employee information is invalid.');
        return;
      }

      final employeeJson = Map<String, dynamic>.from(employeeData);
      final membership = data['membership'];
      if (membership is! Map || membership['id'] == null) {
        throw StateError('Employee membership is missing.');
      }
      employeeJson['membership_id'] = membership['id'];
      final employee = Employee.fromJson(employeeJson);
      if (!employee.isActive) throw StateError('Employee account is inactive.');

      final businessData = data['business'];
      if (businessData == null || businessData is! Map) {
        _setError('Login succeeded but business information is invalid.');
        return;
      }

      final businessJson = Map<String, dynamic>.from(businessData);
      final business = Business.fromJson(businessJson);
      if (business.id.isEmpty || business.id != employee.businessId) {
        throw StateError(
          'Employee business does not match the login response.',
        );
      }

      final sessionData = data['session'];
      if (sessionData != null && sessionData is Map) {
        final sessionJson = Map<String, dynamic>.from(sessionData);
        final refreshToken = sessionJson['refresh_token']?.toString();

        if (refreshToken != null && refreshToken.isNotEmpty) {
          final session = await _supabase.auth.setSession(refreshToken);
          if (!await _retainLogin(generation, session.user?.id)) return;
          if (session.user?.id != employee.userId) {
            await _supabase.auth.signOut(scope: SignOutScope.local);
            throw StateError('Authenticated employee identity mismatch.');
          }
        } else {
          throw StateError('Login returned no session.');
        }
      } else {
        throw StateError('Login returned no session.');
      }

      await restoreSession(businessId: business.id);
    } on FunctionsHttpException catch (e) {
      if (!mounted || generation != _generation) return;
      String message = 'Unable to login';
      if (e.details is Map) {
        final details = Map<String, dynamic>.from(e.details as Map);
        final serverError = details['error']?.toString();
        if (serverError != null && serverError.isNotEmpty) {
          message = serverError;
        }
      }
      _setError(message);
    } on PostgrestException {
      if (mounted && generation == _generation)
        _setError('Unable to verify employee access. Please retry.');
    } on AuthException {
      if (mounted && generation == _generation)
        _setError('Authentication failed. Check your details and connection.');
    } catch (e) {
      if (mounted && generation == _generation)
        _setError('Login failed. Please try again.');
    } finally {
      _signingIn = false;
    }
  }

  void _setError(String message) {
    state = state.copyWith(isLoading: false, error: message);
  }

  void selectBusiness(Business business) {
    if (state.employee == null ||
        !state.employee!.isActive ||
        state.employee!.businessId != business.id) {
      throw StateError('You are not assigned to this business.');
    }
    state = state.copyWith(activeBusiness: business);
  }

  Future<void> logout() async {
    _generation++;
    _ownerOnly = false;
    if (mounted) state = AuthState();
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Ignore logout errors
    }
  }
}
