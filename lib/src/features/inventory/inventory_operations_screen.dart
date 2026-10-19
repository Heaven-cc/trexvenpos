import '../../ui/trexven_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import 'product_provider.dart';
import 'scanner_screen.dart';

/// Supplies current POS grants and branch context to the existing shared page.
/// Server RPCs and RLS remain authoritative for every stock operation.
class PosInventoryOperationsScreen extends ConsumerWidget {
  const PosInventoryOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);
    final selectedBranch = ref.watch(branchContextProvider);
    final business = auth.activeBusiness;
    final employee = auth.employee;
    if (business == null || employee == null || !employee.isActive ||
        auth.offlineCashOnly || !access.hasPermission('view_inventory')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const PosStateView(title: 'Verify your access',
          message: 'Connect and verify your current employee, business and branch before opening this workflow.',
          icon: Icons.lock_outline),
      );
    }
    if (business.branchesEnabled && selectedBranch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const PosStateView(title: 'Select an authorized branch first.', icon: Icons.store_outlined),
      );
    }
    final branchId = business.branchesEnabled ? selectedBranch!.id : null;
    final permissions = <String>{
      for (final permission in const [
        'view_inventory', 'stocktake', 'approve_stocktake', 'adjust_stock',
        'dispose_stock', 'restore_stock', 'writeoff_stock', 'supplier_returns',
        'approve_supplier_returns',
      ])
        if (access.hasPermission(permission)) permission,
    };
    final permissionKey = (permissions.toList()..sort()).join(',');
    return InventoryOperationsScreen(
      key: ValueKey('${business.id}:${employee.userId}:${employee.membershipId}:$branchId:${employee.role}:$permissionKey'),
      api: OperationsClient.pos(ref.watch(supabaseProvider), business.id),
      permissions: permissions,
      manager: access.isManager,
      branchId: branchId,
      branchName: business.branchesEnabled ? selectedBranch!.name : null,
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
      scanBarcode: (context) async {
        final product = await Navigator.push<Product>(context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()));
        return product == null ? null : 'product:${product.id}';
      },
      onRecordsChanged: () => ref.invalidate(productSearchProvider),
    );
  }
}
