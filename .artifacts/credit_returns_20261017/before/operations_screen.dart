import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import 'offline_cash_screen.dart';
import '../inventory/scanner_screen.dart';
import '../../models/product.dart';

class PosOperationsScreen extends ConsumerWidget {
  const PosOperationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);

    if (auth.activeBusiness == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Operations')),
        body: Center(child: TrexvenEmptyState(title: 'Select a business.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operational Workflows',
              style: TextStyle(
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Cash drawers, inventory stocktakes, credit & offline sync',
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
          if (access.hasPermission('cash_shifts'))
            _OpTile(
              icon: Icons.point_of_sale_rounded,
              title: 'Shared Cash Drawers',
              subtitle: 'Manage shift drawers, floats, and cash balances',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CashShiftScreen(
                    api: OperationsClient.pos(
                      ref.read(supabaseProvider),
                      auth.activeBusiness!.id,
                    ),
                    owner: access.isOwner,
                    reviewer: access.hasPermission('review_cash_shifts'),
                  ),
                ),
              ),
            ),

          if (access.hasPermission('view_inventory'))
            _OpTile(
              icon: Icons.inventory_2_rounded,
              title: 'Stocktaking & Inventory',
              subtitle: 'Count stock, record adjustments & audit inventory',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryOperationsScreen(
                    scanBarcode: (context) async {
                      final product = await Navigator.push<Product>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScannerScreen(),
                        ),
                      );
                      return product?.barcode;
                    },
                    api: OperationsClient.pos(
                      ref.read(supabaseProvider),
                      auth.activeBusiness!.id,
                    ),
                  ),
                ),
              ),
            ),

          _OpTile(
            icon: Icons.receipt_long_rounded,
            title: 'Credit, Repayments & Returns',
            subtitle:
                'Process customer credit accounts, settlements and returns',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FinancialOperationsScreen(
                  api: OperationsClient.pos(
                    ref.read(supabaseProvider),
                    auth.activeBusiness!.id,
                  ),
                  owner: access.isOwner,
                ),
              ),
            ),
          ),

          if (access.hasPermission('offline_cash'))
            _OpTile(
              icon: Icons.sync_rounded,
              title: 'Offline Cash & Synchronization',
              subtitle: 'Manage offline queue and sync pending cash sales',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineCashScreen()),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: TrexvenFontSize.input,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: TrexvenFontSize.body,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
