
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
import 'pending_sale_provider.dart';
import 'checkout_screen.dart';
import 'recent_sales_screen.dart';
import 'operations_screen.dart';

class DashboardScreen extends ConsumerWidget {
const DashboardScreen({super.key});

@override
Widget build(BuildContext context, WidgetRef ref) {
final authState = ref.watch(authStateProvider);
final cart = ref.watch(cartProvider);

final business = authState.activeBusiness;
final employee = authState.employee;
final access = ref.watch(permissionServiceProvider);

final cartTotal = ref.watch(cartProvider.notifier).total;

final cartItemCount = cart.fold<num>(
0,
(total, item) => total + item.quantity,
);

return Scaffold(
appBar: business?.branchesEnabled == true
? AppBar(
title: Text(
ref.watch(branchContextProvider)?.name ?? 'Select branch',
),
actions: [
TextButton(
onPressed: () {
try {
ref
    .read(branchContextProvider.notifier)
    .clear(hasCart: cart.isNotEmpty);
ref.invalidate(authorizedBranchesProvider);
} on StateError catch (error) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(CustomerPresentation.error(error)),
),
);
}
},
child: Text('Change branch'),
),
],
)
    : null,
backgroundColor: Theme.of(context).scaffoldBackgroundColor,
body: SafeArea(
child: Stack(
children: [
CustomScrollView(
slivers: [
SliverPadding(
padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
sliver: SliverList(
delegate: SliverChildListDelegate([
_DashboardHeader(
businessName: business?.name ?? 'Trexven POS',
employeeName: employee?.name ?? 'Employee',
employeeRole: employee?.role.name ?? 'Employee',
onLogout: () {
_showLogoutDialog(context, ref);
},
),

SizedBox(height: TrexvenSpacing.sectionGap),

_PrimaryAction(
title: 'Scan Product',
subtitle: 'Angel Scan • barcode checkout ready',
onTap: () {
Navigator.push<void>(
context,
MaterialPageRoute(
builder: (_) => ScannerScreen(
onProductMatched: (product, scanEventId) =>
_addRecognizedProduct(
context,
ref,
product,
scanEventId,
),
),
),
);
},
),

const SizedBox(height: 20),
const _SectionHeader(title: 'Quick Actions', subtitle: ''),
const SizedBox(height: 12),

Row(
children: [
Expanded(
child: _ActionCard(
icon: Icons.search_rounded,
title: 'Search',
subtitle: 'Find product',
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ProductSearchScreen(),
),
);
},
),
),
SizedBox(width: 12),
Expanded(
child: _ActionCard(
icon: Icons.history_rounded,
title: 'Sales History',
subtitle: 'View transactions',
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => RecentSalesScreen(),
),
);
},
),
),
],
),

const SizedBox(height: 12),
Row(
children: [
Expanded(child: _ActionCard(
icon: Icons.account_balance_wallet_outlined,
title: 'Expenses',
subtitle: 'Integration pending',
onTap: () => _showUnavailable(context, 'Expenses'),
)),
const SizedBox(width: 12),
Expanded(child: _ActionCard(
icon: Icons.sync_alt_rounded,
title: 'Credit & Return',
subtitle: 'Integration pending',
onTap: () => _showUnavailable(context, 'Credit & Return'),
)),
],
),
const SizedBox(height: 12),
if (access.canQuickAddProduct)
_QuickAddAction(onTap: () {
Navigator.push(context, MaterialPageRoute(
builder: (_) => QuickAddScreen(),
));
}),
]),
),
),
],
),

if (cart.isNotEmpty && access.canCompleteSales)
Positioned(
left: 16,
right: 16,
bottom: 16,
child: _CheckoutBar(
itemCount: cartItemCount,
total: cartTotal,
onTap: () {
Navigator.push(
context,
MaterialPageRoute(builder: (_) => CheckoutScreen()),
);
},
),
),
],
),
),
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

void _showUnavailable(BuildContext context, String feature) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
content: Text('$feature needs its existing screen and permission wiring.'),
));
}

void _showLogoutDialog(BuildContext context, WidgetRef ref) {
showDialog(
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
style: ElevatedButton.styleFrom(
backgroundColor: Theme.of(context).colorScheme.primary,
foregroundColor: Theme.of(context).colorScheme.onPrimary,
),
child: Text('Sign Out'),
),
],
);
},
);
}
}

class _DashboardHeader extends StatelessWidget {
final String businessName;
final String employeeName;
final String employeeRole;
final VoidCallback onLogout;

const _DashboardHeader({
required this.businessName,
required this.employeeName,
required this.employeeRole,
required this.onLogout,
});

String _formatRole(String value) {
if (value.isEmpty) return 'Employee';

return value
    .split('_')
    .map(
(word) =>
'${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
)
    .join(' ');
}

@override
Widget build(BuildContext context) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
businessName,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: TrexvenFontSize.input,
fontWeight: FontWeight.w500,
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
),
SizedBox(height: 5),
Text(
'Hello, $employeeName',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 25,
fontWeight: FontWeight.w700,
letterSpacing: -0.8,
color: Theme.of(context).colorScheme.onSurface,
),
),
SizedBox(height: 5),
Text(
'${_formatRole(employeeRole)} • Ready for business',
style: TextStyle(
fontSize: TrexvenFontSize.body,
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
),
],
),
),
SizedBox(width: 16),
Material(
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: InkWell(
onTap: onLogout,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: Container(
width: 48,
height: 48,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(TrexvenRadii.card),
border: Border.all(
color: Theme.of(context).colorScheme.outlineVariant,
),
),
child: Icon(
Icons.power_settings_new_rounded,
color: Theme.of(context).colorScheme.onSurface,
size: 21,
),
),
),
),
],
);
}
}

class _SectionHeader extends StatelessWidget {
final String title;
final String subtitle;

const _SectionHeader({required this.title, required this.subtitle});

@override
Widget build(BuildContext context) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
fontSize: TrexvenFontSize.section,
fontWeight: FontWeight.w700,
letterSpacing: -0.4,
color: Theme.of(context).colorScheme.onSurface,
),
),
SizedBox(height: 3),
Text(
subtitle,
style: TextStyle(
fontSize: TrexvenFontSize.body,
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
),
],
);
}
}

class _PrimaryAction extends StatelessWidget {
final String title;
final String subtitle;
final VoidCallback onTap;

const _PrimaryAction({
required this.title,
required this.subtitle,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Material(
color: Theme.of(context).colorScheme.primary,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
child: Row(
children: [
Container(
width: 54,
height: 54,
decoration: BoxDecoration(
color: Theme.of(
context,
).colorScheme.onPrimary.withValues(alpha: 0.16),
borderRadius: BorderRadius.circular(TrexvenRadii.card),
),
child: Icon(
Icons.qr_code_scanner_rounded,
color: Theme.of(context).colorScheme.onPrimary,
size: 27,
),
),
SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
color: Theme.of(context).colorScheme.onPrimary,
fontSize: TrexvenFontSize.section,
fontWeight: FontWeight.w700,
letterSpacing: -0.2,
),
),
SizedBox(height: 4),
Text(
subtitle,
style: TextStyle(
color: Theme.of(
context,
).colorScheme.onPrimary.withValues(alpha: 0.78),
fontSize: TrexvenFontSize.body,
height: 1.3,
),
),
],
),
),
SizedBox(width: 8),
Icon(
Icons.arrow_forward_ios_rounded,
color: Theme.of(context).colorScheme.onPrimary,
size: 17,
),
],
),
),
),
);
}
}

class _ActionCard extends StatelessWidget {
final IconData icon;
final String title;
final String subtitle;
final VoidCallback onTap;

const _ActionCard({
required this.icon,
required this.title,
required this.subtitle,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Material(
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: Container(
constraints: const BoxConstraints(minHeight: 102),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(TrexvenRadii.card),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: Theme.of(
context,
).colorScheme.primary.withValues(alpha: .08),
borderRadius: BorderRadius.circular(TrexvenRadii.card),
),
child: Icon(
icon,
color: Theme.of(context).colorScheme.primary,
size: 23,
),
),
const SizedBox(height: 8),
Text(
title,
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: TrexvenFontSize.input,
fontWeight: FontWeight.w700,
),
),
SizedBox(height: 3),
Text(
subtitle,
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: TrexvenFontSize.caption,
),
),
],
),
),
),
);
}
}

class _QuickAddAction extends StatelessWidget {
final VoidCallback onTap;

const _QuickAddAction({required this.onTap});

@override
Widget build(BuildContext context) {
return Material(
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(TrexvenRadii.card),
),
child: Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: Theme.of(
context,
).colorScheme.primary.withValues(alpha: .08),
borderRadius: BorderRadius.circular(TrexvenRadii.card),
),
child: Icon(
Icons.add_box_outlined,
color: Theme.of(context).colorScheme.primary,
),
),
SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Add Product',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: TrexvenFontSize.input,
fontWeight: FontWeight.w700,
),
),
SizedBox(height: 3),
Text(
'Create an inventory item',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: TrexvenFontSize.body,
),
),
],
),
),
Icon(
Icons.chevron_right_rounded,
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
],
),
),
),
);
}
}

class _CheckoutBar extends StatelessWidget {
final num itemCount;
final double total;
final VoidCallback onTap;

const _CheckoutBar({
required this.itemCount,
required this.total,
required this.onTap,
});

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final badge = Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
decoration: BoxDecoration(
color: theme.colorScheme.onPrimary.withValues(alpha: .18),
borderRadius: BorderRadius.circular(TrexvenRadii.status),
),
child: Text(
'$itemCount',
style: TextStyle(
color: theme.colorScheme.onPrimary,
fontWeight: FontWeight.w700,
),
),
);
final title = Text(
'View Cart',
style: theme.textTheme.bodyLarge?.copyWith(
color: theme.colorScheme.onPrimary,
fontWeight: FontWeight.w700,
),
);
final amount = Text(
'₦${total.toStringAsFixed(0)}',
style: theme.textTheme.titleLarge?.copyWith(
color: theme.colorScheme.onPrimary,
),
);
final arrow = Icon(
Icons.arrow_forward_rounded,
color: theme.colorScheme.onPrimary,
size: 20,
);
return Material(
borderRadius: BorderRadius.circular(TrexvenRadii.card),
color: theme.colorScheme.primary,
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(TrexvenRadii.card),
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
child: MediaQuery.textScalerOf(context).scale(16) > 20
? Column(
mainAxisSize: MainAxisSize.min,
children: [
Row(
children: [
badge,
const SizedBox(width: 12),
Expanded(child: title),
],
),
const SizedBox(height: 8),
Row(
children: [
Expanded(child: amount),
const SizedBox(width: 8),
arrow,
],
),
],
)
    : Row(
children: [
badge,
const SizedBox(width: 12),
Expanded(child: title),
Flexible(child: amount),
const SizedBox(width: 8),
arrow,
],
),
),
),
);
}
}
