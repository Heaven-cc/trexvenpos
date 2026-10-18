
import 'package:flutter/material.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import 'customer_presentation.dart';
import 'operations_client.dart';

class _AccessStyle {
  static const background = Color(0xFFF5F7FC);
  static const white = Colors.white;
  static const navy = Color(0xFF14213D);
  static const blue = Color(0xFF2864F0);
  static const muted = Color(0xFF71809A);
  static const paleBlue = Color(0xFFE8EFFF);
  static const border = Color(0xFFE7ECF4);
  static const green = Color(0xFF16845A);
  static const paleGreen = Color(0xFFE6F7EF);
  static const red = Color(0xFFD44B52);
  static const paleRed = Color(0xFFFCEDEF);
}

class EmployeeAccessScreen extends StatefulWidget {
  final OperationsClient api;

  const EmployeeAccessScreen({
    super.key,
    required this.api,
  });

  @override
  State<EmployeeAccessScreen> createState() =>
      _EmployeeAccessScreenState();
}

class _EmployeeAccessScreenState
    extends State<EmployeeAccessScreen> {
  late Future<List<Map<String, dynamic>>> rows;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    rows = widget.api.list('employees');
  }

  void refresh() {
    setState(() {
      rows = widget.api.list('employees');
    });
  }

  Future<void> permissions(
      Map<String, dynamic> employee,
      ) async {
    final client = widget.api.client;
    final user = client.auth.currentUser?.id;

    if (user == null) {
      throw StateError('Sign in is required.');
    }

    // Ownership is verified before showing the controls.
    // The RPC independently authorizes every permission write.
    final owned = await client
        .from('businesses')
        .select('id')
        .eq('id', widget.api.businessId)
        .eq('owner_id', user)
        .maybeSingle();

    if (!mounted) return;

    if (owned == null) {
      throw StateError(
        'Only the verified owner can grant permissions.',
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _PermissionOverrides(
          api: widget.api,
          employee: employee,
        ),
      ),
    );
  }

  Future<void> act(
      Future<void> Function() operation,
      ) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access could not be verified. Refresh and ask the owner to review.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AccessStyle.background,
      appBar: AppBar(
        backgroundColor: _AccessStyle.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Employees & permissions',
          style: TextStyle(
            color: _AccessStyle.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh employees',
            onPressed: busy ? null : refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _AccessStyle.navy,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (context, state) {
          if (state.hasError) {
            return _AccessError(
              message:
              'We could not load employee access.',
              onRetry: refresh,
            );
          }

          if (!state.hasData) {
            return const Center(
              child: TrexvenLoading(),
            );
          }

          final staff = state.data!;

          return RefreshIndicator(
            color: _AccessStyle.blue,
            onRefresh: () async {
              final next = widget.api.list('employees');
              setState(() => rows = next);
              try {
                await next;
              } catch (_) {
                // The FutureBuilder displays the error.
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16, 18, 16, 30,
              ),
              children: [
                const Text(
                  'Employee access',
                  style: TextStyle(
                    color: _AccessStyle.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage what your team can access',
                  style: TextStyle(
                    color: _AccessStyle.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _AccessStyle.paleBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: _AccessStyle.blue,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Only the verified business owner can change employee permissions.',
                          style: TextStyle(
                            color: _AccessStyle.navy,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Team members',
                        style: TextStyle(
                          color: _AccessStyle.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${staff.length} employees',
                      style: const TextStyle(
                        color: _AccessStyle.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (staff.isEmpty)
                  const _AccessEmpty(
                    message:
                    'No employees are visible in this business.',
                  ),
                for (final employee in staff)
                  Padding(
                    padding:
                    const EdgeInsets.only(bottom: 10),
                    child: _employeeCard(employee),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _employeeCard(
      Map<String, dynamic> employee,
      ) {
    final name =
        employee['name']?.toString() ?? 'Employee';
    final role =
    CustomerPresentation.label(employee['role']);
    final status =
    CustomerPresentation.label(employee['status']);

    final isOwner = employee['role'] == 'owner';
    final isSelf =
        employee['user_id'] ==
            widget.api.client.auth.currentUser?.id;

    final canOpen = !busy && !isOwner && !isSelf;
    final initial = name.trim().isEmpty
        ? 'E'
        : name.trim()[0].toUpperCase();

    return Material(
      color: _AccessStyle.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canOpen
            ? () => act(() => permissions(employee))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _AccessStyle.paleBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _AccessStyle.blue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AccessStyle.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      role,
                      style: const TextStyle(
                        color: _AccessStyle.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _AccessPill(
                      text: status,
                      color: status.toLowerCase() ==
                          'active'
                          ? _AccessStyle.green
                          : _AccessStyle.muted,
                      background: status.toLowerCase() ==
                          'active'
                          ? _AccessStyle.paleGreen
                          : _AccessStyle.background,
                    ),
                  ],
                ),
              ),
              if (canOpen)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _AccessStyle.muted,
                )
              else if (isOwner)
                const Icon(
                  Icons.lock_outline_rounded,
                  color: _AccessStyle.muted,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionOverrides extends StatefulWidget {
  final OperationsClient api;
  final Map<String, dynamic> employee;

  const _PermissionOverrides({
    required this.api,
    required this.employee,
  });

  @override
  State<_PermissionOverrides> createState() =>
      _PermissionOverridesState();
}

class _PermissionOverridesState
    extends State<_PermissionOverrides> {
  List<Map<String, dynamic>>? definitions;
  final Map<String, bool> overrides = {};

  String? error;
  bool busy = true;

  static const forbidden = {
    'owner_app',
    'manage_permissions',
    'assign_roles',
    'view_camera_events',
    'view_profit',
  };

  static const priceOrFinance = {
    'override_price',
    'edit_prices',
    'change_prices',
    'manage_prices',
    'set_prices',
    'branch_price_override',
    'view_finance',
  };

  static const categories = [
    'POS & Sales',
    'Inventory & Stock',
    'Finance & Cash',
    'Employees',
    'Returns & Suppliers',
    'Other permissions',
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
      });
    }

    try {
      final client = widget.api.client;

      final entries = await client
          .from('employee_permissions')
          .select('permission_id,granted')
          .eq(
        'employee_id',
        widget.employee['id'] as String,
      );

      final catalog = await client
          .from('permissions')
          .select('id,description')
          .order('id');

      if (!mounted) return;

      setState(() {
        overrides.clear();

        for (final row in entries) {
          overrides[row['permission_id'] as String] =
              row['granted'] == true;
        }

        definitions = List<Map<String, dynamic>>.from(
          catalog,
        );

        busy = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        busy = false;
        error =
        'Permission records could not be loaded. Refresh before changing access.';
      });
    }
  }

  Future<void> change(
      String id,
      bool value,
      ) async {
    if (busy || error != null) return;

    setState(() => busy = true);

    try {
      await widget.api.client.rpc(
        'set_trexven_employee_permission',
        params: {
          'p_employee_id': widget.employee['id'],
          'p_permission': id,
          'p_granted': value,
        },
      );

      await load();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        busy = false;
        error =
        'Change was not confirmed. Server access may have changed; refresh before retrying.';
      });
    }
  }

  String _categoryFor(String id) {
    final key = id.toLowerCase();

    if (key.contains('employee') ||
        key.contains('staff') ||
        key.contains('permission') ||
        key.contains('role')) {
      return 'Employees';
    }

    if (key.contains('supplier') ||
        key.contains('return') ||
        key.contains('refund')) {
      return 'Returns & Suppliers';
    }

    if (key.contains('stock') ||
        key.contains('inventory') ||
        key.contains('product') ||
        key.contains('transfer') ||
        key.contains('dispose') ||
        key.contains('restock')) {
      return 'Inventory & Stock';
    }

    if (key.contains('cash') ||
        key.contains('finance') ||
        key.contains('credit') ||
        key.contains('repayment') ||
        key.contains('register') ||
        key.contains('payment')) {
      return 'Finance & Cash';
    }

    if (key.contains('sale') ||
        key.contains('pos') ||
        key.contains('discount') ||
        key.contains('price') ||
        key.contains('checkout')) {
      return 'POS & Sales';
    }

    return 'Other permissions';
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'POS & Sales':
        return Icons.point_of_sale_outlined;
      case 'Inventory & Stock':
        return Icons.inventory_2_outlined;
      case 'Finance & Cash':
        return Icons.account_balance_wallet_outlined;
      case 'Employees':
        return Icons.people_outline_rounded;
      case 'Returns & Suppliers':
        return Icons.assignment_return_outlined;
      default:
        return Icons.admin_panel_settings_outlined;
    }
  }

  bool _canGrant(String id) {
    final role = widget.employee['role'];

    if (priceOrFinance.contains(id) &&
        role != 'manager') {
      return false;
    }

    if (id == 'apply_discount' &&
        role == 'inventory_employee') {
      return false;
    }

    return true;
  }

  String _status(String id) {
    if (!overrides.containsKey(id)) {
      return 'Role default';
    }

    return overrides[id]! ? 'Granted' : 'Denied';
  }

  Future<void> _showPermissionActions(
      Map<String, dynamic> definition,
      ) async {
    if (busy || error != null) return;

    final id = definition['id'] as String;
    final description =
        definition['description']?.toString() ??
            CustomerPresentation.label(id);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _AccessStyle.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20, 22, 20, 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: _AccessStyle.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current override: ${_status(id)}',
                  style: const TextStyle(
                    color: _AccessStyle.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                if (_canGrant(id))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: _AccessStyle.green,
                    ),
                    title: const Text('Grant access'),
                    subtitle: const Text(
                      'Explicitly allow this permission',
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, true),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.block_outlined,
                    color: _AccessStyle.red,
                  ),
                  title: const Text('Deny access'),
                  subtitle: const Text(
                    'Explicitly block this permission',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, false),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Changes are checked and applied by the server. Role defaults cannot be restored here because this screen has no verified reset RPC.',
                  style: TextStyle(
                    color: _AccessStyle.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    await change(id, result);
  }

  @override
  Widget build(BuildContext context) {
    final employeeName =
        widget.employee['name']?.toString() ??
            'Employee';

    final role =
    CustomerPresentation.label(
      widget.employee['role'],
    );

    final visible = (definitions ??
        <Map<String, dynamic>>[])
        .where(
          (item) => !forbidden.contains(item['id']),
    )
        .toList();

    return Scaffold(
      backgroundColor: _AccessStyle.background,
      appBar: AppBar(
        backgroundColor: _AccessStyle.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Employee permissions',
          style: TextStyle(
            color: _AccessStyle.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh permissions',
            onPressed: busy ? null : load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _AccessStyle.navy,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
              16, 16, 16, 30,
            ),
            children: [
              _employeeSummary(employeeName, role),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _AccessStyle.paleBlue,
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: _AccessStyle.blue,
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Role default means no explicit override. Grant or Deny changes are applied immediately by the server.',
                        style: TextStyle(
                          color: _AccessStyle.navy,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _AccessStyle.paleRed,
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        error!,
                        style: const TextStyle(
                          color: _AccessStyle.red,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: busy ? null : load,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Permission categories',
                      style: TextStyle(
                        color: _AccessStyle.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${visible.length} permissions',
                    style: const TextStyle(
                      color: _AccessStyle.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (definitions == null &&
                  error == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: TrexvenLoading(),
                  ),
                ),
              for (final category in categories)
                if (visible.any(
                      (item) =>
                  _categoryFor(
                    item['id'].toString(),
                  ) ==
                      category,
                ))
                  Padding(
                    padding:
                    const EdgeInsets.only(bottom: 10),
                    child: _categoryCard(
                      category,
                      visible
                          .where(
                            (item) =>
                        _categoryFor(
                          item['id'].toString(),
                        ) ==
                            category,
                      )
                          .toList(),
                    ),
                  ),
            ],
          ),
          if (busy && definitions != null)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                color: _AccessStyle.blue,
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _employeeSummary(
      String name,
      String role,
      ) {
    final initial = name.trim().isEmpty
        ? 'E'
        : name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AccessStyle.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _AccessStyle.paleBlue,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: _AccessStyle.blue,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _AccessStyle.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  role,
                  style: const TextStyle(
                    color: _AccessStyle.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_outlined,
            color: _AccessStyle.blue,
            size: 23,
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(
      String category,
      List<Map<String, dynamic>> items,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: _AccessStyle.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: _AccessStyle.blue,
        collapsedIconColor: _AccessStyle.muted,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 3,
        ),
        childrenPadding:
        const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: _AccessStyle.paleBlue,
            borderRadius:
            BorderRadius.circular(11),
          ),
          child: Icon(
            _iconFor(category),
            color: _AccessStyle.blue,
            size: 20,
          ),
        ),
        title: Text(
          category,
          style: const TextStyle(
            color: _AccessStyle.navy,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${items.length} permissions',
          style: const TextStyle(
            color: _AccessStyle.muted,
            fontSize: 11,
          ),
        ),
        children: [
          const Divider(
            color: _AccessStyle.border,
            height: 1,
          ),
          for (final item in items)
            _permissionRow(item),
        ],
      ),
    );
  }

  Widget _permissionRow(
      Map<String, dynamic> definition,
      ) {
    final id = definition['id'] as String;
    final title =
        definition['description']?.toString() ??
            CustomerPresentation.label(id);

    final status = _status(id);

    final color = status == 'Granted'
        ? _AccessStyle.green
        : status == 'Denied'
        ? _AccessStyle.red
        : _AccessStyle.muted;

    final background = status == 'Granted'
        ? _AccessStyle.paleGreen
        : status == 'Denied'
        ? _AccessStyle.paleRed
        : _AccessStyle.background;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _AccessStyle.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      CustomerPresentation.label(id),
                      style: const TextStyle(
                        color: _AccessStyle.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _AccessPill(
                      text: status,
                      color: color,
                      background: background,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Change permission',
                onPressed: busy || error != null
                    ? null
                    : () => _showPermissionActions(
                  definition,
                ),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: _AccessStyle.muted,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
        const Divider(
          color: _AccessStyle.border,
          height: 1,
        ),
      ],
    );
  }
}

class _AccessPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _AccessPill({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AccessEmpty extends StatelessWidget {
  final String message;

  const _AccessEmpty({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _AccessStyle.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 40,
            color: _AccessStyle.muted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AccessStyle.muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AccessError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _AccessStyle.red,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AccessStyle.navy,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
