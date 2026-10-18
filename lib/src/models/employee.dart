enum EmployeeRole {
  owner,
  admin,
  manager,
  employee,
  cashier,
  inventoryEmployee,
}

enum EmployeeStatus {
  active,
  inactive,
  suspended,
  pending,
}

class Employee {
  final String id;
  final String membershipId;
  final String userId;
  final String employeeCode;
  final String name;
  final String? email;
  final String? phone;

  final EmployeeRole role;
  final EmployeeStatus status;

  final String businessId;
  final List<String> permissions;
  final List<String> deniedPermissions;

  const Employee({
    required this.id,
    this.membershipId = '',
    required this.userId,
    required this.employeeCode,
    required this.name,
    this.email,
    this.phone,
    this.role = EmployeeRole.employee,
    this.status = EmployeeStatus.active,
    required this.businessId,
    this.permissions = const [],
    this.deniedPermissions = const [],
  });

  factory Employee.fromJson(
      Map<String, dynamic> json,
      ) {
    return Employee(
      id: json['id']?.toString() ?? '',
      membershipId: json['membership_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      employeeCode:
      json['employee_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: _nullableString(json['email']),
      phone: _nullableString(json['phone']),
      role: _parseRole(json['role']),
      status: _parseStatus(json['status']),
      businessId:
      json['business_id']?.toString() ?? '',
      permissions: _parsePermissions(
        json['permissions'],
      ),
      deniedPermissions: _parsePermissions(json['denied_permissions']),
    );
  }

  static EmployeeRole _parseRole(dynamic value) {
    final raw = value?.toString().toLowerCase();
    if (raw == 'sales_employee') return EmployeeRole.cashier;
    if (raw == 'inventory_employee') return EmployeeRole.inventoryEmployee;

    return EmployeeRole.values.firstWhere(
          (role) => role.name == raw,
      orElse: () => EmployeeRole.employee,
    );
  }

  static EmployeeStatus _parseStatus(
      dynamic value,
      ) {
    final raw = value?.toString().toLowerCase();

    return EmployeeStatus.values.firstWhere(
          (status) => status.name == raw,
      orElse: () => EmployeeStatus.inactive,
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;

    final string = value.toString().trim();

    return string.isEmpty ? null : string;
  }

  static List<String> _parsePermissions(
      dynamic value,
      ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Employee copyWith({
    String? id,
    String? userId,
    String? employeeCode,
    String? name,
    String? email,
    String? phone,
    EmployeeRole? role,
    EmployeeStatus? status,
    String? businessId,
    List<String>? permissions,
  }) {
    return Employee(
      id: id ?? this.id,
      membershipId: membershipId,
      userId: userId ?? this.userId,
      employeeCode:
      employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      businessId: businessId ?? this.businessId,
      permissions: permissions ?? this.permissions,
      deniedPermissions: deniedPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membership_id': membershipId,
      'user_id': userId,
      'employee_code': employeeCode,
      'name': name,
      'email': email,
      'phone': phone,
      'role': switch (role) {
        EmployeeRole.cashier => 'sales_employee',
        EmployeeRole.inventoryEmployee => 'inventory_employee',
        _ => role.name,
      },
      'status': status.name,
      'business_id': businessId,
      'permissions': permissions,
      if (deniedPermissions.isNotEmpty) 'denied_permissions': deniedPermissions,
    };
  }

  String get employeeId => id;

  bool get isActive =>
      status == EmployeeStatus.active;

  bool get isInactive =>
      status == EmployeeStatus.inactive;

  bool get isManager =>
      role == EmployeeRole.manager;

  bool get isAdmin =>
      role == EmployeeRole.admin;

  bool get isCashier =>
      role == EmployeeRole.cashier;

  bool get canAccessPOS {
    return isActive &&
        (role == EmployeeRole.owner ||
            role == EmployeeRole.inventoryEmployee ||
            hasPermission('pos_access'));
  }

  bool hasPermission(String permission) {
    if (!isActive) return false;
    if (permission == 'view_profit') return false;
    if (role != EmployeeRole.owner &&
        const {'view_camera_events', 'owner_app', 'manage_permissions', 'assign_roles'}.contains(permission)) {
      return false;
    }
    if (role != EmployeeRole.owner && role != EmployeeRole.manager &&
        const {'override_price', 'edit_prices', 'change_prices', 'manage_prices',
          'set_prices', 'branch_price_override', 'manage_employees', 'view_finance'}.contains(permission)) {
      return false;
    }
    // Inventory staff must never change selling prices, even with a stale grant.
    if (role == EmployeeRole.inventoryEmployee &&
        const {'override_price', 'edit_prices', 'change_prices', 'manage_prices',
          'set_prices', 'branch_price_override', 'apply_discount'}.contains(permission)) {
      return false;
    }
    if (role == EmployeeRole.owner) {
      return true;
    }
    if (deniedPermissions.contains(permission)) return false;
    final defaults = switch (role) {
      EmployeeRole.manager => const {'pos_access', 'complete_sales', 'view_inventory',
        'add_products', 'edit_products', 'manage_employees', 'adjust_stock'},
      EmployeeRole.cashier => const {'pos_access', 'complete_sales', 'view_inventory'},
      EmployeeRole.inventoryEmployee => const {'view_inventory', 'add_products', 'edit_products'},
      _ => const <String>{},
    };
    return defaults.contains(permission) || permissions.contains(permission);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Employee &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
