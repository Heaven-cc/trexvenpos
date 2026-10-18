import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/inventory/quick_add_screen.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/features/pos/checkout_screen.dart';
import 'package:trexvenpos/src/features/pos/dashboard_screen.dart';
import 'package:trexvenpos/src/models/business.dart';
import 'package:trexvenpos/src/models/employee.dart';
import 'package:trexvenpos/src/models/product.dart';

class NoNetworkClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected network operation: ${invocation.memberName}',
  );
}

class SignedIn extends AuthNotifier {
  SignedIn(SupabaseClient client, Employee employee)
    : super(client, observeSession: false) {
    state = AuthState(
      employee: employee,
      activeBusiness: const Business(
        id: 'business',
        ownerId: 'owner',
        name: 'Shop',
      ),
    );
  }
  String? get selectedBusinessId => state.activeBusiness?.id;
}

Employee staff(EmployeeRole role) => Employee(
  id: 'employee',
  userId: 'user',
  membershipId: 'member',
  employeeCode: 'EMP',
  name: 'Staff',
  businessId: 'business',
  role: role,
);

ProviderContainer session(EmployeeRole role) {
  final client = NoNetworkClient();
  return ProviderContainer(
    overrides: [
      supabaseProvider.overrideWithValue(client),
      authStateProvider.overrideWith((ref) => SignedIn(client, staff(role))),
    ],
  );
}

void main() {
  test('Business selection cannot cross employee business assignments', () {
    final auth = SignedIn(NoNetworkClient(), staff(EmployeeRole.cashier));
    expect(
      () => auth.selectBusiness(
        const Business(id: 'other', ownerId: 'other', name: 'Other'),
      ),
      throwsStateError,
    );
    expect(auth.selectedBusinessId, 'business');
    auth.dispose();
  });

  testWidgets(
    'Direct quick-add route denies sales staff without a network call',
    (tester) async {
      final container = session(EmployeeRole.cashier);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: QuickAddScreen()),
        ),
      );
      expect(
        find.text('You do not have permission to add products.'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('Dashboard hides product creation from sales staff', (
    tester,
  ) async {
    final container = session(EmployeeRole.cashier);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    expect(find.text('Quick Add Product'), findsNothing);
    expect(find.text('Scan Product'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('Direct checkout denies inventory staff and preserves cart', (
    tester,
  ) async {
    final container = session(EmployeeRole.inventoryEmployee);
    container
        .read(cartProvider.notifier)
        .addProduct(
          const Product(id: 'product', name: 'Widget', businessId: 'business'),
          10,
          'standard',
        );
    final request = container.read(cartProvider.notifier).checkoutRequestId;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();
    expect(
      find.text('You do not have permission to complete this sale.'),
      findsOneWidget,
    );
    expect(container.read(cartProvider), hasLength(1));
    expect(container.read(cartProvider.notifier).checkoutRequestId, request);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('Checkout rejects a cart from a different business', (
    tester,
  ) async {
    final container = session(EmployeeRole.cashier);
    container
        .read(cartProvider.notifier)
        .addProduct(
          const Product(
            id: 'product',
            name: 'Other shop item',
            businessId: 'other',
          ),
          10,
          'standard',
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();
    expect(
      find.text('You do not have permission to complete this sale.'),
      findsOneWidget,
    );
    expect(container.read(cartProvider), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
