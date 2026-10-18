import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexvenpos/src/features/pos/sales_repository.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/models/sale.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'package:trexvenpos/src/services/sale_errors.dart';

void main() {
  for (final entry in {
    'Cash': 'cash',
    'POS Terminal': 'card',
    'Transfer': 'bank_transfer',
  }.entries) {
    test(
      'Checkout maps ${entry.key} and returns the saved receipt on retries',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.invalid',
          'test',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'id': 'saved-id',
                'business_id': 'b',
                'employee_id': 'e',
                'created_at': '2026-10-05T00:00:00Z',
                'total': 20,
                'payment_method': entry.value,
                'sale_items': [
                  {
                    'product_id': 'p',
                    'product_name': 'Widget',
                    'quantity': 2,
                    'unit_price': 10,
                    'total': 20,
                  },
                ],
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final repo = SalesRepository(client);
        final sale = Sale(
          id: 'stable-request',
          businessId: 'b',
          employeeId: 'e',
          total: 20,
          paymentMethod: entry.key,
          timestamp: DateTime.now(),
          items: const [
            SaleItem(
              productId: 'p',
              quantity: 2,
              unitPrice: 10,
              total: 20,
              priceLevel: 'standard',
            ),
          ],
        );
        final receipt = await repo.completeSale(sale);
        await repo.completeSale(sale);
        expect(receipt.id, 'saved-id');
        expect(receipt.items.single.productName, 'Widget');
        expect(receipt.timestamp, DateTime.utc(2026, 10, 5));
        expect(requests[0].body, requests[1].body);
        final body = jsonDecode(requests[0].body);
        expect(body['p_payment_method'], entry.value);
        expect(body['p_request_id'], 'stable-request');
        expect(
          requests.singleWhere((r) => identical(r, requests.first)).url.path,
          endsWith('/rpc/submit_trexven_sale'),
        );
        await client.dispose();
      },
    );
  }
  test('Cart retains retry identity until its contents change', () {
    final cart = CartNotifier();
    cart.addProduct(
      const Product(id: 'p', name: 'Widget', businessId: 'b'),
      10,
      'standard',
    );
    final key = cart.checkoutRequestId;
    expect(cart.checkoutRequestId, key);
    cart.increment('p', 'standard');
    expect(cart.checkoutRequestId, isNot(key));
    cart.dispose();
  });
  test('Fractional currency totals match database decimal arithmetic', () {
    final cart = CartNotifier();
    cart.addProduct(
      const Product(id: 'p', name: 'Widget', businessId: 'b'),
      0.1,
      'standard',
    );
    cart.increment('p', 'standard');
    cart.increment('p', 'standard');
    expect(cart.total, 0.3);
    cart.dispose();
  });
  test('Checkout exposes actionable database errors', () {
    expect(
      saleErrorMessage(
        const PostgrestException(message: 'Insufficient stock', code: 'P0001'),
      ),
      'Insufficient stock',
    );
    expect(
      saleErrorMessage(Exception('connection lost')),
      contains('will not be recorded twice'),
    );
  });
}
