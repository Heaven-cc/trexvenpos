
import 'package:flutter/material.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import 'customer_presentation.dart';
import 'operations_client.dart';

class OperationalPermissionsScreen extends StatefulWidget {
  final OperationsClient api;

  const OperationalPermissionsScreen({
    super.key,
    required this.api,
  });

  @override
  State<OperationalPermissionsScreen> createState() =>
      _OperationalPermissionsScreenState();
}

class _OperationalPermissionsScreenState
    extends State<OperationalPermissionsScreen> {
  static const Color _background = Color(0xFFF5F7FC);
  static const Color _navy = Color(0xFF14213D);
  static const Color _blue = Color(0xFF2864F0);
  static const Color _muted = Color(0xFF71809A);
  static const Color _border = Color(0xFFE6EAF2);
  static const Color _softBlue = Color(0xFFEAF0FF);
  static const Color _green = Color(0xFF16845A);

  late Future<List<Map<String, dynamic>>> employees;

  static const Map<String, List<String>> _groups = {
    'Financial operations': [
      'offline_cash',
      'approve_credit',
      'record_credit_repayment',
      'approve_refund',
      'inspect_returns',
      'reverse_credit_repayment',
    ],
    'Inventory operations': [
      'stocktake',
      'approve_stocktake',
      'dispose_stock',
      'restore_stock',
      'writeoff_stock',
      'supplier_returns',
      'approve_supplier_returns',
    ],
    'Cash management': [
      'cash_shifts',
      'cash_movements',
      'review_cash_shifts',
    ],
  };

  static const Map<String, String> _permissionNames = {
    'offline_cash': 'Offline cash transactions',
    'approve_credit': 'Approve customer credit',
    'record_credit_repayment': 'Record credit repayments',
    'approve_refund': 'Approve refunds',
    'inspect_returns': 'Inspect returned products',
    'reverse_credit_repayment': 'Reverse credit repayments',
    'stocktake': 'Perform stocktaking',
    'approve_stocktake': 'Approve stock reconciliation',
    'dispose_stock': 'Dispose of damaged stock',
    'restore_stock': 'Restore inspected stock',
    'writeoff_stock': 'Write off inventory',
    'supplier_returns': 'Process supplier returns',
    'approve_supplier_returns': 'Approve supplier returns',
    'cash_shifts': 'Manage cash shifts',
    'cash_movements': 'Record cash movements',
    'review_cash_shifts': 'Review cash shifts',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    employees = widget.api.list('employees');
  }

  void _refresh() {
    setState(_load);
  }

  String _employeeName(Map<String, dynamic> employee) {
    final name = employee['full_name'] ?? employee['name'];
    final text = '$name'.trim();

    return name == null || text.isEmpty
        ? 'Employee'
        : text;
  }

  Future<void> _edit(Map<String, dynamic> employee) async {
    Map<String, bool> granted;

    try {
      final rows = await widget.api.list(
        'employee_permissions',
        foreignKey: 'employee_id',
        foreignId: employee['id'] as String,
      );

      granted = {
        for (final p in rows)
          p['permission_id'] as String: p['granted'] == true,
      };
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CustomerPresentation.error(
              error,
              fallback: 'Unable to load employee permissions.',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    var busy = false;
    String? errorMessage;
    String? successMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, update) {
            Future<void> changePermission(
                String permission,
                bool value,
                ) async {
              if (busy) return;

              update(() {
                busy = true;
                errorMessage = null;
                successMessage = null;
              });

              try {
                await widget.api.call(
                  'set_trexven_employee_permission',
                  {
                    'p_employee_id': employee['id'],
                    'p_permission': permission,
                    'p_granted': value,
                  },
                );

                if (!dialogContext.mounted) return;

                update(() {
                  granted[permission] = value;
                  successMessage = value
                      ? 'Permission enabled successfully.'
                      : 'Permission disabled successfully.';
                });
              } catch (error) {
                if (!dialogContext.mounted) return;

                update(() {
                  errorMessage = CustomerPresentation.error(
                    error,
                    fallback:
                    'Change not confirmed. Please try again.',
                  );
                });
              } finally {
                if (dialogContext.mounted) {
                  update(() => busy = false);
                }
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 680,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18, 18, 12, 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _softBlue,
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: _blue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _employeeName(employee),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _navy,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Operational permissions',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: busy
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      color: _border,
                    ),
                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _softBlue,
                              borderRadius:
                              BorderRadius.circular(11),
                            ),
                            child: const Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: _blue,
                                  size: 18,
                                ),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Permissions are saved individually. '
                                        'Changes do not modify the employee role. '
                                        'Server authorization still applies.',
                                    style: TextStyle(
                                      color: _navy,
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (busy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(
                              color: _blue,
                            ),
                          ],
                          if (errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _feedback(
                              errorMessage!,
                              const Color(0xFFD44B52),
                            ),
                          ],
                          if (successMessage != null) ...[
                            const SizedBox(height: 12),
                            _feedback(
                              successMessage!,
                              _green,
                            ),
                          ],
                          const SizedBox(height: 18),
                          for (final group in _groups.entries) ...[
                            _dialogSection(group.key),
                            const SizedBox(height: 9),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: _border,
                                ),
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0;
                                  i < group.value.length;
                                  i++) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        indent: 12,
                                        endIndent: 12,
                                        color: _border,
                                      ),
                                    SwitchListTile.adaptive(
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 2,
                                      ),
                                      dense: true,
                                      title: Text(
                                        _permissionNames[
                                        group.value[i]] ??
                                            group.value[i],
                                        style: const TextStyle(
                                          color: _navy,
                                          fontSize: 12,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                      value: granted[
                                      group.value[i]] ??
                                          false,
                                      activeTrackColor: _blue,
                                      onChanged: busy
                                          ? null
                                          : (value) =>
                                          changePermission(
                                            group.value[i],
                                            value,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      color: _border,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.pop(dialogContext),
                          style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(
                              double.infinity,
                              43,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogSection(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _navy,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _feedback(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Employee Permissions',
          style: TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh employees',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _navy,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: employees,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: TrexvenLoading());
          }

          if (snapshot.hasError) {
            return _errorState();
          }

          final rows = snapshot.data ?? [];

          return RefreshIndicator(
            color: _blue,
            onRefresh: () async {
              _refresh();
              try {
                await employees;
              } catch (_) {
                // FutureBuilder handles load failures.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16, 14, 16, 32,
              ),
              children: [
                const Text(
                  'Operational Access',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Control which sensitive business operations '
                      'employees are authorized to perform.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _securityNotice(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Employees',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _countBadge(rows.length),
                  ],
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  _emptyState()
                else
                  for (final employee in rows) ...[
                    _employeeCard(employee),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _securityNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: _blue,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sensitive operations remain restricted to owners '
                  'and explicitly authorized managers. '
                  'Permission grants never change an employee role.',
              style: TextStyle(
                color: _navy,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _blue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _employeeCard(Map<String, dynamic> employee) {
    final name = _employeeName(employee);
    final status = '${employee['status'] ?? 'unknown'}';
    final active = status.toLowerCase() == 'active';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _edit(employee),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _blue,
                  size: 22,
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
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      CustomerPresentation.label(
                        employee['role'],
                      ),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? _green.withValues(alpha: 0.09)
                          : _background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      CustomerPresentation.label(status),
                      style: TextStyle(
                        color: active ? _green : _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            color: _muted,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'No employees found',
            style: TextStyle(
              color: _navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Employees will appear here once they are added.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: _muted,
              size: 36,
            ),
            const SizedBox(height: 12),
            const Text(
              'Employee access unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We could not load employee permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _refresh,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
