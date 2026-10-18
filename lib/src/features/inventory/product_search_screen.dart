import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../ui/trexven_ui.dart';
import 'product_detail_screen.dart';
import 'product_provider.dart';
import 'inventory_operations_screen.dart';
import '../auth/permission_service.dart';
import '../auth/auth_provider.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() =>
      _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  String _stockFilter = 'all';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Rebuild immediately so the clear button responds instantly.
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(Duration(milliseconds: 300), () {
      if (!mounted) return;

      setState(() {
        _query = value.trim();
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();

    setState(() {
      _searchController.clear();
      _query = '';
    });
  }

  Future<void> _refresh() async {
    if (_query.isEmpty) return;

    await ref.read(productSearchProvider(_query).notifier).search();
  }

  Future<void> _openOperations() async {
    await Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => const PosInventoryOperationsScreen()));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final searchResult = ref.watch(productSearchProvider(_query));
    final scheme = Theme.of(context).colorScheme;
    final canView = ref.watch(permissionServiceProvider).hasPermission('view_inventory');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            if (Navigator.of(context).canPop())
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inventory', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: scheme.onSurface)),
                Text('Products & stock management',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            )),
            if (canView)
              IconButton(
                tooltip: 'Stocktaking & stock management',
                onPressed: _openOperations,
                icon: const Icon(Icons.tune_rounded),
              ),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TrexvenTextField(
            controller: _searchController,
            variant: TrexvenFieldVariant.search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: TrexvenInputDecoration(
              hintText: 'Products, barcode or part number',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty ? null : IconButton(
                tooltip: 'Clear search', onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded, size: 20)),
            ),
          ),
        ),
        if (canView)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(children: [
              Expanded(child: _InventoryShortcut(
                icon: Icons.inventory_2_outlined,
                title: 'Products',
                subtitle: 'Browse catalog',
                emphasized: true,
                onTap: () { _clearSearch(); setState(() => _stockFilter = 'all'); },
              )),
              const SizedBox(width: 12),
              Expanded(child: _InventoryShortcut(
                icon: Icons.fact_check_outlined,
                title: 'Stocktaking',
                subtitle: 'Count & reconcile',
                emphasized: false,
                onTap: _openOperations,
              )),
            ]),
          ),
        if (ref.watch(authStateProvider).activeBusiness?.branchesEnabled == true)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Catalog quantities are shown here. Open stock operations for branch stock.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Product search',
              style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, children: [
              for (final filter in const [('all', 'All results'), ('low', 'Low stock'), ('out', 'Out of stock')])
                ChoiceChip(label: Text(filter.$2), selected: _stockFilter == filter.$1,
                  onSelected: (_) => setState(() => _stockFilter = filter.$1)),
            ]))),
        Expanded(child: AnimatedSwitcher(
          duration: PosMotion.duration(context, PosMotion.component),
          child: _query.isEmpty ? _buildInitialState() : searchResult.when(
            loading: _buildLoadingState,
            error: (_, _) => _buildErrorState(),
            data: (products) {
              final visible = products.where((product) => switch (_stockFilter) {
                'low' => product.isActive && product.stock <= product.lowStockThreshold,
                'out' => product.isActive && product.stock <= 0,
                _ => true,
              }).toList();
              if (products.isEmpty) return _buildNoResultsState();
              return RefreshIndicator(onRefresh: _refresh,
                child: ListView(
                  key: const ValueKey('inventory-results'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    Text('${visible.length} matching products',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(children: [
                          const Icon(Icons.search_off_rounded, size: 32),
                          const SizedBox(height: 12),
                          const Text('No products match this stock filter.'),
                          TextButton(onPressed: () => setState(() => _stockFilter = 'all'),
                            child: const Text('Show all results')),
                        ]))
                    else
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Theme.of(context).trexvenColors.cardBackground ?? scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(TrexvenRadii.card),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55))),
                        child: Column(children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 76),
                            _buildProductRow(visible[i]),
                          ],
                        ]),
                      ),
                  ],
                ));
            },
          ),
        )),
      ])),
    );
  }

  Widget _buildInitialState() => const PosStateView(
    key: ValueKey('initial'),
    title: 'Product results',
    message: 'Search products by name, barcode or part number to browse your catalog.',
    icon: Icons.inventory_2_outlined,
  );
  Widget _buildLoadingState() => const Center(key: ValueKey('loading'),
    child: TrexvenLoading(message: 'Searching products…'));
  Widget _buildNoResultsState() => PosStateView(key: const ValueKey('no-results'),
    title: 'No matching products', message: 'No products match "$_query".',
    icon: Icons.inventory_2_outlined, action: TextButton(onPressed: _clearSearch, child: const Text('Clear search')));
  Widget _buildErrorState() => PosStateView(key: const ValueKey('error'),
    title: 'Search unavailable', message: 'Check your connection and try again.',
    icon: Icons.cloud_off_outlined,
    action: FilledButton(onPressed: () => ref.invalidate(productSearchProvider(_query)), child: const Text('Retry')));

  Widget _buildProductRow(Product product) {
    final scheme = Theme.of(context).colorScheme;
    final branchBusiness = ref.watch(authStateProvider).activeBusiness?.branchesEnabled == true;
    final low = product.isActive && product.stock <= product.lowStockThreshold;
    final stockLabel = !product.isActive ? 'Not available for sale'
        : product.stock <= 0 ? 'Out of stock' : low ? 'Low stock' : 'In stock';
    final stockColor = low ? Theme.of(context).trexvenColors.warning ?? scheme.error
        : scheme.onSurfaceVariant;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48, height: 48, color: scheme.primary.withValues(alpha: .10),
              child: product.hasImage
                  ? Image.network(product.imageUrl!, fit: BoxFit.cover, cacheWidth: 144,
                      errorBuilder: (_, _, _) => Icon(Icons.inventory_2_outlined, color: scheme.primary))
                  : Icon(Icons.inventory_2_outlined, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (product.partNumber?.isNotEmpty == true || product.barcode?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(product.partNumber ?? product.barcode ?? '', maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
            if (product.brand?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(product.brand!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 4),
            Text(branchBusiness
                ? 'Catalog stock: ${product.stock} ${product.unit}'
                : '$stockLabel · ${product.stock} ${product.unit}',
              style: TextStyle(fontSize: 12, color: stockColor)),
          ])),
          const SizedBox(width: 8),
          if (ref.watch(permissionServiceProvider).canCompleteSales)
            Flexible(child: Text(product.sellingPrice == null ? 'Price pending' :
              CustomerPresentation.money(product.sellingPrice!, currency: ref.watch(authStateProvider).activeBusiness?.currency),
              textAlign: TextAlign.end, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
        ]),
      ),
    ));
  }
}

/// Presentation-only shortcut. Stocktaking still uses the existing authorized workflow.
class _InventoryShortcut extends StatelessWidget {
  const _InventoryShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasized,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: emphasized ? colors.primary.withValues(alpha: 0.10) : colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: emphasized
                ? colors.primary.withValues(alpha: 0.25)
                : colors.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: colors.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_outward_rounded,
                  size: 18, color: colors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
