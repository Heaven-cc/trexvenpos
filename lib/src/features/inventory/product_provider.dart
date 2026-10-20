import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
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
  final business = ref.watch(authStateProvider).activeBusiness;
  final branch = ref.watch(branchContextProvider);
  return ProductSearchNotifier(ref.watch(productRepositoryProvider), business?.id ?? '', query,
    branchId: business?.branchesEnabled == true ? branch?.id : null,
    branchRequired: business?.branchesEnabled == true);
});

class ProductSearchNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductRepository _repository;
  final String _businessId;
  final String _query;
  final String? branchId;
  final bool branchRequired;
  int _generation = 0;

  ProductSearchNotifier(this._repository, this._businessId, this._query, {this.branchId, this.branchRequired = false}) : super(const AsyncValue.loading()) {
    search();
  }

  Future<void> search() async {
    if (!mounted) return;
    final generation = ++_generation;
    if (_query.isEmpty || _businessId.isEmpty || (branchRequired && branchId == null)) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final products = await _repository.searchProducts(_query, _businessId, branchId: branchId);
      if (!mounted || generation != _generation) return;
      state = AsyncValue.data(products);
    } catch (e, st) {
      if (!mounted || generation != _generation) return;
      state = AsyncValue.error(e, st);
    }
  }
}
