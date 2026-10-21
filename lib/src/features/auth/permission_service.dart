import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/employee.dart';
import 'auth_provider.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final employee = ref.watch(
    authStateProvider.select((state) => state.employee),
  );

  return PermissionService(
    employee,
    offlineCashOnly: ref.watch(
      authStateProvider.select((state) => state.offlineCashOnly),
    ),
  );
});

class PermissionService {
  final Employee? _employee;
  final bool offlineCashOnly;

  const PermissionService(this._employee, {this.offlineCashOnly = false});

  static const String overridePricePermission = 'override_price';

  static const String applyDiscountPermission = 'apply_discount';

  static const String manageInventoryPermission = 'edit_products';

  static const String deleteSalesPermission = 'delete_sales';

  static const String quickAddProductPermission = 'add_products';

  bool get isLoggedIn => _employee != null;

  bool get isActive {
    return _employee?.isActive ?? false;
  }

  bool get isOwner {
    return !offlineCashOnly && _employee?.role == EmployeeRole.owner;
  }

  bool get isAdmin {
    return !offlineCashOnly && (_employee?.isAdmin ?? false);
  }

  bool get isManager {
    return !offlineCashOnly && (_employee?.isManager ?? false);
  }

  bool get isCashier {
    return _employee?.isCashier ?? false;
  }

  bool get hasFullAccess {
    return isActive && isOwner;
  }

  bool hasPermission(String permission) {
    if (offlineCashOnly &&
        !const {'pos_access', 'complete_sales'}.contains(permission))
      return false;
    if (permission == 'view_profit') return false;
    if (!isActive) {
      return false;
    }

    // Only owners have unrestricted access; legacy admin needs explicit grants.
    if (hasFullAccess) {
      return true;
    }

    return _employee?.hasPermission(permission) ?? false;
  }

  String get authorizationKey {
    final grants = [...?_employee?.permissions]..sort();
    final denials = [...?_employee?.deniedPermissions]..sort();
    return '${_employee?.role.name}:${_employee?.status.name}:${grants.join(',')}:${denials.join(',')}:$offlineCashOnly';
  }

  bool get canRecordExpenses =>
      !offlineCashOnly && hasPermission('pos_access') && hasPermission('record_expenses');

  bool get canViewBranchExpenses =>
      !offlineCashOnly && hasPermission('pos_access') &&
      (isOwner || isManager) && hasPermission('view_pos_expenses');

  bool get canAccessExpenses => canRecordExpenses || canViewBranchExpenses;

  bool get canAccessCreditReturns =>
      !offlineCashOnly && isActive &&
      (isOwner || hasPermission('complete_sales') ||
       hasPermission('record_credit_repayment') || hasPermission('inspect_returns') ||
       hasPermission('view_finance') ||
       (isManager && (hasPermission('approve_credit') || hasPermission('approve_refund'))));

  bool get canOverridePrice {
    return hasPermission(overridePricePermission);
  }

  bool get canApplyDiscount {
    return hasPermission(applyDiscountPermission);
  }

  bool get canManageInventory {
    return hasPermission(manageInventoryPermission);
  }

  bool get canDeleteSales {
    return hasPermission(deleteSalesPermission);
  }

  bool get canQuickAddProduct {
    return hasPermission(quickAddProductPermission);
  }

  bool get canCompleteSales =>
      hasPermission('pos_access') && hasPermission('complete_sales');

  bool get canAccessPOS {
    if (!isActive) {
      return false;
    }

    return _employee?.canAccessPOS ?? false;
  }

  List<String> get permissions {
    return List.unmodifiable(_employee?.permissions ?? const []);
  }
}
