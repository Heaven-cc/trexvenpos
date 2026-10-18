import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/features/pos/checkout_screen.dart';
import 'package:trexvenpos/src/features/pos/pending_sale_provider.dart';
import 'package:trexvenpos/src/features/pos/sales_provider.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'checkout_flow_test.dart'
    show MemoryPendingStore, UnusedClient, SignedIn, PendingRepository;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 340.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Checkout $width/$scale/$dark grows and preserves cart actions',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final client = UnusedClient();
            final cart = CartNotifier()
              ..addProduct(
                const Product(
                  id: 'p',
                  name: 'Representative long product name',
                  businessId: 'b',
                ),
                10,
                'standard',
              );
            final container = ProviderContainer(
              overrides: [
                supabaseProvider.overrideWithValue(client),
                authStateProvider.overrideWith((ref) => SignedIn(client)),
                cartProvider.overrideWith((ref) => cart),
                pendingSaleStoreProvider.overrideWith(
                  (ref) async => MemoryPendingStore(),
                ),
                salesRepositoryProvider.overrideWithValue(
                  PendingRepository(client),
                ),
              ],
            );
            addTearDown(container.dispose);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: dark
                      ? TrexvenTheme.darkTheme
                      : TrexvenTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: const CheckoutScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final increment = find.widgetWithIcon(
              IconButton,
              Icons.add_rounded,
            );
            await tester.ensureVisible(increment);
            await tester.pumpAndSettle();
            expect(tester.getSize(increment).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(increment).height, greaterThanOrEqualTo(48));
            await tester.tap(increment);
            await tester.pumpAndSettle();
            expect(container.read(cartProvider).single.quantity, 2);
            final transfer = find.text('Transfer');
            await tester.ensureVisible(transfer);
            await tester.pumpAndSettle();
            await tester.tap(transfer);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(container.read(cartProvider).single.quantity, 2);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
