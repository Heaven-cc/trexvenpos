import 'package:uuid/uuid.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import '../inventory/product_provider.dart';
import '../inventory/product_search_screen.dart';
import '../inventory/quick_add_screen.dart';
import '../inventory/scanner_screen.dart';
import 'cart_provider.dart';
import '../../ui/trexven_ui.dart';
import 'expense_support_screen.dart';
import 'pending_sale_provider.dart';
import 'checkout_screen.dart';
import 'recent_sales_screen.dart';
import 'credit_returns_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final business = auth.activeBusiness;
    final employee = auth.employee;
    final access = ref.watch(permissionServiceProvider);
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    void open(Widget page) => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
    final scheme = Theme.of(context).colorScheme;
    final scan = ScannerScreen(onProductMatched: (product, scanEventId) =>
        _addRecognizedProduct(context, ref, product, scanEventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('TREXVEN POS'),
        actions: [
          if (business?.branchesEnabled == true)
            IconButton(
              tooltip: 'Change branch',
              icon: const Icon(Icons.store_outlined),
              onPressed: !canSwitchPosBranch(access) ? null : () async {
                try {
                  final pending = await (await ref.read(pendingSaleStoreProvider.future)).read();
                  if (await OperationJournal().pending() != null) throw StateError('Recover the retained operation before switching branches.');
                  ref.read(branchContextProvider.notifier).clear(hasCart: ref.read(cartProvider).isNotEmpty,
                    hasPendingSale: pending != null, canSwitch: canSwitchPosBranch(ref.read(permissionServiceProvider)));
                  ref.invalidate(authorizedBranchesProvider);
                } catch (error) {
                  if (context.mounted) _showScanError(context, CustomerPresentation.error(error,
                    fallback: error is StateError ? error.message.toString() : 'Unable to verify branch access.'));
                }
              },
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: PosSpace.page,
          children: [
            Text('Hello, ${employee?.name ?? 'Employee'}',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              business?.branchesEnabled == true
                  ? ref.watch(branchContextProvider)?.name ?? 'Select branch'
                  : 'Ready for your next sale',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Material(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => open(scan),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan Product',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: scheme.onPrimary)),
                                const SizedBox(height: 4),
                                Text('Scan products with Angel AI',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onPrimary.withValues(alpha: .85))),
                              ],
                            ),
                          ),
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 28, color: scheme.onPrimary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Angel Scan',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: scheme.onPrimary)),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: scheme.onPrimary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _HomeActionTile(
                  icon: Icons.search_rounded, title: 'Search',
                  subtitle: 'Find products',
                  onTap: () => open(ProductSearchScreen(
                    onAddProduct: (product) => _addRecognizedProduct(
                      context, ref, product, const Uuid().v4()),
                  )),
                )),
                const SizedBox(width: 12),
                Expanded(child: _HomeActionTile(
                  icon: Icons.history_rounded, title: 'Sales History',
                  subtitle: 'Transactions',
                  onTap: () => open(const RecentSalesScreen()),
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _HomeActionTile(
                  icon: Icons.account_balance_wallet_outlined, title: 'Expenses',
                  subtitle: 'Expense options',
                  onTap: access.canAccessExpenses ? () => open(const PosExpenseSupportScreen()) : null,
                )),
                const SizedBox(width: 12),
                Expanded(child: _HomeActionTile(
                  icon: Icons.sync_alt_rounded, title: 'Credit & Return',
                  subtitle: 'Credit and refunds',
                  onTap: access.canAccessCreditReturns ? () => open(const PosCreditReturnsScreen()) : null,
                )),
              ],
            ),
            if (access.canQuickAddProduct) ...[
              const SizedBox(height: 12),
              PosSurface(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.add_box_outlined, color: scheme.primary),
                  title: const Text('Quick Add Product'),
                  subtitle: const Text('Submit a product for review'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const QuickAddScreen()),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: cart.isEmpty || !access.canCompleteSales
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => open(const CheckoutScreen()),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('View cart · ${notifier.itemCount} items'),
                      Text(CustomerPresentation.money(notifier.total,
                          currency: business?.currency)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(height: 12),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Integrates a *verified inventory product* with the existing cart. A scan
/// is NOT a sale and does not send a payment or edit Supabase.
Future<bool> _addRecognizedProduct(
  BuildContext context,
  WidgetRef ref,
  Product product,
  String scanEventId,
) async {
  try {
    final auth = ref.read(authStateProvider);
    final business = auth.activeBusiness;
    final employee = auth.employee;
    final originalBranch = ref.read(branchContextProvider)?.id;
    if (business == null || employee == null ||
        !ref.read(permissionServiceProvider).canCompleteSales ||
        employee.businessId != business.id ||
        product.businessId != business.id ||
        !product.isActive) {
      _showScanError(context, 'This product cannot be sold by this employee.');
      return false;
    }
    if (business.branchesEnabled) {
      final branch = ref.read(branchContextProvider);
      if (branch == null || branch.businessId != business.id) {
        _showScanError(context, 'Select an authorized branch first.');
        return false;
      }
    }

    final pendingStore = await ref.read(pendingSaleStoreProvider.future);
    if (await pendingStore.read() != null) {
      _showScanError(context, 'Resolve the pending sale before scanning more products.');
      return false;
    }

    final levels = await ref.read(productPriceLevelsProvider(product.id).future);
    if (!context.mounted) return false;
    final current = ref.read(authStateProvider);
    if (levels == null ||
        current.activeBusiness?.id != business.id ||
        current.employee?.membershipId != employee.membershipId ||
        !ref.read(permissionServiceProvider).canCompleteSales ||
        !product.isActive) {
      _showScanError(context, 'Unable to verify the product or its Standard price.');
      return false;
    }
    if (business.branchesEnabled) {
      final branch = ref.read(branchContextProvider);
      if (branch == null || branch.businessId != business.id || branch.id != originalBranch) {
        _showScanError(context, 'Branch changed. Scan again after selecting a branch.');
        return false;
      }
    }
    final price = levels.standard;
    if (!price.isFinite || price < 0) {
      _showScanError(context, 'An authorized selling price is required.');
      return false;
    }
    return ref.read(cartProvider.notifier).addScannedProduct(
          product: product,
          authorizedPrice: price,
          authorizedPriceLevel: 'standard',
          scanEventId: scanEventId,
        );
  } catch (_) {
    if (context.mounted) {
      _showScanError(context, 'Unable to add this product. Check your connection or search manually.');
    }
    return false;
  }
}

void _showScanError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _showLogoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to sign out of Trexven POS?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authStateProvider.notifier).logout();
            },
            style: Theme.of(context).elevatedButtonTheme.style,
            child: const Text('Sign Out'),
          ),
        ],
      );
    },
  );
}
