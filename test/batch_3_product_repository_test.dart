import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexvenpos/src/features/inventory/product_repository.dart';
import 'package:trexvenpos/src/models/product.dart';

void main() {
  test(
    'catalog read retries only absent new columns with non-cost legacy projection',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((r) async {
          requests.add(r);
          if (requests.length == 1) {
            return http.Response(
              jsonEncode({
                'code': '42703',
                'message': 'column catalog_group_id does not exist',
              }),
              400,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'p',
                'business_id': 'b',
                'name': 'Legacy',
                'barcode': '00123',
                'selling_price': 0,
              },
            ]),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final product = await ProductRepository(
        client,
      ).findProductByBarcode('00123', 'b');
      expect(product!.id, 'p');
      expect(product.isActive, true);
      expect(requests.length, 2);
      for (final r in requests) {
        expect(r.url.queryParameters['business_id'], 'eq.b');
        expect(r.url.queryParameters['select'], isNot(contains('cost_price')));
        expect(r.url.queryParameters['select'], isNot('*'));
      }
      expect(
        requests.last.url.queryParameters['select'],
        isNot(contains('catalog_group_id')),
      );
      await client.dispose();
    },
  );
  test('permission denial does not invoke a legacy fallback', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.invalid',
      'test',
      httpClient: MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await expectLater(
      ProductRepository(client).searchProducts('widget', 'b'),
      throwsA(isA<PostgrestException>()),
    );
    expect(calls, 1);
    await client.dispose();
  });
  test(
    'duplicate barcode fails explicitly and never chooses an arbitrary row',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode([
              {'id': 'a'},
              {'id': 'b'},
            ]),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        ProductRepository(client).findProductByBarcode('123', 'b'),
        throwsA(isA<DuplicateBarcode>()),
      );
      await client.dispose();
    },
  );
  test(
    'pending quick add returns database identity and omits all price and cost fields',
    () async {
      late Map<String, dynamic> payload;
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((r) async {
          payload = jsonDecode(r.body);
          return http.Response(
            jsonEncode('real-database-id'),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final product = await ProductRepository(client).quickAddProduct(
        const Product(id: 'stable-request', name: 'Pending', businessId: 'b'),
      );
      expect(product.id, 'real-database-id');
      expect(product.isPending, true);
      expect(payload['p_request_id'], 'stable-request');
      expect(payload['p_business_id'], 'b');
      expect((payload['p_fields'] as Map).containsKey('selling_price'), false);
      expect((payload['p_fields'] as Map).containsKey('cost_price'), false);
      await client.dispose();
    },
  );
}
