import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexvenpos/src/models/sale.dart';
import 'package:trexvenpos/src/services/pending_sale.dart';
import 'package:trexvenpos/src/services/pending_sale_file.dart';

final sale = Sale(
  id: 'original-request',
  businessId: 'original-business',
  branchId: 'original-branch',
  employeeId: 'original-membership',
  total: 10,
  paymentMethod: 'Cash',
  timestamp: _timestamp,
  items: const [
    SaleItem(
      productId: 'product',
      quantity: 1,
      unitPrice: 10,
      total: 10,
      priceLevel: 'standard',
    ),
  ],
);
final _timestamp = DateTime.utc(2026, 10, 8);

void main() {
  test(
    'verified legacy payment enrichment survives restart with the original identity',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trexven-payment-upgrade-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/pending.json');
      final store = FilePendingSaleStore(file);
      final original = PendingSale(
        'original-user',
        sale.copyWith(paymentMethod: 'Transfer'),
      );
      await store.save(original);
      final upgraded = await PendingSaleSubmission(store).confirmLegacyPayment(
        original,
        [
          {
            'method': 'bank_transfer',
            'amount': 10,
            'confirmed': true,
            'evidence': 'synthetic-bank-reference',
          },
        ],
        null,
      );
      final restarted = (await FilePendingSaleStore(file).read())!;
      expect(restarted.sale.id, original.sale.id);
      expect(restarted.sale.employeeId, original.sale.employeeId);
      expect(restarted.sale.branchId, original.sale.branchId);
      expect(restarted.sale.timestamp, original.sale.timestamp);
      expect(
        restarted.sale.payments!.single['evidence'],
        'synthetic-bank-reference',
      );
      expect(restarted.sale.total, upgraded.total);
      await expectLater(
        PendingSaleSubmission(store).confirmLegacyPayment(original, [], null),
        throwsStateError,
      );
    },
  );
  test(
    'payment enrichment cannot replace the original cart or business',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trexven-payment-forgery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = FilePendingSaleStore(
        File('${directory.path}/pending.json'),
      );
      final original = PendingSale('original-user', sale);
      await store.save(original);
      final forged = PendingSale(
        'original-user',
        Sale.fromJson({
          ...sale.toJsonWithItems(),
          'business_id': 'other-business',
          'payments': [
            {'method': 'cash', 'amount': 10, 'confirmed': true},
          ],
        }),
      );
      await expectLater(
        store.upgradePayment(original, forged),
        throwsStateError,
      );
      expect((await store.read())!.sale.businessId, sale.businessId);
    },
  );
  test(
    'legacy v1 journal survives an app update without changing request or membership IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trexven-upgrade-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/trexven_pending_sale_v1.json');
      const legacy =
          '{"version":1,"user_id":"original-user","sale":{"id":"legacy-request","business_id":"original-business","employee_id":"original-membership","total":10,"payment_method":"Cash","created_at":"2026-10-08T00:00:00.000Z","sale_items":[{"product_id":"product","quantity":1,"unit_price":10,"discount":0,"total":10,"price_level":"standard"}]}}';
      await file.writeAsString(legacy, flush: true);
      final updatedStore = FilePendingSaleStore(file);
      final restored = (await updatedStore.read())!;
      expect(restored.sale.id, 'legacy-request');
      expect(restored.sale.branchId, isNull);
      expect(
        restored.belongsTo(
          'original-user',
          'original-business',
          'original-membership',
        ),
        isTrue,
      );
      expect(restored.sale.items.single.quantity, 1);
      expect(await file.readAsString(), legacy);
      await expectLater(
        updatedStore.acknowledge('different-request'),
        throwsStateError,
      );
      expect(await file.readAsString(), legacy);
      await PendingSaleSubmission(updatedStore).submit(
        userId: restored.userId,
        sale: restored.sale,
        send: (request) async {
          expect(request.id, 'legacy-request');
          expect(request.employeeId, 'original-membership');
          return request.copyWith(id: 'recovered-receipt');
        },
      );
      expect(await file.readAsString(), legacy);
      await updatedStore.acknowledge('legacy-request');
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'unrecognized journal is retained and fails closed during an update',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trexven-upgrade-corrupt-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/trexven_pending_sale_v1.json');
      const original = '{"version":2,"user_id":"original-user","sale":{}}';
      await file.writeAsString(original, flush: true);
      final store = FilePendingSaleStore(file);
      await expectLater(store.read(), throwsFormatException);
      expect(await file.readAsString(), original);
      await expectLater(
        store.acknowledge('legacy-request'),
        throwsFormatException,
      );
      expect(await file.readAsString(), original);
    },
  );

  const phase = String.fromEnvironment(
    'PENDING_RESTART_PHASE',
    defaultValue: 'unit',
  );
  test(
    'payment journals survive both authorization and validation rejection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trexven-rejection-test-',
      );
      final store = FilePendingSaleStore(
        File('${directory.path}/pending.json'),
      );
      final submission = PendingSaleSubmission(store);
      const denied = PostgrestException(
        message: 'Sale permission denied',
        code: '42501',
      );
      await expectLater(
        submission.submit(
          userId: 'original-user',
          sale: sale,
          send: (_) async => throw denied,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect((await store.read())!.sale.id, sale.id);
      await expectLater(
        submission.submit(
          userId: 'original-user',
          sale: sale,
          send: (_) async => throw denied,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(await store.read(), isNotNull);
      const priceChanged = PostgrestException(
        message: 'Product is pending, inactive or price changed',
        code: 'P0001',
      );
      await expectLater(
        submission.submit(
          userId: 'original-user',
          sale: sale,
          send: (_) async => throw priceChanged,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect((await store.read())!.sale.id, sale.id);
      await directory.delete(recursive: true);
    },
  );
  test(
    'journal flushes before submission and survives a fresh process',
    () async {
      final path = phase == 'unit'
          ? '${(await Directory.systemTemp.createTemp('trexven-pending-test-')).path}/pending.json'
          : '.batch2-tools/pending-restart/pending.json';
      final store = FilePendingSaleStore(File(path));
      final submission = PendingSaleSubmission(store);
      final evidence = File('$path.pid');
      if (phase == 'after') {
        final before = jsonDecode(await evidence.readAsString());
        expect(pid, isNot(before['pid']));
        final restored = (await store.read())!;
        expect(restored.sale.id, sale.id);
        expect(restored.sale.businessId, sale.businessId);
        expect(restored.sale.branchId, sale.branchId);
        expect(restored.sale.employeeId, sale.employeeId);
        expect(restored.userId, 'original-user');
        final receipt = await submission.submit(
          userId: restored.userId,
          sale: restored.sale,
          send: (request) async {
            expect(request.id, sale.id);
            return request.copyWith(id: 'original-receipt');
          },
        );
        expect(receipt.id, 'original-receipt');
        await store.acknowledge(sale.id);
        expect(await store.read(), isNull);
        await evidence.delete();
      } else {
        await expectLater(
          submission.submit(
            userId: 'original-user',
            sale: sale,
            send: (request) async {
              expect((await store.read())!.sale.id, request.id);
              throw const SocketException('Interrupted after dispatch');
            },
          ),
          throwsA(isA<SocketException>()),
        );
        await expectLater(
          submission.submit(
            userId: 'other-user',
            sale: sale,
            send: (_) async => throw StateError('Must never dispatch'),
          ),
          throwsStateError,
        );
        await expectLater(
          submission.submit(
            userId: 'original-user',
            sale: sale.copyWith(businessId: 'other-business'),
            send: (_) async => throw StateError('Must never dispatch'),
          ),
          throwsStateError,
        );
        final switchedBranch = Sale.fromJson({
          ...sale.toJsonWithItems(),
          'branch_id': 'other-branch',
        });
        await expectLater(
          submission.submit(
            userId: 'original-user',
            sale: switchedBranch,
            send: (_) async => throw StateError('Must never dispatch'),
          ),
          throwsStateError,
        );
        if (phase == 'before') {
          await evidence.writeAsString(jsonEncode({'pid': pid}), flush: true);
        } else {
          await store.acknowledge(sale.id);
          await File(path).parent.delete();
        }
      }
    },
  );
}
