import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
      (ref) {
        ref.watch(authStateProvider.select((s) => '${s.employee?.userId}:${s.employee?.membershipId}:${s.activeBusiness?.id}'));
        return CartNotifier();
      },
);

class CartItem {
  final Product product;
  final num quantity;
  final double selectedPrice;
  final String priceLevel;
  final double discount;

  const CartItem({
    required this.product,
    this.quantity = 1,
    required this.selectedPrice,
    required this.priceLevel,
    this.discount = 0,
  });

  // Preserve the existing fixed-point monetary calculation.
  double get total =>
      ((BigInt.from((selectedPrice * 100).round()) *
          BigInt.from((quantity * 1000).round()) +
          BigInt.from(500)) ~/
          BigInt.from(1000))
          .toInt() /
          100 - discount;

  CartItem copyWith({
    Product? product,
    num? quantity,
    double? selectedPrice,
    String? priceLevel,
    double? discount,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedPrice: selectedPrice ?? this.selectedPrice,
      priceLevel: priceLevel ?? this.priceLevel,
      discount: discount ?? this.discount,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  // Retained for compatibility with the existing checkout integration.
  // Checkout idempotency semantics should be audited with checkout_screen.dart.
  String checkoutRequestId = const Uuid().v4();

  // Scan event keys are supplied by the scan/checkout adapter, not by the AI
  // model. A repeated callback for the same event must not increase quantity.
  final Set<String> _consumedScanEvents = <String>{};

  @override
  set state(List<CartItem> value) {
    checkoutRequestId = const Uuid().v4();
    super.state = value;
  }

  static String _normalizeLevel(String level) {
    final normalized = level.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Select an authorized price level.');
    }
    return normalized;
  }

  static void _validatePrice(double price) {
    if (!price.isFinite || price < 0 ||
        (price * 100 - (price * 100).round()).abs() > 0.000001) {
      throw ArgumentError('Use a valid product price with two decimal places.');
    }
  }

  /// Existing add semantics are preserved: same product and tier increment
  /// quantity; a different tier creates a separate cart line.
  void addProduct(Product product, double price, String level) {
    _validatePrice(price);
    final normalizedLevel = _normalizeLevel(level);

    final index = state.indexWhere(
          (item) => item.product.id == product.id &&
          item.priceLevel == normalizedLevel,
    );

    if (index == -1) {
      state = [
        ...state,
        CartItem(
          product: product,
          quantity: 1,
          selectedPrice: price,
          priceLevel: normalizedLevel,
        ),
      ];
      return;
    }

    final updatedItem = state[index].copyWith(
      quantity: state[index].quantity + 1,
    );
    final updatedCart = [...state];
    updatedCart[index] = updatedItem;
    state = updatedCart;
  }

  /// Adds an ALREADY VERIFIED product after the caller has selected an
  /// authorized current price/level. Returns false for a retried event.
  /// This does not perform product recognition or select a price tier.
  bool addScannedProduct({
    required Product product,
    required double authorizedPrice,
    required String authorizedPriceLevel,
    required String scanEventId,
  }) {
    final event = scanEventId.trim();
    if (event.isEmpty) {
      throw ArgumentError('A scan event ID is required.');
    }
    if (_consumedScanEvents.contains(event)) return false;

    // Do not mark the event consumed if adding throws.
    addProduct(product, authorizedPrice, authorizedPriceLevel);
    _consumedScanEvents.add(event);
    return true;
  }

  void removeProduct(String productId, String level) {
    final normalizedLevel = _normalizeLevel(level);
    state = state.where(
          (item) => !(item.product.id == productId &&
          item.priceLevel == normalizedLevel),
    ).toList();
  }

  void updateQuantity(String productId, String level, num quantity) {
    final normalizedLevel = _normalizeLevel(level);
    final index = state.indexWhere(
          (item) => item.product.id == productId &&
          item.priceLevel == normalizedLevel,
    );
    if (index == -1) return;
    if (quantity <= 0) {
      removeProduct(productId, normalizedLevel);
      return;
    }

    if (!quantity.isFinite || quantity < 0 ||
        (quantity * 1000 - (quantity * 1000).round()).abs() > 0.0000001 ||
        (!state[index].product.supportsFractionalQuantity &&
            quantity != quantity.truncate())) {
      throw ArgumentError(
        'Use whole pieces or up to three decimal places for measurable units.',
      );
    }
    if (state[index].discount > quantity * state[index].selectedPrice) {
      throw ArgumentError('Adjust discount before reducing quantity.');
    }

    final updatedCart = [...state];
    updatedCart[index] = state[index].copyWith(quantity: quantity);
    state = updatedCart;
  }

  void increment(String productId, String level) {
    final item = _findItem(productId, level);
    if (item != null) updateQuantity(productId, level, item.quantity + 1);
  }

  void decrement(String productId, String level) {
    final item = _findItem(productId, level);
    if (item != null) updateQuantity(productId, level, item.quantity - 1);
  }

  void updateTerms(
      String productId,
      String level,
      double price,
      double discount,
      ) {
    final normalizedLevel = _normalizeLevel(level);
    final index = state.indexWhere(
          (i) => i.product.id == productId &&
          i.priceLevel == normalizedLevel,
    );
    if (index < 0) return;
    _validatePrice(price);
    if (!discount.isFinite || discount < 0 ||
        discount > state[index].quantity * price ||
        (discount * 100 - (discount * 100).round()).abs() > 0.000001) {
      throw ArgumentError('Use valid prices and discounts with two decimal places.');
    }

    state = [
      for (var i = 0; i < state.length; i++)
        i == index
            ? state[i].copyWith(selectedPrice: price, discount: discount)
            : state[i],
    ];
  }

  void clear() {
    state = const [];
    _consumedScanEvents.clear();
  }

  num get itemCount {
    final units = state.fold<int>(
      0,
          (sum, item) => sum + (item.quantity * 1000).round(),
    );
    return units % 1000 == 0 ? units ~/ 1000 : units / 1000;
  }

  int get uniqueItemCount => state.length;

  double get total => state.fold<int>(
    0,
        (sum, item) => sum + (item.total * 100).round(),
  ) / 100;

  bool get isNotEmpty => state.isNotEmpty;
  bool get isEmpty => state.isEmpty;

  CartItem? _findItem(String productId, String level) {
    final normalizedLevel = _normalizeLevel(level);
    for (final item in state) {
      if (item.product.id == productId &&
          item.priceLevel == normalizedLevel) {
        return item;
      }
    }
    return null;
  }
}
