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
      if (access.hasPermission('record_expenses') || access.hasPermission('view_pos_expenses'))
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
      _Workflow(
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Manage daily business workflows',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          const SizedBox(height: 24),
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF1C2D46) : Theme.of(context).colorScheme.surface;
    final foreground = dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final muted = dark ? const Color(0xFFA9BDD8) : Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: workflow.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dark
              ? const Color(0xFF344761)
              : Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF294A79) : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(workflow.icon, size: 20,
                  color: dark ? const Color(0xFFA9CBFF) : Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(workflow.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700, color: foreground)),
              const SizedBox(height: 4),
              Text(workflow.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_outward_rounded, size: 17, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
