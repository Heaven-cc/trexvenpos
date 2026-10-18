import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trexvenpos/src/models/sale.dart';
import 'package:trexvenpos/src/services/offline_cash_queue.dart';
import 'package:trexvenpos/src/services/offline_cash_file.dart';
import 'package:trexvenpos/src/services/offline_session.dart';

void main() {
  late Directory directory;
  late File file;
  late OfflineCashQueue queue;
  final now = DateTime.utc(2026, 10, 9, 9);
  final key = SecretKey(List<int>.filled(32, 7)); // Synthetic fixture only.
  Map<String, dynamic> ticket() => {
    'signature': 'synthetic-server-signature',
    'scope': {
      'version': 1,
      'lease_id': 'lease',
      'device_id': 'device',
      'user_id': 'user',
      'business_id': 'business',
      'membership_id': 'member',
      'branch_id': null,
      'issued_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'expires_at': now.add(const Duration(hours: 23)).toIso8601String(),
      'products': [
        {
          'id': 'product',
          'price': 12.34,
          'unit': 'kg',
          'name': 'Synthetic product',
        },
      ],
    },
  };
  OfflineCashEntry entry(String id) => OfflineCashEntry(
    sale: Sale(
      id: id,
      businessId: 'business',
      employeeId: 'member',
      total: 1.54,
      paymentMethod: 'cash',
      timestamp: now,
      items: const [
        SaleItem(
          productId: 'product',
          quantity: 0.125,
          unitPrice: 12.34,
          total: 1.54,
          priceLevel: 'standard',
        ),
      ],
    ),
    userId: 'user',
    ticket: ticket(),
    occurredAt: now,
  );
  OfflineCashQueue reopen() =>
      OfflineCashQueue(EncryptedOfflineCashStore(file, () async => key));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trexven_cash_test_');
    file = File('${directory.path}/cash.enc');
    queue = reopen();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'encrypted durable entries survive restart, failed sync and explicit receipt recovery',
    () async {
      await queue.enqueue(entry('original-request'), now);
      final encrypted = await file.readAsString();
      expect(encrypted, isNot(contains('original-request')));
      expect(encrypted, isNot(contains('Synthetic product')));
      queue = reopen();
      final pending = (await queue.entries()).single;
      await expectLater(queue.acknowledge(pending.requestId), throwsStateError);
      await expectLater(
        queue.synchronize(
          pending,
          (_) async => throw const SocketException('offline'),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(await file.readAsString(), encrypted);
      var sends = 0;
      final receipt = {
        'id': 'server-receipt',
        'business_id': 'business',
        'employee_id': 'member',
        'total': 1.54,
      };
      await queue.synchronize(pending, (_) async {
        sends++;
        return receipt;
      });
      queue = reopen();
      final recovered = (await queue.entries()).single;
      expect(recovered.receipt, receipt);
      await queue.synchronize(recovered, (_) async {
        sends++;
        return receipt;
      });
      expect(sends, 1);
      await queue.acknowledge('wrong-request');
      expect(await queue.entries(), hasLength(1));
      await queue.acknowledge(pending.requestId);
      expect(await queue.entries(), isEmpty);
    },
  );
  test(
    'concurrent writers and duplicate enqueue retain every original key',
    () async {
      final other = reopen();
      await Future.wait([
        for (var i = 0; i < 10; i++)
          (i.isEven ? queue : other).enqueue(entry('request-$i'), now),
      ]);
      expect(await queue.entries(), hasLength(10));
      await queue.enqueue(entry('request-0'), now);
      expect(await queue.entries(), hasLength(10));
    },
  );
  test(
    'authorization expiry, clock rollback, noncash and forged identities fail closed',
    () async {
      await queue.enqueue(entry('valid'), now);
      final before = await file.readAsString();
      await expectLater(
        queue.enqueue(entry('expired'), now.add(const Duration(days: 1))),
        throwsStateError,
      );
      await expectLater(
        queue.enqueue(entry('clock'), now.subtract(const Duration(seconds: 1))),
        throwsStateError,
      );
      final bad = entry('identity');
      bad.ticket['scope']['user_id'] = 'forged';
      await expectLater(queue.enqueue(bad, now), throwsStateError);
      final noncash = OfflineCashEntry(
        sale: entry('noncash').sale.copyWith(paymentMethod: 'bank_transfer'),
        userId: 'user',
        ticket: ticket(),
        occurredAt: now,
      );
      await expectLater(queue.enqueue(noncash, now), throwsStateError);
      expect(await file.readAsString(), before);
    },
  );
  test(
    'tamper authentication and unknown envelope version preserve damaged data',
    () async {
      await queue.enqueue(entry('tamper'), now);
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final cipher = base64Decode(envelope['cipher'] as String);
      cipher[0] ^= 1;
      envelope['cipher'] = base64Encode(cipher);
      await file.writeAsString(jsonEncode(envelope));
      final tampered = await file.readAsString();
      await expectLater(queue.entries(), throwsA(anything));
      expect(await file.readAsString(), tampered);
      envelope['version'] = 2;
      await file.writeAsString(jsonEncode(envelope));
      final future = await file.readAsString();
      await expectLater(queue.entries(), throwsStateError);
      expect(await file.readAsString(), future);
    },
  );
  test('wrong server receipt is never acknowledged or removed', () async {
    await queue.enqueue(entry('receipt-context'), now);
    await expectLater(
      queue.synchronize(
        (await queue.entries()).single,
        (_) async => {
          'id': 'receipt',
          'business_id': 'forged-business',
          'employee_id': 'member',
        },
      ),
      throwsStateError,
    );
    expect((await queue.entries()).single.receipt, isNull);
  });
  test(
    'encrypted lease and exact context survive restart for cash only',
    () async {
      final context = {
        'employee': {
          'id': 'employee',
          'membership_id': 'member',
          'user_id': 'user',
          'business_id': 'business',
          'role': 'sales_employee',
          'status': 'active',
          'permissions': ['complete_sales', 'pos_access'],
        },
        'business': {
          'id': 'business',
          'owner_id': 'owner',
          'business_name': 'Synthetic',
        },
      };
      await queue.store.mutate((state) => state['device_id'] = 'device');
      await queue.cacheTicket(ticket(), now, authContext: context);
      queue = reopen();
      expect(await resumeOfflineCashContext(queue.store, 'user', now), context);
      expect(
        await resumeOfflineCashContext(queue.store, 'other-user', now),
        isNull,
      );
      expect(
        await resumeOfflineCashContext(
          queue.store,
          'user',
          now.add(const Duration(days: 1)),
        ),
        isNull,
      );
      expect(
        await resumeOfflineCashContext(
          queue.store,
          'user',
          now.subtract(const Duration(seconds: 1)),
        ),
        isNull,
      );
      await queue.store.mutate((state) => state['device_id'] = 'other-device');
      expect(await resumeOfflineCashContext(queue.store, 'user', now), isNull);
    },
  );
  test(
    'legacy cash ticket without trusted context cannot grant a restored session',
    () async {
      await queue.cacheTicket(ticket(), now);
      expect(
        await resumeOfflineCashContext(reopen().store, 'user', now),
        isNull,
      );
      expect(await queue.ticket(), isNotNull);
    },
  );
}
