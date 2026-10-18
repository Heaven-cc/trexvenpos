
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
  return Scaffold(
    appBar: AppBar(title: Text(business?.name ?? 'TREXVEN POS'),
      actions: [
        if (business?.branchesEnabled == true)
          IconButton(tooltip: 'Change branch', icon: const Icon(Icons.store_outlined), onPressed: () {
            try {
              ref.read(branchContextProvider.notifier).clear(hasCart: cart.isNotEmpty);
              ref.invalidate(authorizedBranchesProvider);
            } on StateError catch (error) { _showScanError(context, CustomerPresentation.error(error)); }
          }),
        IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout_rounded),
          onPressed: () => _showLogoutDialog(context, ref)),
      ]),
    body: SafeArea(top: false, child: ListView(padding: PosSpace.page, children: [
      Text('Hello, ${employee?.name ?? 'Employee'}', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(business?.branchesEnabled == true
          ? ref.watch(branchContextProvider)?.name ?? 'Select branch'
          : 'Ready for your next sale', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      FilledButton.icon(icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan Product'),
        onPressed: () => open(ScannerScreen(onProductMatched: (product, scanEventId) =>
          _addRecognizedProduct(context, ref, product, scanEventId)))),
      const SizedBox(height: 20),
      Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      PosSurface(padding: EdgeInsets.zero, child: Column(children: [
        PosActionRow(icon: Icons.search_rounded, title: 'Search products', subtitle: 'Catalog, barcode or part number',
          onTap: () => open(const ProductSearchScreen())),
        const Divider(indent: 64),
        PosActionRow(icon: Icons.history_rounded, title: 'Sales History', subtitle: 'Transactions and receipts',
          onTap: () => open(const RecentSalesScreen())),
        const Divider(indent: 64),
        PosActionRow(icon: Icons.account_balance_wallet_outlined, title: 'Expenses',
          subtitle: 'Expense recording requires backend support',
          onTap: () => open(const PosExpenseSupportScreen())),
        const Divider(indent: 64),
        PosActionRow(icon: Icons.sync_alt_rounded, title: 'Credit & Returns', subtitle: 'Customer credit, repayments and returns',
          onTap: () => open(const PosCreditReturnsScreen())),
        if (access.canQuickAddProduct) ...[
          const Divider(indent: 64),
          PosActionRow(icon: Icons.add_box_outlined, title: 'Quick Add Product', subtitle: 'Submit a product for review',
            onTap: () => open(const QuickAddScreen())),
        ],
      ])),
    ])),
    bottomNavigationBar: cart.isEmpty || !access.canCompleteSales ? null : SafeArea(top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(onPressed: () => open(const CheckoutScreen()),
          child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 4,
            children: [Text('View cart · ${notifier.itemCount} items'),
              Text(CustomerPresentation.money(notifier.total, currency: business?.currency))])))),
  );
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

// An unresolved payment must not be mixed with a new scanned sale.
final pendingStore = await ref.read(pendingSaleStoreProvider.future);
if (await pendingStore.read() != null) {
_showScanError(context, 'Resolve the pending sale before scanning more products.');
return false;
}

// Same default tier as ProductDetailScreen. Angel does not choose price.
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
if (branch == null || branch.businessId != business.id) {
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
title: Text(
'Sign Out',
style: TextStyle(fontWeight: FontWeight.w700),
),
content: Text('Are you sure you want to sign out of Trexven POS?'),
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
child: Text('Sign Out'),
),
],
);
},
);
}
}
