import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexvenpos/main.dart';
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/models/employee.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'package:trexvenpos/src/models/sale.dart';

class _UnusedSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Signed-out terminal displays employee login', (tester) async {
    final client = _UnusedSupabaseClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(client),
          authStateProvider.overrideWith(
            (ref) => AuthNotifier(client, observeSession: false),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Employee ID'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  test('Live backend rows support receipt timestamps and standard prices', () {
    final sale = Sale.fromJson({
      'id': 'sale',
      'business_id': 'business',
      'employee_id': 'member',
      'created_at': '2026-10-03T09:00:00Z',
      'total': 10,
      'sale_items': [
        {'product_id': 'product', 'quantity': 1, 'unit_price': 10, 'total': 10},
      ],
    });
    expect(sale.timestamp, DateTime.utc(2026, 10, 3, 9));
    expect(sale.items.single.priceLevel, 'standard');
    final product = Product.fromJson({
      'id': 'product',
      'business_id': 'business',
      'name': 'Widget',
      'sku': 'SKU-1',
      'is_active': true,
      'active': true,
    });
    expect(product.isActive, true);
    expect(product.partNumber, 'SKU-1');
    expect(product.toJson().containsKey('part_number'), false);
  });

  test('Sales employee preserves both IDs and unknown status fails closed', () {
    final staff = Employee.fromJson({
      'id': 'employee',
      'membership_id': 'member',
      'role': 'sales_employee',
      'status': 'active',
    });
    expect(staff.id, 'employee');
    expect(staff.membershipId, 'member');
    expect(staff.canAccessPOS, true);
    expect(Employee.fromJson({'status': 'terminated'}).isActive, false);
  });
}
