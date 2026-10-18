import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:trexvenpos/src/features/pos/sales_repository.dart';
import 'package:trexvenpos/src/models/sale.dart';
import 'package:trexvenpos/src/services/pending_sale.dart';
import 'package:trexvenpos/src/services/pending_sale_file.dart';

void main() {
  const phase = String.fromEnvironment('LIVE_RESTART_PHASE');
  const fixturePath = String.fromEnvironment(
    'LIVE_RESTART_FIXTURE',
    defaultValue: '.batch2-tools/batch9_live_restart_fixture.json',
  );
  test(
    'real persisted restart retries the original RPC once without duplicate stock or receipt',
    () async {
      final fixture = jsonDecode(
        await File(fixturePath).readAsString(),
      );
      expect(fixture['url'], 'http://127.0.0.1:54401');
      final actor = fixture['users']['sales'];
      final ids = fixture['m'];
      final client = SupabaseClient(
        fixture['url'],
        fixture['key'],
        headers: {'Authorization': 'Bearer ${actor['token']}'},
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final store = FilePendingSaleStore(
        File('.batch2-tools/batch9-live-restart/pending.json'),
      );
      final evidence = File('.batch2-tools/batch9-live-restart/evidence.json');
      final repository = SalesRepository(client);
      Future<num> stock() async =>
          ((await client
                  .from('products')
                  .select('quantity')
                  .eq('business_id', ids['business'])
                  .eq('id', ids['product'])
                  .single())['quantity']
              as num);
      if (phase == 'before') {
        final beforeStock = await stock();
        final sale = Sale(
          id: const Uuid().v4(),
          businessId: ids['business'],
          branchId: null,
          employeeId: ids['sales_member'],
          total: 10,
          paymentMethod: 'cash',
          payments: [
            {'method': 'cash', 'amount': 10, 'confirmed': true},
          ],
          timestamp: DateTime.now().toUtc(),
          items: [
            SaleItem(
              productId: ids['product'],
              quantity: 1,
              unitPrice: 10,
              total: 10,
              priceLevel: 'standard',
            ),
          ],
        );
        await expectLater(
          PendingSaleSubmission(store).submit(
            userId: actor['id'],
            sale: sale,
            send: (request) async {
              final receipt = await repository.completeSale(request);
              await evidence.writeAsString(
                jsonEncode({
                  'pid': pid,
                  'stock_before': beforeStock,
                  'request_id': sale.id,
                  'receipt': receipt.toJsonWithItems(),
                }),
                flush: true,
              );
              throw const SocketException(
                'Simulated lost response after actual RPC commit',
              );
            },
          ),
          throwsA(isA<SocketException>()),
        );
        expect(await stock(), beforeStock - 1);
      } else {
        expect(phase, 'after');
        final before = jsonDecode(await evidence.readAsString());
        expect(pid, isNot(before['pid']));
        final pending = (await store.read())!;
        expect(
          pending.belongsTo(actor['id'], ids['business'], ids['sales_member']),
          isTrue,
        );
        expect(pending.sale.branchId, ids['branch_a']);
        expect(pending.sale.id, before['request_id']);
        var dispatches = 0;
        final receipt = await PendingSaleSubmission(store).submit(
          userId: actor['id'],
          sale: pending.sale,
          send: (request) {
            dispatches++;
            return repository.completeSale(request);
          },
        );
        expect(dispatches, 1);
        expect(receipt.toJsonWithItems(), before['receipt']);
        expect(await stock(), before['stock_before'] - 1);
        final rows = await client
            .from('sales')
            .select('id')
            .eq('id', receipt.id);
        expect(rows, hasLength(1));
        await store.acknowledge(pending.sale.id);
        expect(await store.read(), isNull);
        await evidence.writeAsString(
          jsonEncode({
            ...before,
            'restart_pid': pid,
            'dispatches': dispatches,
            'stock_after': await stock(),
            'passed': true,
          }),
          flush: true,
        );
      }
      client.dispose();
    },
    skip: phase.isEmpty ? 'Explicit disposable live fixture required.' : false,
  );
}
