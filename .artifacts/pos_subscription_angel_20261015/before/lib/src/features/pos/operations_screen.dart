import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import 'offline_cash_screen.dart';
import '../inventory/scanner_screen.dart';
import '../../models/product.dart';

final operationsEntitlementsProvider =
    FutureProvider.family<BusinessEntitlements, String>((ref, business) {
      ref.watch(authStateProvider.select((s) => s.employee?.userId));
      final client = ref.read(supabaseProvider);
      final channel = client
          .channel('operations-subscription-$business')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'business_subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: business,
            ),
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        client.removeChannel(channel);
      });
      return BusinessEntitlements.load(OperationsClient.pos(client, business));
    });

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

    final subscription = ref.watch(
      operationsEntitlementsProvider(auth.activeBusiness!.id),
    );

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
          // Subscription status card
          subscription.when(
            data: (s) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(TrexvenRadii.card),
                    ),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Subscription Plan',
                              style: TextStyle(
                                fontSize: TrexvenFontSize.input,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .trexvenColors
                                    .success!
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  TrexvenRadii.status,
                                ),
                              ),
                              child: Text(
                                s.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: TrexvenFontSize.caption,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .trexvenColors
                                      .success!,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.enforced
                              ? 'Plan restrictions are verified online. Pending sales and receipts are retained.'
                              : 'Subscription enforcement is inactive.',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.body,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh subscription status',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => ref.invalidate(
                      operationsEntitlementsProvider(auth.activeBusiness!.id),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(),
            ),
            error: (e, st) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Subscription status unavailable; offline mode active.',
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                        MaterialPageRoute(builder: (_) => const ScannerScreen()),
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
            subtitle: 'Process customer credit accounts, settlements and returns',
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
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
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
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
