import 'package:flutter_test/flutter_test.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'package:trexvenpos/src/models/sale.dart';

void main() {
  test('fractional cart quantity rounds each line to currency precision', () {
    final cart = CartNotifier();
    const oil = Product(id: 'oil', name: 'Oil', businessId: 'b', unit: 'litre');
    cart.addProduct(oil, 1.99, 'standard');
    cart.updateQuantity('oil', 'standard', 0.125);
    expect(cart.state.single.total, 0.25);
    expect(cart.total, 0.25);
    expect(cart.itemCount, 0.125);
    expect(cart.state.single.quantity, 0.125);
  });
  test('pieces, nonfinite quantities and excessive precision are rejected', () {
    final cart = CartNotifier();
    cart.addProduct(
      const Product(id: 'p', name: 'Piece', businessId: 'b'),
      10,
      'standard',
    );
    expect(
      () => cart.updateQuantity('p', 'standard', 0.5),
      throwsArgumentError,
    );
    expect(
      () => cart.updateQuantity('p', 'standard', double.nan),
      throwsArgumentError,
    );
    cart.addProduct(
      const Product(id: 'kg', name: 'Weight', businessId: 'b', unit: 'kg'),
      2,
      'standard',
    );
    expect(
      () => cart.updateQuantity('kg', 'standard', 0.0001),
      throwsArgumentError,
    );
  });
  test(
    'variant identity survives copied model and legacy barcode remains text',
    () {
      final p = Product.fromJson({
        'id': 'v',
        'business_id': 'b',
        'name': 'Blue',
        'barcode': '00123',
        'selling_price': 0,
        'catalog_group_id': 'group',
        'variant_attributes': {'color': 'Blue'},
      });
      expect(p.copyWith(name: 'Edited').catalogGroupId, 'group');
      expect(p.copyWith().unit, 'piece');
      expect(p.barcode, '00123');
      expect(p.sellingPrice, 0);
      expect(p.isActive, true);
    },
  );
  test(
    'receipt item quantity keeps fractional and legacy integer representations',
    () {
      final fractional = SaleItem.fromJson({
        'id': 'i',
        'sale_id': 's',
        'product_id': 'p',
        'product_name': 'Oil',
        'quantity': 0.125,
        'unit_price': 10,
        'total': 1.25,
      });
      expect(fractional.quantity, 0.125);
      expect(fractional.toJson()['quantity'], 0.125);
      final legacy = SaleItem.fromJson({'quantity': 2, 'unit_price': 10});
      expect(legacy.quantity, 2);
    },
  );
}
