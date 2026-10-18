import 'package:flutter_test/flutter_test.dart';
import 'package:trexvenpos/src/features/auth/permission_service.dart';
import 'package:trexvenpos/src/models/employee.dart';

Employee staff(
  String role, {
  String status = 'active',
  List<String> permissions = const [],
}) => Employee.fromJson({
  'id': 'employee',
  'user_id': 'user',
  'business_id': 'business',
  'role': role,
  'status': status,
  'permissions': permissions,
});

void main() {
  test('Only an active owner has unrestricted access', () {
    expect(PermissionService(staff('owner')).hasFullAccess, isTrue);
    expect(
      PermissionService(staff('owner', status: 'suspended')).hasFullAccess,
      isFalse,
    );
    expect(PermissionService(staff('admin')).hasFullAccess, isFalse);
    expect(PermissionService(staff('admin')).canOverridePrice, isFalse);
    expect(
      staff('owner', status: 'inactive').hasPermission('edit_products'),
      isFalse,
    );
  });

  test(
    'Inventory staff can use the app and create products but cannot change prices',
    () {
      final employee = staff(
        'inventory_employee',
        permissions: ['override_price', 'edit_prices'],
      );
      final access = PermissionService(employee);
      expect(employee.role.name, 'inventoryEmployee');
      expect(employee.toJson()['role'], 'inventory_employee');
      expect(access.canAccessPOS, isTrue);
      expect(access.canQuickAddProduct, isTrue);
      expect(access.canManageInventory, isTrue);
      expect(access.canOverridePrice, isFalse);
      expect(access.hasPermission('edit_prices'), isFalse);
    },
  );

  test(
    'Managers need an explicit grant for privileged price and finance actions',
    () {
      final access = PermissionService(staff('manager'));
      expect(access.canQuickAddProduct, isTrue);
      expect(access.canManageInventory, isTrue);
      expect(access.canOverridePrice, isFalse);
      expect(
        PermissionService(
          staff('manager', permissions: ['override_price']),
        ).canOverridePrice,
        isTrue,
      );
    },
  );

  test('Sales staff cannot create products without a grant', () {
    expect(PermissionService(staff('sales_employee')).canAccessPOS, isTrue);
    expect(
      PermissionService(staff('sales_employee')).canQuickAddProduct,
      isFalse,
    );
    expect(
      PermissionService(
        staff('sales_employee', permissions: ['add_products']),
      ).canQuickAddProduct,
      isTrue,
    );
    expect(staff('sales_employee').toJson()['role'], 'sales_employee');
  });

  test('Unknown roles and inactive employees fail closed', () {
    expect(PermissionService(staff('unknown')).canAccessPOS, isFalse);
    expect(
      PermissionService(
        staff('manager', status: 'terminated', permissions: ['add_products']),
      ).canQuickAddProduct,
      isFalse,
    );
    expect(PermissionService(null).canAccessPOS, isFalse);
  });
}
