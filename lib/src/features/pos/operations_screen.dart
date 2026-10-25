import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../../ui/trexven_ui.dart';
import '../auth/permission_service.dart';
import 'offline_cash_screen.dart';
import 'credit_returns_screen.dart';
import 'branch_transfers_screen.dart';
import 'expense_support_screen.dart';
import '../inventory/inventory_operations_screen.dart';
import '../inventory/angel_scan_review_screen.dart';
import '../inventory/angel_scan_client.dart';
import '../auth/branch_context.dart';

class PosOperationsScreen extends ConsumerWidget {
  const PosOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);
    if (auth.activeBusiness == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operations')),
        body: const Center(child: Text('Select a business.')),
      );
    }

    final workflows = <_Workflow>[
      if (access.canAngelInventory)
        _Workflow('Angel inventory', 'Scan & request owner approval', Icons.document_scanner_outlined, () {
          final business = auth.activeBusiness!;
          final employee = auth.employee!;
          final branch = business.branchesEnabled ? ref.read(branchContextProvider)?.id : null;
          if (business.branchesEnabled && branch == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an authorized branch.'))); return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => AngelScanReviewScreen(
            api: AngelScanClient(ref.read(supabaseProvider), businessId: business.id, branchId: branch, inventoryMode: true),
            contextIsCurrent: () => ref.read(permissionServiceProvider).canAngelInventory &&
              ref.read(authStateProvider).activeBusiness?.id == business.id &&
              ref.read(authStateProvider).employee?.membershipId == employee.membershipId &&
              (!business.branchesEnabled || ref.read(branchContextProvider)?.id == branch),
          )));
        }),
      if (access.canAccessExpenses)
        _Workflow('Expenses', 'Cash spending & history', Icons.payments_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosExpenseSupportScreen()))),
      if (auth.activeBusiness!.branchesEnabled && (access.isOwner || access.isManager) && access.hasPermission('transfer_stock'))
        _Workflow('Branch Transfers', 'Dispatch & receive stock', Icons.local_shipping_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosBranchTransfersScreen()))),
      if (access.hasPermission('cash_shifts'))
        _Workflow(
          'Cash Drawers', 'Shifts & balances', Icons.account_balance_wallet_outlined,
          () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => CashShiftScreen(
              api: OperationsClient.pos(ref.read(supabaseProvider), auth.activeBusiness!.id),
              owner: access.isOwner,
              reviewer: access.hasPermission('review_cash_shifts'),
            ),
          )),
        ),
      if (access.hasPermission('view_inventory'))
        _Workflow(
          'Inventory', 'Stock & adjustments', Icons.inventory_2_outlined,
          () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PosInventoryOperationsScreen(),
          )),
        ),
      if (access.canAccessCreditReturns) _Workflow(
        'Credit & Returns', 'Repayments & refunds', Icons.receipt_long_outlined,
        () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PosCreditReturnsScreen(),
        )),
      ),
      if (access.hasPermission('offline_cash'))
        _Workflow(
          'Offline Sync', 'Pending transactions', Icons.sync_rounded,
          () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const OfflineCashScreen(),
          )),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Operations')),
      body: ListView(
        padding: TrexvenSpacing.pagePadding,
        children: [
          Text('Manage daily business workflows',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          const SizedBox(height: PosSpace.lg),
          Text('DAILY OPERATIONS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            )),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final workflow in workflows)
                  SizedBox(
                    width: width,
                    child: _WorkflowCard(workflow: workflow),
                  ),
              ],
            );
          }),
          const SizedBox(height: PosSpace.lg),
          Container(
            padding: const EdgeInsets.all(PosSpace.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(children: [
              Icon(Icons.shield_outlined, size: 20,
                color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permission-aware access',
                    style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 3),
                  Text('Only authorized workflows are displayed',
                    style: Theme.of(context).textTheme.bodySmall),
                ],
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Workflow {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _Workflow(this.title, this.subtitle, this.icon, this.onTap);
}

class _WorkflowCard extends StatelessWidget {
  final _Workflow workflow;
  const _WorkflowCard({required this.workflow});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      child: InkWell(
        onTap: workflow.onTap,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(PosSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(PosSpace.sm),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(PosSpace.md),
              ),
              child: Icon(workflow.icon, size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: PosSpace.sm),
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workflow.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: PosSpace.xs),
                Text(workflow.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

