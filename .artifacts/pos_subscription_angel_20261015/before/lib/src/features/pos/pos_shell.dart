import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import '../inventory/product_detail_screen.dart';
import '../inventory/product_search_screen.dart';
import '../inventory/scanner_screen.dart';
import 'dashboard_screen.dart';
import 'recent_sales_screen.dart';
import 'operations_screen.dart';
import 'checkout_screen.dart';
import 'cart_provider.dart';
import 'pending_sale_provider.dart';
import '../auth/branch_context.dart';
import 'employee_settings_screen.dart';
import 'package:trexven_operations/trexven_operations.dart';

/// Tabs retain the existing repositories and checkout. Auth, pending-sale and
/// authorized-branch gates remain outside this shell.
class PosShell extends ConsumerStatefulWidget {
  const PosShell({super.key});
  @override
  ConsumerState<PosShell> createState() => _PosShellState();
}

class _PosShellState extends ConsumerState<PosShell> {
  String selected = 'Home';
  final Set<String> visited = {'Home'};
  @override
  Widget build(BuildContext context) {
    final access = ref.watch(permissionServiceProvider);
    final auth = ref.watch(authStateProvider);
    final tabs = <({String label, IconData icon, Widget screen})>[
      (label: 'Home', icon: Icons.home_outlined, screen: DashboardScreen()),
      if (access.hasPermission('view_inventory'))
        (
          label: 'Inventory',
          icon: Icons.inventory_2_outlined,
          screen: ProductSearchScreen(),
        ),
      (label: 'More', icon: Icons.more_horiz, screen: const _MoreScreen()),
    ];
    final selectedIndex = tabs.indexWhere((tab) => tab.label == selected);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs
            .map(
              (tab) => visited.contains(tab.label)
                  ? KeyedSubtree(
                      key: ValueKey(
                        '${auth.activeBusiness?.id}:${auth.employee?.membershipId}:${tab.label}',
                      ),
                      child: tab.screen,
                    )
                  : SizedBox.shrink(),
            )
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          selected = tabs[i].label;
          visited.add(selected);
        }),
        destinations: tabs
            .map(
              (t) => NavigationDestination(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
      ),
    );
  }
}

class _SalesLanding extends ConsumerWidget {
  const _SalesLanding();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionServiceProvider);
    final hasCart = ref.watch(cartProvider).isNotEmpty;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Hub',
              style: TextStyle(
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Checkout, product search & sales history',
              style: TextStyle(
                fontSize: TrexvenFontSize.caption,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: TrexvenSpacing.cardPadding,
        children: [
          if (access.canCompleteSales) ...[
            _SalesActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan Product Barcode',
              subtitle: 'Scan a product to view details or add to cart',
              isPrimary: true,
              onTap: () async {
                final product = await Navigator.push<Product>(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
                if (product != null && context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _SalesActionCard(
              icon: Icons.add_shopping_cart_rounded,
              title: 'New Sale / Search Catalog',
              subtitle: 'Browse catalog and search products for checkout',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
              ),
            ),
            if (hasCart) ...[
              const SizedBox(height: 12),
              _SalesActionCard(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Review Current Cart',
                subtitle: 'Proceed to checkout and complete sale',
                badgeText: '${ref.watch(cartProvider).length} items',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
          _SalesActionCard(
            icon: Icons.receipt_long_rounded,
            title: 'Sales History',
            subtitle: 'View authorized business transactions and receipts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecentSalesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SalesActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final fgColor = isPrimary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final subColor = isPrimary
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: Container(
          padding: TrexvenSpacing.cardPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
            border: isPrimary
                ? null
                : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.16)
                      : theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                ),
                child: Icon(
                  icon,
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: fgColor,
                              fontSize: TrexvenFontSize.input,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius:
                                  BorderRadius.circular(TrexvenRadii.status),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: TrexvenFontSize.caption,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subColor,
                        fontSize: TrexvenFontSize.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: subColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreScreen extends ConsumerWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);
    final employee = auth.employee;
    final business = auth.activeBusiness;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'More Options',
          style: TextStyle(
            fontSize: TrexvenFontSize.section,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: TrexvenSpacing.cardPadding,
        children: [
          // User Profile Card Header
          Container(
            padding: TrexvenSpacing.cardPadding,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  child: Text(
                    (employee?.name.isNotEmpty == true)
                        ? employee!.name[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee?.name ?? 'My Profile',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.input,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${business?.name ?? 'No Business'} · ${employee?.employeeCode ?? ''}',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(TrexvenRadii.status),
                        ),
                        child: Text(
                          employee?.role.name.toUpperCase() ?? 'EMPLOYEE',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.caption,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionGroupTitle(title: 'OPERATIONS & ACCESS'),
          const SizedBox(height: 8),
          _MoreMenuContainer(
            children: [
              if (!auth.offlineCashOnly)
                _MoreMenuItem(
                  icon: Icons.business_outlined,
                  title: 'Switch authorized business',
                  subtitle: 'Change active business context',
                  onTap: () async {
                    try {
                      if (await (await ref.read(
                            pendingSaleStoreProvider.future,
                          )).read() !=
                          null) {
                        throw StateError(
                          'Recover the retained sale before switching business.',
                        );
                      }
                      if (ref.read(cartProvider).isNotEmpty) {
                        throw StateError(
                          'Finish or remove the unsubmitted cart before switching business.',
                        );
                      }
                      final rows =
                          await ref
                                  .read(supabaseProvider)
                                  .rpc('get_trexven_pos_context')
                              as List;
                      if (!context.mounted) return;
                      final id = await showDialog<String>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Select authorized business'),
                          children: [
                            for (final row in rows)
                              if (!access.isOwner ||
                                  (row['employee'] as Map)['role'] == 'owner')
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    (row['business'] as Map)['id'] as String,
                                  ),
                                  child: Text(
                                    (row['business'] as Map)['business_name']
                                            ?.toString() ??
                                        'Business',
                                  ),
                                ),
                          ],
                        ),
                      );
                      if (id != null && context.mounted) {
                        await ref
                            .read(authStateProvider.notifier)
                            .restoreSession(businessId: id);
                        ref.invalidate(branchContextProvider);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Business switch was not confirmed. Recover pending sales and finish the current cart before verifying access online.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              _MoreMenuItem(
                icon: Icons.tune_rounded,
                title: 'Operations & Workflows',
                subtitle:
                    'Credit, returns, inventory, cash drawers & sync',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PosOperationsScreen()),
                ),
              ),
              if (!auth.offlineCashOnly && auth.activeBusiness != null)
                _MoreMenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Business notifications',
                  subtitle: 'Operational alerts & messages',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationCenterScreen(
                        api: OperationsClient.pos(
                          ref.read(supabaseProvider),
                          auth.activeBusiness!.id,
                        ),
                        open: (context, route, referenceId) {
                          final current = ref.read(permissionServiceProvider);
                          if ((route == 'inventory' &&
                                  current.hasPermission('view_inventory')) ||
                              (route == 'cash' &&
                                  current.hasPermission('review_cash_shifts'))) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PosOperationsScreen(),
                              ),
                            );
                          } else if (route == 'employees' &&
                              current.hasPermission('manage_employees')) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EmployeeAccessScreen(
                                  api: OperationsClient.pos(
                                    ref.read(supabaseProvider),
                                    auth.activeBusiness!.id,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Current permission is required to open this notification.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              if (access.hasPermission('manage_employees') &&
                  auth.activeBusiness != null)
                _MoreMenuItem(
                  icon: Icons.group_outlined,
                  title: 'Employees & permissions',
                  subtitle: 'Manage staff accounts and authority',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmployeeAccessScreen(
                        api: OperationsClient.pos(
                          ref.read(supabaseProvider),
                          auth.activeBusiness!.id,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionGroupTitle(title: 'PREFERENCES & SECURITY'),
          const SizedBox(height: 8),
          _MoreMenuContainer(
            children: [
              _MoreMenuItem(
                icon: Icons.settings_outlined,
                title: 'My Settings',
                subtitle: 'Appearance, password & device recovery',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeeSettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionGroupTitle(title: 'SUPPORT & ACCOUNT'),
          const SizedBox(height: 8),
          _MoreMenuContainer(
            children: [
              _MoreMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Help & Safe Recovery',
                subtitle: 'Guidance for offline sales & troubleshooting',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => const AlertDialog(
                    scrollable: true,
                    title: Text('Safe recovery'),
                    content: Text(
                      'Keep pending transactions and retry their original request. Never collect payment twice. Contact the business owner for access or payment discrepancies. Do not uninstall while sales are unsynced.',
                    ),
                  ),
                ),
              ),
              _MoreMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About TREXVEN POS',
                subtitle: 'Version and system information',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'TREXVEN POS',
                  applicationVersion: const String.fromEnvironment(
                    'TREXVEN_BUILD_VERSION',
                    defaultValue: 'Development build — version not supplied',
                  ),
                ),
              ),
              _MoreMenuItem(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'End current terminal session',
                isDestructive: true,
                onTap: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      scrollable: true,
                      title: const Text('Sign out?'),
                      content: const Text(
                        'Pending sales and encrypted queues stay on this device. The original employee must sign in to recover them. Unsubmitted cart changes are not a completed sale.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    await ref.read(authStateProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionGroupTitle extends StatelessWidget {
  final String title;
  const _SectionGroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: TrexvenFontSize.caption,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MoreMenuContainer extends StatelessWidget {
  final List<Widget> children;
  const _MoreMenuContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDestructive
              ? theme.colorScheme.error.withValues(alpha: 0.08)
              : theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: TrexvenFontSize.input,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: TrexvenFontSize.caption,
                color: isDestructive
                    ? theme.colorScheme.error.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
