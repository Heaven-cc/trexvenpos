import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'product_provider.dart';
import 'catalog_edit_screen.dart';
import '../auth/permission_service.dart';
import '../auth/auth_provider.dart';
import '../pos/cart_provider.dart';
import '../../models/product.dart';
import '../../models/price_levels.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceLevelsAsync = ref.watch(productPriceLevelsProvider(product.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        actions: [
          if (ref.watch(permissionServiceProvider).canManageInventory)
            IconButton(
              tooltip: 'Edit product',
              icon: Icon(Icons.edit),
              onPressed: () => _editProduct(context, ref),
            ),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          'Product',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: TrexvenFontSize.section,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: priceLevelsAsync.when(
        data: (levels) => _buildContent(context, ref, levels),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (error, stackTrace) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Future<void> _editProduct(BuildContext context, WidgetRef ref) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CatalogEditScreen(product: product)),
    );
    if (changed != true || !context.mounted) return;
    ref.invalidate(productSearchProvider);
    ref.invalidate(productPriceLevelsProvider(product.id));
    Navigator.pop(context);
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    PriceLevels? levels,
  ) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildProductHeader(context),

          if (_hasOptionalDetails) ...[
            SizedBox(height: PosSpace.xl),
            _buildProductInformation(context),
          ],

          SizedBox(height: PosSpace.xl),

          _buildPriceSection(context, ref, levels),
        ],
      ),
    );
  }

  bool get _hasOptionalDetails =>
      product.barcode?.trim().isNotEmpty == true ||
      product.partNumber?.trim().isNotEmpty == true ||
      product.brand?.trim().isNotEmpty == true ||
      product.category?.trim().isNotEmpty == true ||
      product.description?.trim().isNotEmpty == true;

  Widget _buildProductHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).trexvenColors.cardBackground ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(13),
          child: SizedBox(width: 72, height: 72, child: _buildProductImage(context))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (product.brand?.trim().isNotEmpty == true) ...[
            Text(product.brand!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
          ],
          Text(product.name, style: const TextStyle(fontSize: 19,
            fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 12),
          _buildStatusBadge(context),
          const SizedBox(height: 8),
          Text('Catalog stock: ${product.stock} ${product.unit}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    if (product.imageUrl == null || product.imageUrl!.trim().isEmpty) {
      return Container(
        height: 72,
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 72,
      width: double.infinity,
      child: Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isPending = product.status == ProductStatus.pending;

    final backgroundColor = isPending
        ? Theme.of(context).trexvenColors.warning!.withValues(alpha: .10)
        : Theme.of(context).trexvenColors.success!.withValues(alpha: .10);

    final foregroundColor = isPending
        ? Theme.of(context).trexvenColors.warning!
        : Theme.of(context).trexvenColors.success!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending_outlined : Icons.check_circle_outline,
            size: 15,
            color: foregroundColor,
          ),
          SizedBox(width: 8),
          Text(
            isPending
                ? 'Pending price'
                : product.isInactive
                ? 'Archived'
                : 'Active',
            style: TextStyle(
              color: foregroundColor,
              fontSize: TrexvenFontSize.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInformation(BuildContext context) {
    final details = <({IconData icon, String label, String value})>[
      if (product.barcode?.trim().isNotEmpty == true)
        (icon: Icons.qr_code_2_outlined, label: 'Barcode', value: product.barcode!.trim()),
      if (product.partNumber?.trim().isNotEmpty == true)
        (icon: Icons.tag_outlined, label: 'Part Number', value: product.partNumber!.trim()),
      if (product.brand?.trim().isNotEmpty == true)
        (icon: Icons.workspace_premium_outlined, label: 'Brand', value: product.brand!.trim()),
      if (product.category?.trim().isNotEmpty == true)
        (icon: Icons.category_outlined, label: 'Category', value: product.category!.trim()),
      if (product.description?.trim().isNotEmpty == true)
        (icon: Icons.notes_outlined, label: 'Description', value: product.description!.trim()),
    ];
    if (details.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product Information', style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: TrexvenFontSize.section,
          fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Column(children: [
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0) _buildDivider(context),
              _buildInfoRow(context, icon: details[i].icon,
                label: details[i].label, value: details[i].value),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(
              icon,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: TrexvenFontSize.caption,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildPriceSection(
    BuildContext context,
    WidgetRef ref,
    PriceLevels? levels,
  ) {
    if (!ref.watch(permissionServiceProvider).canCompleteSales) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Price',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: TrexvenFontSize.section,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),

        SizedBox(height: 4),

        Text(
          'Choose the price to use for this sale.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: TrexvenFontSize.body,
          ),
        ),

        SizedBox(height: 12),

        if (levels == null)
          _buildNoPricesState(context)
        else ...[
          _buildPriceCard(
            context: context,
            ref: ref,
            label: 'Standard',
            price: levels.standard,
            icon: Icons.sell_outlined,
            isRecommended: true,
          ),
        ],
      ],
    );
  }

  Widget _buildNoPricesState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(
              Icons.price_change_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),

          SizedBox(height: 12),

          Text(
            'No price information',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: TrexvenFontSize.input,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'This product needs an active selling price before it can be sold.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: TrexvenFontSize.body,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required double price,
    required IconData icon,
    String? subtitle,
    bool isRecommended = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
        color: isRecommended
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          onTap: product.isActive ? () => _addToCart(context, ref, label, price) : null,
          child: Padding(
            padding: TrexvenSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.input,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isRecommended)
                      Text(
                        'Default price',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  CustomerPresentation.money(
                    price,
                    currency: ref
                        .watch(authStateProvider)
                        .activeBusiness
                        ?.currency,
                  ),
                  style: TextStyle(
                    fontSize: TrexvenFontSize.section,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(subtitle),
                ],
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart(
    BuildContext context,
    WidgetRef ref,
    String label,
    double price,
  ) {
    final auth = ref.read(authStateProvider);
    if (!product.isActive ||
        !ref.read(permissionServiceProvider).canCompleteSales ||
        product.businessId != auth.activeBusiness?.id ||
        auth.employee?.businessId != auth.activeBusiness?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot create a sale for this product.')),
      );
      return;
    }
    ref
        .read(cartProvider.notifier)
        .addProduct(product, price, label.toLowerCase());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).scaffoldBackgroundColor,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label price added to cart',
                style: TextStyle(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: TrexvenSpacing.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 12),
              Text(
                'Unable to load prices',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TrexvenFontSize.section,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                CustomerPresentation.error(
                  error,
                  fallback:
                      'We could not load product prices. Please try again.',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: PosSpace.md),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(productPriceLevelsProvider(product.id)),
                child: Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
