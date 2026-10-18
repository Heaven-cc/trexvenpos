import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/inventory/product_provider.dart';
import 'package:trexvenpos/src/features/inventory/product_repository.dart';
import 'package:trexvenpos/src/features/inventory/product_search_screen.dart';
import 'package:trexvenpos/src/features/inventory/product_detail_screen.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'package:trexvenpos/src/models/price_levels.dart';
import 'employee_settings_test.dart' show StaffSession, NoNetwork;

class DisplayRepository extends ProductRepository {
  DisplayRepository() : super(NoNetwork());
  int searches = 0, priceReads = 0;
  static const product = Product(
    id: 'product',
    name: 'Test product',
    businessId: 'business',
    stock: 10,
    sellingPrice: 10,
    status: ProductStatus.active,
  );
  @override
  Future<List<Product>> searchProducts(String query, String business) async {
    searches++;
    return [product];
  }

  @override
  Future<PriceLevels?> getPriceLevels(String productId) async {
    priceReads++;
    if (priceReads == 1) throw Exception('private_rpc and SQL error');
    return PriceLevels(
      productId: productId,
      budget: 10,
      standard: 10,
      premium: 10,
      market: 10,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scale in [1.0, 1.6]) {
    testWidgets(
      'POS selection remains present and price retry retains the product at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = DisplayRepository();
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => StaffSession()),
            productRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const ProductSearchScreen(),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Test product'), findsOneWidget);
        await tester.tap(find.text('Test product'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsOneWidget);
        expect(find.textContaining('private_rpc'), findsNothing);
        expect(find.text('Unable to load prices'), findsOneWidget);
        expect(container.read(cartProvider), isEmpty);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(repository.priceReads, 2);
        expect(find.text('Test product'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Add'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsNothing);
        expect(find.text('Test product'), findsOneWidget);
        expect(container.read(cartProvider).single.product.id, 'product');
        expect(container.read(cartProvider).single.quantity, 1);
        expect(DisplayRepository.product.stock, 10);
        expect(repository.searches, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
