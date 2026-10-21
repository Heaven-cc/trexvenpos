import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/employee.dart';
import 'auth_provider.dart';
import 'branch_context.dart';
import 'permission_service.dart';

/// Snapshot for one online workflow. Server RPCs remain authoritative at commit.
class PosWorkflowAccess {
  final String userId, employeeId, membershipId, businessId, authorizationKey;
  final String? branchId;
  final bool branchesEnabled;
  const PosWorkflowAccess({
    required this.userId, required this.employeeId, required this.membershipId,
    required this.businessId, required this.authorizationKey,
    required this.branchId, required this.branchesEnabled,
  });

  factory PosWorkflowAccess.capture(WidgetRef ref) {
    final auth = ref.read(authStateProvider);
    final employee = auth.employee;
    final business = auth.activeBusiness;
    if (employee == null || business == null || auth.offlineCashOnly || !employee.isActive) {
      throw StateError('Connect and verify your active employee and business.');
    }
    final branch = ref.read(branchContextProvider);
    if (business.branchesEnabled && (branch == null || branch.businessId != business.id)) {
      throw StateError('Select an authorized branch.');
    }
    return PosWorkflowAccess(
      userId: employee.userId, employeeId: employee.id,
      membershipId: employee.membershipId, businessId: business.id,
      authorizationKey: ref.read(permissionServiceProvider).authorizationKey,
      branchId: business.branchesEnabled ? branch!.id : null,
      branchesEnabled: business.branchesEnabled,
    );
  }

  String get key => '$userId:$employeeId:$membershipId:$businessId:$branchesEnabled:$branchId:$authorizationKey';

  bool isCurrent(WidgetRef ref) {
    if (!ref.context.mounted) return false;
    try {
      return PosWorkflowAccess.capture(ref).key == key &&
          ref.read(supabaseProvider).auth.currentUser?.id == userId;
    } catch (_) {
      return false;
    }
  }

  Future<void> verify(WidgetRef ref) async {
    if (!isCurrent(ref)) throw StateError('Workflow access changed. Reopen in the current context.');
    final client = ref.read(supabaseProvider);
    final response = await client.rpc('get_trexven_pos_context',
      params: {'p_business_id': businessId}).timeout(const Duration(seconds: 20));
    if (!isCurrent(ref)) throw StateError('Workflow context changed during verification.');
    var matches = false;
    if (response is List && response.length == 1) {
      final row = Map<String, dynamic>.from(response.single as Map);
      final business = Map<String, dynamic>.from(row['business'] as Map);
      final employee = Employee.fromJson(Map<String, dynamic>.from(row['employee'] as Map));
      matches = business['id'] == businessId &&
          business['branches_enabled'] == branchesEnabled &&
          employee.id == employeeId && employee.userId == userId &&
          employee.businessId == businessId && employee.membershipId == membershipId &&
          employee.isActive &&
          PermissionService(employee).authorizationKey == authorizationKey;
    }
    if (!matches) {
      // Refresh visible access; never reuse a revoked snapshot for a new action.
      await ref.read(authStateProvider.notifier).restoreSession(businessId: businessId);
      throw StateError('Employee permissions changed. Reopen the authorized workflow.');
    }
    if (branchesEnabled) {
      final branch = await client.from('branches').select('id')
          .eq('business_id', businessId).eq('id', branchId!)
          .eq('is_active', true).maybeSingle().timeout(const Duration(seconds: 20));
      if (!isCurrent(ref)) throw StateError('Workflow context changed during verification.');
      if (branch == null) {
        ref.invalidate(authorizedBranchesProvider);
        throw StateError('Branch access changed. Select an authorized branch.');
      }
    }
    if (!isCurrent(ref)) throw StateError('Workflow context changed during verification.');
  }
}
