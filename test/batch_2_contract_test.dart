import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'package:trexvenpos/src/models/sale.dart';
import 'package:trexvenpos/src/models/employee.dart';
import 'package:trexvenpos/src/features/pos/sales_repository.dart';
import 'package:trexvenpos/src/features/auth/permission_service.dart';

void main() {
  test('Revoked POS permission also blocks sale completion', () {
    final employee = Employee.fromJson({
      'role': 'sales_employee',
      'status': 'active',
      'denied_permissions': ['pos_access'],
    });
    expect(employee.canAccessPOS, isFalse);
    expect(PermissionService(employee).canCompleteSales, isFalse);
  });
  test('Explicit owner denial overrides default sales permission', () {
    final manager = Employee.fromJson({
      'role': 'manager',
      'status': 'active',
      'permissions': ['complete_sales'],
      'denied_permissions': ['complete_sales'],
    });
    expect(manager.hasPermission('complete_sales'), isFalse);
    expect(
      manager.copyWith(name: 'Changed').hasPermission('complete_sales'),
      isFalse,
    );
    expect(
      Employee.fromJson(manager.toJson()).hasPermission('complete_sales'),
      isFalse,
    );
  });
  test('Null selling price remains pending even with forged active flags', () {
    final product = Product.fromJson({
      'id': 'p',
      'business_id': 'b',
      'selling_price': null,
      'active': true,
      'is_active': true,
    });
    expect(product.isPending, isTrue);
    expect(
      Product.fromJson({'selling_price': 0, 'is_active': true}).isActive,
      isTrue,
    );
  });
  test('Sales cannot gain price or staff administration from stale grants', () {
    final employee = Employee.fromJson({
      'role': 'sales_employee',
      'status': 'active',
      'permissions': [
        'override_price',
        'manage_employees',
        'view_camera_events',
      ],
    });
    for (final permission in employee.permissions) {
      expect(employee.hasPermission(permission), isFalse);
    }
  });
  test('Owner-only Vision stays denied for explicitly granted managers', () {
    final manager = Employee.fromJson({
      'role': 'manager',
      'status': 'active',
      'permissions': ['view_camera_events'],
    });
    expect(manager.hasPermission('view_camera_events'), isFalse);
  });
  test(
    'Legacy sale JSON has no new branch key; branch receipts round-trip',
    () {
      final legacy = Sale.fromJson({
        'id': 'request',
        'business_id': 'b',
        'employee_id': 'member',
        'created_at': '2026-10-07T00:00:00Z',
      });
      expect(legacy.toJson().containsKey('branch_id'), isFalse);
      final scoped = Sale.fromJson({...legacy.toJson(), 'branch_id': 'branch'});
      expect(scoped.copyWith(paymentMethod: 'card').branchId, 'branch');
      expect(scoped.toJson()['branch_id'], 'branch');
      expect(scoped.employeeId, 'member');
    },
  );
  test(
    'Branch sale uses distinct API and retains original retry context',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'id': 'saved',
              'business_id': 'b',
              'employee_id': 'member',
              'branch_id': 'branch',
              'total': 10,
              'created_at': '2026-10-07T00:00:00Z',
              'sale_items': [],
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final sale = Sale(
        id: 'request',
        businessId: 'b',
        branchId: 'branch',
        employeeId: 'member',
        total: 10,
        paymentMethod: 'cash',
        timestamp: DateTime.utc(2026),
        items: const [
          SaleItem(
            productId: 'p',
            quantity: 1,
            unitPrice: 10,
            total: 10,
            priceLevel: 'standard',
          ),
        ],
      );
      final repo = SalesRepository(client);
      final receipt = await repo.completeSale(sale);
      await repo.completeSale(sale);
      expect(
        requests.first.url.path,
        endsWith('/rpc/submit_trexven_branch_sale'),
      );
      expect(requests.first.body, requests.last.body);
      final body = jsonDecode(requests.first.body);
      expect(body['p_request_id'], 'request');
      expect(body['p_employee_id'], 'member');
      expect(body['p_branch_id'], 'branch');
      expect(receipt.branchId, 'branch');
      await client.dispose();
    },
  );
  test(
    'Business sales reader scopes business/branch and preserves other staff receipts',
    () async {
      http.Request? sent;
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode([
              {
                'id': 'receipt',
                'business_id': 'business',
                'branch_id': 'branch',
                'employee_id': 'other-member',
                'created_at': '2026-10-07T00:00:00Z',
                'sale_items': [
                  {
                    'product_id': null,
                    'product_name': 'Archived product',
                    'quantity': 1,
                    'unit_price': 10,
                    'total': 10,
                  },
                ],
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final sales = await SalesRepository(
        client,
      ).getAuthorizedBusinessSales('business', branchId: 'branch');
      expect(sent!.url.queryParameters['business_id'], 'eq.business');
      expect(sent!.url.queryParameters['branch_id'], 'eq.branch');
      expect(sent!.url.queryParameters.containsKey('employee_id'), isFalse);
      expect(sales.single.employeeId, 'other-member');
      expect(sales.single.items.single.productName, 'Archived product');
      await client.dispose();
    },
  );
}
