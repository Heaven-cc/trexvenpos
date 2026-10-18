import '../../ui/trexven_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import '../inventory/product_provider.dart';
import 'sales_provider.dart';

/// POS adapter for the existing shared financial workflows. The backend remains
/// authoritative for membership, branch assignments and sensitive manager grants.
class PosCreditReturnsScreen extends ConsumerWidget {
  const PosCreditReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);
    final selectedBranch = ref.watch(branchContextProvider);
    final business = auth.activeBusiness;
    final employee = auth.employee;
    if (business == null ||
        employee == null ||
        !employee.isActive ||
        auth.offlineCashOnly) {
      return Scaffold(
        appBar: AppBar(title: const Text('Credit & Returns')),
        body: const PosStateView(title: 'Verify your access',
          message: 'Connect and verify your current employee, business and branch before opening this workflow.',
          icon: Icons.lock_outline),
      );
    }
    if (business.branchesEnabled && selectedBranch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Credit & Returns')),
        body: const PosStateView(title: 'Select an authorized branch first.', icon: Icons.store_outlined),
      );
    }
    final branchId = business.branchesEnabled ? selectedBranch!.id : null;
    final permissions = <String>{
      for (final permission in const [
        'complete_sales',
        'record_credit_repayment',
        'approve_credit',
        'inspect_returns',
        'approve_refund',
        'reverse_credit_repayment',
        'review_cash_shifts',
        'view_finance',
        'offline_cash',
      ])
        if (access.hasPermission(permission)) permission,
    };
    final permissionKey = (permissions.toList()..sort()).join(',');
    return FinancialOperationsScreen(
      key: ValueKey(
        '${business.id}:${employee.userId}:${employee.membershipId}:$branchId:${employee.role}:$permissionKey',
      ),
      api: OperationsClient.pos(ref.watch(supabaseProvider), business.id),
      owner: access.hasFullAccess,
      posWorkspace: true,
      manager: access.isManager,
      permissions: permissions,
      branchId: branchId,
      currency: business.currency,
      contextIsCurrent: () {
        final current = ref.read(authStateProvider);
        return !current.offlineCashOnly &&
            current.employee?.isActive == true &&
            current.employee?.userId == employee.userId &&
            current.employee?.membershipId == employee.membershipId &&
            current.activeBusiness?.id == business.id &&
            (!business.branchesEnabled ||
                ref.read(branchContextProvider)?.id == branchId);
      },
      onRecordsChanged: () {
        // Return inventory and sale reads refresh from the shared records. No
        // mirrored sale or secondary balance is created to synchronize clients.
        ref.invalidate(productSearchProvider);
        ref.invalidate(recentSalesProvider);
      },
    );
  }
}
