import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trexvenpos/src/services/pending_sale.dart';
import 'package:trexvenpos/src/features/pos/pending_sale_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/features/pos/checkout_screen.dart';
import 'package:trexvenpos/src/features/pos/sales_provider.dart';
import 'package:trexvenpos/src/features/pos/sales_repository.dart';
import 'package:trexvenpos/src/models/business.dart';
import 'package:trexvenpos/src/models/employee.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'package:trexvenpos/src/models/sale.dart';

class MemoryPendingStore implements PendingSaleStore {
  PendingSale? value;
  @override
  Future<PendingSale?> read() async => value;
  @override
  Future<void> save(PendingSale pending) async {
    value = pending;
  }

  @override
  Future<void> acknowledge(String requestId) async {
    value = null;
  }
}

class SignedIn extends AuthNotifier {
  void switchActor() {
    state = AuthState(
      activeBusiness: const Business(id: 'b', ownerId: 'u', name: 'Shop'),
      employee: const Employee(
        id: 'other-e',
        membershipId: 'other-m',
        userId: 'other-u',
        employeeCode: 'OTHER',
        name: 'Other cashier',
        role: EmployeeRole.cashier,
        businessId: 'b',
      ),
    );
  }

  SignedIn(SupabaseClient client) : super(client, observeSession: false) {
    state = AuthState(
      activeBusiness: const Business(id: 'b', ownerId: 'u', name: 'Shop'),
      employee: const Employee(
        id: 'e',
        membershipId: 'm',
        userId: 'u',
        employeeCode: 'EMP',
        name: 'Cashier',
        role: EmployeeRole.cashier,
        businessId: 'b',
      ),
    );
  }
}

class UnusedClient extends SupabaseClient {
  UnusedClient()
    : super(
        'https://example.invalid',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final payload = switch (request.url.path.split('/').last) {
            'get_trexven_cash_context' => {
              'configured': false,
              'shifts': <Object>[],
            },
            _ => throw StateError(
              'Unexpected checkout request: ${request.url.path}',
            ),
          };
          return http.Response(
            jsonEncode(payload),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
}

Future<void> confirmReceivedPayment(WidgetTester tester) async {
  // PostgREST decodes JSON in a real isolate; let that response arrive before
  // settling the animated processing indicator on the widget test clock.
  for (var i = 0; i < 20 && find.byType(AlertDialog).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
  final verification = find.widgetWithText(
    CheckboxListTile,
    'I have verified the payment',
  );
  expect(
    verification,
    findsOneWidget,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .join(' | '),
  );
  await tester.ensureVisible(verification);
  await tester.tap(verification);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Confirm Payment').last);
  await tester.pump();
}

class PendingRepository extends SalesRepository {
  PendingRepository(super.client);
  final calls = <Sale>[];
  Completer<Sale> result = Completer();
  @override
  Future<Sale> completeSale(Sale sale) {
    calls.add(sale);
    return result.future;
  }
}

void main() {
  testWidgets(
    'Actor change during submission preserves original intent without showing receipt',
    (tester) async {
      final store = MemoryPendingStore();
      final client = UnusedClient();
      final auth = SignedIn(client);
      final repo = PendingRepository(client);
      final cart = CartNotifier()
        ..addProduct(
          const Product(id: 'p', name: 'Widget', businessId: 'b'),
          10,
          'standard',
        );
      final container = ProviderContainer(
        overrides: [
          pendingSaleStoreProvider.overrideWith((ref) async => store),
          supabaseProvider.overrideWithValue(client),
          authStateProvider.overrideWith((ref) => auth),
          salesRepositoryProvider.overrideWithValue(repo),
          cartProvider.overrideWith((ref) => cart),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await confirmReceivedPayment(tester);
      expect(repo.calls, hasLength(1));
      auth.switchActor();
      repo.result.complete(repo.calls.single.copyWith(id: 'saved-sale'));
      await tester.pumpAndSettle();
      expect(find.text('Sale receipt'), findsNothing);
      expect(container.read(cartProvider), hasLength(1));
      expect(store.value?.userId, 'u');
      expect(store.value?.sale.businessId, 'b');
      expect(store.value?.sale.employeeId, 'm');
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'Checkout guards taps, keeps ambiguous retry, then clears cart and displays saved receipt',
    (tester) async {
      final pendingStore = MemoryPendingStore();
      final client = UnusedClient();
      final repo = PendingRepository(client);
      final cart = CartNotifier()
        ..addProduct(
          const Product(id: 'p', name: 'Widget', businessId: 'b'),
          10,
          'standard',
        );
      final container = ProviderContainer(
        overrides: [
          pendingSaleStoreProvider.overrideWith((ref) async => pendingStore),
          supabaseProvider.overrideWithValue(client),
          authStateProvider.overrideWith((ref) => SignedIn(client)),
          salesRepositoryProvider.overrideWithValue(repo),
          cartProvider.overrideWith((ref) => cart),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CheckoutScreen(),
                    ),
                  ),
                  child: const Text('Open checkout'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open checkout'));
      await tester.pumpAndSettle();
      final complete = find.byType(ElevatedButton).last;
      await tester.ensureVisible(complete);
      await tester.pumpAndSettle();
      await tester.tap(complete);
      await tester.tap(complete);
      await confirmReceivedPayment(tester);
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.employeeId, 'm');
      expect(repo.calls.single.payments, [
        {'method': 'cash', 'amount': 10.0, 'confirmed': true},
      ]);
      repo.result.completeError(Exception('connection lost after commit'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider), hasLength(1));
      expect(find.textContaining('Could not confirm'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      repo.result = Completer();
      await tester.ensureVisible(complete);
      await tester.pumpAndSettle();
      await tester.tap(complete);
      await tester.pump();
      expect(repo.calls[1].id, repo.calls[0].id);
      expect(repo.calls[1].payments, repo.calls[0].payments);
      expect(find.byType(CheckboxListTile), findsNothing);
      repo.result.complete(
        repo.calls[0].copyWith(
          id: 'saved-sale',
          paymentMethod: 'cash',
          items: const [
            SaleItem(
              productId: 'p',
              productName: 'Widget',
              quantity: 1,
              unitPrice: 10,
              total: 10,
              priceLevel: 'standard',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(cartProvider), isEmpty);
      expect(find.text('Sale receipt'), findsOneWidget);
      expect(find.text('Receipt: saved-sale'), findsOneWidget);
      expect(find.text('Widget × 1: ₦10.00'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Open checkout'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
