import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'product_repository.dart';
import '../../models/product.dart';
import '../../models/price_levels.dart';

final productRepositoryProvider = Provider((ref) {
  return ProductRepository(ref.watch(supabaseProvider));
});

final productPriceLevelsProvider = FutureProvider.family<PriceLevels?, String>((ref, productId) async {
  return ref.watch(productRepositoryProvider).getPriceLevels(productId);
});

final productSearchProvider = StateNotifierProvider.family<ProductSearchNotifier, AsyncValue<List<Product>>, String>((ref, query) {
  final businessId = ref.watch(authStateProvider).activeBusiness?.id ?? '';
  return ProductSearchNotifier(ref.watch(productRepositoryProvider), businessId, query);
});

class ProductSearchNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductRepository _repository;
  final String _businessId;
  final String _query;

  ProductSearchNotifier(this._repository, this._businessId, this._query) : super(const AsyncValue.loading()) {
    search();
  }

  Future<void> search() async {
    if (_query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final products = await _repository.searchProducts(_query, _businessId);
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
