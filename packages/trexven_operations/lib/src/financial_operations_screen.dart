import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import 'cash_shift_screen.dart';
import 'customer_presentation.dart';
import 'operations_client.dart';
import 'text_controller_scope.dart';

part 'financial_operations_support.dart';
part 'financial_operations_details.dart';

/// The same records and RPCs serve Owner and POS. Permissions only shape the UI;
/// every write remains authorized and committed by the existing backend.
class FinancialOperationsScreen extends StatefulWidget {
  final OperationsClient api;
  final bool owner;
  final bool manager;
  final Set<String> permissions;
  final String? branchId;
  final String? currency;
  final bool Function()? contextIsCurrent;
  final VoidCallback? onRecordsChanged;
  const FinancialOperationsScreen({
    super.key,
    required this.api,
    required this.owner,
    this.manager = false,
    this.permissions = const {},
    this.branchId,
    this.currency,
    this.contextIsCurrent,
    this.onRecordsChanged,
  });
  @override
  State<FinancialOperationsScreen> createState() =>
      _FinancialOperationsScreenState();
}

class _FinancialOperationsScreenState extends State<FinancialOperationsScreen>
    with WidgetsBindingObserver {
  final _revision = ValueNotifier<int>(0);
  final _search = TextEditingController();
  _SectionData _accounts = const _SectionData();
  _SectionData _entries = const _SectionData();
  _SectionData _returns = const _SectionData();
  _SectionData _approvals = const _SectionData();
  _SectionData _offline = const _SectionData();
  _SectionData _limits = const _SectionData();
  Map<String, dynamic>? _day, _totals;
  Object? _dayError, _totalsError;
  String? _message, _currency;
  bool _loading = true,
      _busy = false,
      _preparing = false,
      _invalid = false,
      _refreshing = false;
  int _tab = 0, _filter = 0, _generation = 0, _childRoutes = 0;
  late final String? _actor;
  StreamSubscription<AuthState>? _authChanges;
  Timer? _refreshTimer;
  NavigatorState? _navigator;
  ModalRoute<dynamic>? _rootRoute;
  String? _freshAt;

  bool get _current =>
      mounted &&
      !_invalid &&
      widget.api.client.auth.currentUser?.id == _actor &&
      (widget.contextIsCurrent?.call() ?? true);
  bool _can(String permission, {bool sensitive = false}) =>
      _current &&
      (widget.owner ||
          (widget.permissions.contains(permission) &&
              (!sensitive || widget.manager)));
  bool get _canReadCredit =>
      widget.owner || _can('record_credit_repayment') || _can('view_finance');
  bool get _canReadReturns =>
      widget.owner ||
      _can('complete_sales') ||
      _can('inspect_returns') ||
      _can('approve_refund', sensitive: true) ||
      _can('view_finance');

  @override
  void initState() {
    super.initState();
    _actor = widget.api.client.auth.currentUser?.id;
    _currency = widget.currency;
    WidgetsBinding.instance.addObserver(this);
    _authChanges = widget.api.client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user.id != _actor) {
        _invalid = true;
        ++_generation;
        _accounts = _entries = _returns = _approvals = _offline = _limits =
            const _SectionData();
        _totals = _day = null;
        _closeChildRoutes();
        _notify();
      }
    });
    unawaited(_reload());
    // These tables are not published to Realtime. Refresh visible routes using
    // authorized reads rather than changing production publication settings.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          !_busy &&
          !_preparing &&
          !_refreshing &&
          !_loading &&
          _current &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ((ModalRoute.of(context)?.isCurrent ?? false) || _childRoutes > 0)) {
        unawaited(_reload(background: true));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_busy &&
        !_preparing &&
        _current) {
      unawaited(_reload(background: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.maybeOf(context);
    _rootRoute = ModalRoute.of(context);
  }

  void _closeChildRoutes() {
    final navigator = _navigator;
    final root = _rootRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator?.mounted == true && root?.isActive == true) {
        navigator!.popUntil((route) => identical(route, root));
      }
    });
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _closeChildRoutes();
    unawaited(_authChanges?.cancel());
    _search.dispose();
    _revision.dispose();
    super.dispose();
  }

  void _notify() {
    if (!mounted) return;
    setState(() {});
    _revision.value++;
  }

  Future<_SectionData> _read(
    String table, {
    bool enabled = true,
    String? actorColumn,
    bool branch = false,
    String? saleId,
  }) async {
    if (!enabled) return const _SectionData();
    try {
      final rows = <_Row>[];
      for (var offset = 0; ; offset += 200) {
        var query = widget.api.client
            .from(table)
            .select()
            .eq('business_id', widget.api.businessId);
        if (branch && widget.branchId != null) {
          query = query.eq('branch_id', widget.branchId!);
        }
        if (actorColumn != null) query = query.eq(actorColumn, _actor!);
        if (saleId != null) query = query.eq('sale_id', saleId);
        final page = await query
            .order(table == 'credit_accounts' ? 'sale_id' : 'id')
            .range(offset, offset + 199)
            .timeout(const Duration(seconds: 20));
        rows.addAll(page.map((r) => _Row.from(r)));
        if (page.length < 200) return _SectionData(rows);
      }
    } catch (error) {
      // Reject incomplete pagination. A denied or failed read is never zero debt.
      return _SectionData(const [], error);
    }
  }

  Future<void> _reload({bool background = false, bool force = false}) async {
    if (!mounted || !_current || _actor == null || (_refreshing && !force)) {
      return;
    }
    _refreshing = true;
    final version = ++_generation;
    if (!background) {
      _loading = true;
      _notify();
    }
    final canDecide = _can('approve_credit', sensitive: true);
    final broadReturns =
        _can('inspect_returns') ||
        _can('approve_refund', sensitive: true) ||
        widget.owner ||
        _can('view_finance');
    final rows = await Future.wait([
      _read('credit_accounts', enabled: _canReadCredit, branch: true),
      _read('credit_entries', enabled: _canReadCredit),
      _read(
        'sale_returns',
        enabled: _canReadReturns,
        branch: true,
        actorColumn: broadReturns ? null : 'requested_by',
      ),
      _read(
        'credit_approvals',
        enabled: canDecide || _can('complete_sales'),
        branch: true,
        actorColumn: canDecide ? null : 'requested_by',
      ),
      _read(
        'offline_sale_reconciliations',
        enabled:
            widget.owner ||
            _can('review_cash_shifts', sensitive: true) ||
            _can('offline_cash'),
        actorColumn: widget.owner || _can('review_cash_shifts', sensitive: true)
            ? null
            : 'actor_id',
      ),
      _read('credit_limits', enabled: widget.owner),
    ]);
    Map<String, dynamic>? day, totals;
    Object? dayError, totalsError;
    try {
      day = _Row.from(
        await widget.api.call('get_trexven_business_day', {
              'p_business_id': widget.api.businessId,
            }).timeout(const Duration(seconds: 20))
            as Map,
      );
    } catch (error) {
      dayError = error;
    }
    if (widget.owner && day != null) {
      try {
        totals = _Row.from(
          await widget.api.call('get_trexven_financial_summary', {
                'p_business_id': widget.api.businessId,
                'p_start': day['starts_at'],
                'p_end': day['ends_at'],
              }).timeout(const Duration(seconds: 20))
              as Map,
        );
      } catch (error) {
        totalsError = error;
      }
    }
    if (_currency == null) {
      try {
        final business = await widget.api.client
            .from('businesses')
            .select('currency')
            .eq('id', widget.api.businessId)
            .single()
            .timeout(const Duration(seconds: 15));
        _currency = business['currency']?.toString();
      } catch (_) {
        /* Existing currency formatting remains the fallback. */
      }
    }
    if (!mounted || version != _generation || !_current) return;
    _accounts = rows[0];
    _entries = rows[1];
    _returns = rows[2];
    _approvals = rows[3];
    _offline = rows[4];
    _limits = rows[5];
    _day = day;
    _totals = totals;
    _dayError = dayError;
    _totalsError = totalsError;
    _loading = false;
    _refreshing = false;
    _freshAt = TimeOfDay.now().format(context);
    _notify();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_current) return;
    _busy = true;
    _message = null;
    _notify();
    var confirmed = false;
    try {
      await action();
      confirmed = true;
      if (!mounted || !_current) return;
      _message ??= 'The action has been confirmed.';
      widget.onRecordsChanged?.call();
      await _reload(background: true, force: true);
    } catch (error) {
      if (mounted && _current) {
        if (confirmed) {
          // A display failure must never invite a second financial operation.
          _message = 'The action was confirmed, but the display could not refresh. Refresh to load the latest records; do not repeat the payment or refund.';
        } else {
          _message = error is FormatException
              ? error.message
              : CustomerPresentation.error(
                  error,
                  fallback:
                      'Operation not confirmed. Recover the original request before starting another.',
                );
        }
      }
    } finally {
      if (mounted) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<void> _prepare(Future<void> Function() action) async {
    if (_busy || _preparing || !_current) return;
    _preparing = true;
    _notify();
    try {
      await action();
    } catch (error) {
      if (mounted && _current) {
        _message = error is FormatException
            ? error.message
            : CustomerPresentation.error(error);
        _notify();
      }
    } finally {
      _preparing = false;
      _notify();
    }
  }

  Future<void> _repay(_Row account) => _prepare(() async {
    if (!_can('record_credit_repayment') || _accounts.error != null) return;
    final input = await _creditForm(
      context,
      'Record repayment',
      [
        _CreditField(
          'amount',
          'Amount received',
          numeric: true,
          helper: 'Outstanding ${_money(account['outstanding'], _currency)}',
          validate: (v) =>
              _moneyError(v, maximum: _cents(account['outstanding'])),
        ),
        const _CreditField(
          'method',
          'Payment method',
          initial: 'cash',
          choices: ['cash', 'bank_transfer', 'card'],
        ),
        const _CreditField(
          'evidence',
          'Verified bank or terminal reference',
          required: false,
        ),
      ],
      confirmation:
          'I verified the actual cash, bank-account or terminal payment. A screenshot alone is insufficient.',
      submit: 'Record repayment',
    );
    if (input == null || !mounted || !_can('record_credit_repayment')) return;
    final shift = input['method'] == 'cash'
        ? await chooseCashShift(context, widget.api)
        : null;
    if (!mounted || !_current) return;
    await _run(() async {
      await widget.api.call('repay_trexven_credit', {
        'p_sale_id': account['sale_id'],
        'p_request_id': widget.api.requestId(),
        'p_amount': OperationsClient.amount(
          OperationsClient.moneyCents(input['amount']!),
        ),
        'p_method': input['method'],
        'p_confirmed': true,
        'p_evidence': input['evidence'],
        'p_shift_id': shift,
      });
    });
  });

  Future<void> _decide(_Row approval, bool approve) => _prepare(() async {
    if (!_can('approve_credit', sensitive: true)) return;
    final input = await _creditForm(
      context,
      approve ? 'Approve this exact credit sale' : 'Reject credit sale',
      [
        if (widget.owner && approve)
          const _CreditField(
            'exception',
            'Over-limit exception reason',
            required: false,
            helper: 'Leave blank for ordinary approval.',
          ),
      ],
      description:
          'Approval applies only to this saved transaction. The original cashier must retry it; this decision does not collect another payment.',
    );
    if (input == null || !mounted || !_can('approve_credit', sensitive: true)) {
      return;
    }
    await _run(() async {
      await widget.api.call('decide_trexven_credit_approval', {
        'p_approval_id': approval['id'],
        'p_approve': approve,
        'p_over_limit_reason': input['exception']?.isNotEmpty == true
            ? input['exception']
            : null,
      });
    });
  });

  Future<void> _inspect(_Row request) => _prepare(() async {
    if (!_can('inspect_returns')) return;
    final items =
        (await widget.api.call('get_trexven_return_inspection_items', {
                  'p_return_id': request['id'],
                })
                as List)
            .map((r) => _Row.from(r as Map))
            .toList();
    if (!mounted || !_current) return;
    final input = await _creditForm(
      context,
      'Inspect returned products',
      [
        for (final item in items)
          _CreditField(
            item['sale_item_id'] as String,
            '${item['name']} · ${item['quantity']} units',
            choices: const ['sellable', 'damaged', 'defective'],
          ),
      ],
      description:
          'Inspect every item. Only sellable items return to available inventory; damaged and defective items stay separate.',
    );
    if (input == null || !mounted || !_can('inspect_returns')) return;
    await _run(() async {
      await widget.api.call('inspect_trexven_return', {
        'p_return_id': request['id'],
        'p_request_id': widget.api.requestId(),
        'p_conditions': [
          for (final item in items)
            {
              'sale_item_id': item['sale_item_id'],
              'condition': input[item['sale_item_id']],
            },
        ],
      });
    });
  });

  Future<_Row?> _selectSale() async {
    // Receipt picker is business/branch scoped and remains subject to sales RLS.
    final result = await _read('sales', branch: true);
    if (result.error != null) throw result.error!;
    if (!mounted || !_current) return null;
    final sales = result.rows.where((s) => s['status'] == 'completed').toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    var search = '';
    return showDialog<_Row>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Find original receipt'),
          content: SizedBox(
            width: 480,
            height: 420,
            child: Column(
              children: [
                TrexvenTextField(
                  decoration: const TrexvenInputDecoration(
                    labelText: 'Search receipt or customer',
                  ),
                  onChanged: (v) =>
                      update(() => search = v.trim().toLowerCase()),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      if (sales.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No completed receipts are available to your account.',
                          ),
                        ),
                      for (final sale in sales.where(
                        (s) =>
                            '${s['sale_number']} ${s['id']} ${s['customer_name']}'
                                .toLowerCase()
                                .contains(search),
                      ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          isThreeLine: true,
                          title: Text(
                            sale['sale_number']?.toString() ??
                                'Sale ${sale['id']}',
                          ),
                          subtitle: Text(
                            '${CustomerPresentation.date(sale['created_at'], includeTime: true)}\n${_money(sale['total'], _currency)} · ${sale['customer_name'] ?? CustomerPresentation.label(sale['payment_kind'] ?? sale['payment_method'])}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, sale),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_Row>> _saleItems(String saleId) =>
      widget.api.list('sale_items', foreignKey: 'sale_id', foreignId: saleId);

  Future<List<_Row>> _saleReturns(String saleId) async {
    final result = await _read('sale_returns', branch: true, saleId: saleId);
    if (result.error != null) throw result.error!;
    return result.rows;
  }

  Future<Map<String, int>> _approvedQuantities(String saleId) async {
    final approved = (await _saleReturns(
      saleId,
    )).where((r) => r['status'] == 'approved');
    final quantities = <String, int>{};
    for (final request in approved) {
      for (final item in await widget.api.list(
        'return_items',
        foreignKey: 'return_id',
        foreignId: request['id'] as String,
      )) {
        final key = item['sale_item_id'] as String;
        quantities[key] = (quantities[key] ?? 0) + _units(item['quantity']);
      }
    }
    return quantities;
  }

  Future<void> _requestReturn() => _prepare(() async {
    if (!_can('complete_sales')) return;
    final sale = await _selectSale();
    if (sale == null || !mounted || !_current) return;
    final items = await _saleItems(sale['id'] as String);
    final returned = await _approvedQuantities(sale['id'] as String);
    if (!mounted || !_current) return;
    final available = items
        .where((i) => _units(i['quantity']) > (returned[i['id']] ?? 0))
        .toList();
    if (available.isEmpty) {
      _message = 'All quantities on this receipt have already been returned.';
      _notify();
      return;
    }
    final input = await _creditForm(
      context,
      'New return',
      [
        for (final item in available)
          _CreditField(
            item['id'] as String,
            '${item['product_name'] ?? 'Original product'} · return quantity',
            numeric: true,
            required: false,
            helper:
                '${_quantity(_units(item['quantity']) - (returned[item['id']] ?? 0))} units remaining. Leave blank to keep this item.',
            validate: (value) {
              if (value.isEmpty) return null;
              try {
                final quantity = _units(value);
                if (quantity >
                    _units(item['quantity']) - (returned[item['id']] ?? 0)) {
                  return 'Quantity exceeds the unreturned units.';
                }
              } on FormatException catch (e) {
                return e.message;
              }
              return null;
            },
          ),
        const _CreditField('reason', 'Return reason'),
      ],
      description:
          'Choose one or more original items. Inspection and approval are separate; refunds and inventory change only after approval.',
      submit: 'Request return',
    );
    if (input == null || !mounted || !_can('complete_sales')) return;
    final selected = [
      for (final item in available)
        if ((input[item['id']] ?? '').isNotEmpty &&
            _units(input[item['id']]) > 0)
          {'sale_item_id': item['id'], 'quantity': input[item['id']]},
    ];
    if (selected.isEmpty) {
      throw const FormatException(
        'Enter a positive quantity for at least one returned item.',
      );
    }
    await _run(() async {
      await widget.api.call('request_trexven_return', {
        'p_sale_id': sale['id'],
        'p_request_id': widget.api.requestId(),
        'p_items': selected,
        'p_reason': input['reason'],
      });
    });
  });

  Future<void> _approveReturn(_Row request) => _prepare(() async {
    if (!_can('approve_refund', sensitive: true)) return;
    if (!mounted || !_current) return;
    // Server computes the final prorated value, debt reduction and method-level
    // refundable collections atomically. The UI does not manufacture a refund.
    final input = await _creditForm(
      context,
      'Approve inspected return',
      const [
        _CreditField(
          'method',
          'Refund method (if money is due)',
          initial: 'cash',
          choices: ['cash', 'bank_transfer', 'card'],
        ),
        _CreditField(
          'evidence',
          'Verified bank or terminal refund reference',
          required: false,
        ),
      ],
      description:
          'Outstanding credit is reduced first. Only the remaining paid value is refunded. The server checks the original receipt, prior returns and collected funds.',
      confirmation:
          'I verified the debt adjustment and any actual refund. No cash refund is recorded for the portion reducing debt.',
      submit: 'Approve return',
    );
    if (input == null || !mounted || !_can('approve_refund', sensitive: true)) {
      return;
    }
    // A configured drawer may still be required; the backend alone determines
    // whether a cash refund is needed. Do not bypass its drawer checks.
    final shift = input['method'] == 'cash'
        ? await chooseCashShift(context, widget.api, allowNoDrawer: true)
        : null;
    if (!mounted || !_current) return;
    await _run(() async {
      final result =
          await widget.api.call('approve_trexven_return', {
                'p_return_id': request['id'],
                'p_request_id': widget.api.requestId(),
                'p_method': input['method'],
                'p_confirmed': true,
                'p_evidence': input['evidence'],
                'p_shift_id': shift,
              })
              as Map;
      _message =
          'Return confirmed. Debt reduced ${_money(result['debt_reduction'], _currency)}; actual refund ${_money(result['refund'], _currency)}.';
    });
  });

  Future<void> _reverse(_Row entry) => _prepare(() async {
    if (!widget.owner) return;
    final input = await _creditForm(
      context,
      'Reverse repayment',
      const [
        _CreditField('reason', 'Reason'),
        _CreditField(
          'evidence',
          'Verified external reversal reference',
          required: false,
        ),
      ],
      confirmation:
          'I verified the actual reversal. This reopens the corresponding customer debt.',
    );
    if (input == null || !mounted || !_current) return;
    if (entry['method'] != 'cash' && input['evidence']!.isEmpty) {
      throw const FormatException('A verified reversal reference is required.');
    }
    final shift = entry['method'] == 'cash'
        ? await chooseCashShift(context, widget.api)
        : null;
    if (!mounted || !_current) return;
    await _run(() async {
      await widget.api.call('reverse_trexven_credit_repayment', {
        'p_entry_id': entry['id'],
        'p_request_id': widget.api.requestId(),
        'p_reason': input['reason'],
        'p_confirmed': true,
        'p_evidence': input['evidence'],
        'p_shift_id': shift,
      });
    });
  });

  Future<void> _setLimit({_Row? limit}) => _prepare(() async {
    if (!widget.owner) return;
    final input = await _creditForm(
      context,
      'Set credit exposure limit',
      [
        _CreditField(
          'amount',
          'Maximum outstanding credit',
          numeric: true,
          initial: limit?['amount']?.toString() ?? '',
          validate: (v) => _moneyError(v, zero: true),
        ),
      ],
      description: limit?['branch_id'] == null
          ? 'This is the total business exposure limit, not a per-customer allowance. All credit sales still require approval. Only an owner may authorize a documented exception.'
          : 'This limit applies to the existing branch. The business-wide exposure limit also remains in effect.',
      submit: 'Save credit limit',
    );
    if (input == null || !mounted || !_current) return;
    await _run(() async {
      await widget.api.call('set_trexven_credit_limit', {
        'p_business_id': widget.api.businessId,
        'p_branch_id': limit?['branch_id'],
        'p_amount': OperationsClient.amount(
          OperationsClient.moneyCents(input['amount']!, allowZero: true),
        ),
      });
    });
  });

  Future<void> _discard() => _prepare(() async {
    final input = await _creditForm(
      context,
      'Discard unsaved operation',
      const [],
      description:
          'The server first checks that the request has not committed. Retained requests with money collected or returned must be recovered.',
      confirmation:
          'No money was collected or returned for this unsaved operation.',
    );
    if (input == null || !mounted || !_current) return;
    await _run(() => widget.api.discardUncommitted(noMoneyMoved: true));
  });

  Future<void> _review(_Row row) => _prepare(() async {
    if (!_can('review_cash_shifts', sensitive: true)) return;
    final input = await _creditForm(context, 'Review cash discrepancy', const [
      _CreditField('reason', 'Review reason'),
    ]);
    if (input == null || !mounted || !_current) return;
    await _run(() async {
      await widget.api.call('review_trexven_offline_reconciliation', {
        'p_reconciliation_id': row['id'],
        'p_request_id': widget.api.requestId(),
        'p_reason': input['reason'],
      });
    });
  });

  Widget _button(
    String label,
    VoidCallback action, {
    bool primary = false,
    IconData? icon,
  }) => primary
      ? FilledButton.icon(
          onPressed: _busy || _preparing || !_current ? null : action,
          icon: Icon(icon ?? Icons.add, size: 18),
          label: Text(label),
        )
      : OutlinedButton(
          onPressed: _busy || _preparing || !_current ? null : action,
          child: Text(label),
        );

  Widget _heading(String title, {String? count, Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(title, style: TrexvenPresentation.typography(context, TrexvenTypography.section))),
        if (count != null) Flexible(child: _CreditBadge(count)),
        ?action,
      ],
    ),
  );

  Widget _empty(
    String title,
    String description, {
    Widget? action,
    IconData icon = Icons.receipt_long_outlined,
  }) => _CreditCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: TrexvenPresentation.spacing(context, 18)),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TrexvenPresentation.typography(context, TrexvenTypography.section),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          if (action != null) ...[
            SizedBox(height: TrexvenPresentation.spacing(context, 18)),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    ),
  );

  Widget _error(String title) => _empty(
    title,
    'This information could not be loaded. No estimated balances are shown.',
    icon: Icons.cloud_off_outlined,
    action: _button('Retry', () => unawaited(_reload())),
  );

  Widget _notice() => Column(
    children: [
      if (_busy) const LinearProgressIndicator(),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CreditCard(child: Text(_message!)),
        ),
    ],
  );

  Widget _tabs(List<String> labels, int selected, ValueChanged<int> select) =>
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(TrexvenRadii.pill),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: TextButton(
                  onPressed: () => select(i),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: selected == i
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Colors.transparent,
                    foregroundColor: selected == i
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: Text(labels[i], textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      );

  Widget _customerTile(
    _CustomerCredit customer, {
    bool limitView = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: TrexvenPresentation.spacing(context, 10)),
    child: _CreditCard(
      child: InkWell(
        onTap: () => unawaited(_openCustomer(customer.key)),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TrexvenPresentation.typography(context, TrexvenTypography.input).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.contact,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _cash(customer.outstanding, _currency),
                  style: TrexvenPresentation.typography(context, TrexvenTypography.section),
                ),
                _CreditBadge(
                  customer.outstanding > 0 ? 'Active credit' : 'Settled',
                  active: customer.outstanding > 0,
                ),
                Text(
                  '${customer.accounts.length} ${customer.accounts.length == 1 ? 'credit sale' : 'credit sales'}',
                ),
              ],
            ),
            if (limitView) ...[
              const SizedBox(height: 8),
              const Text(
                'Included in business exposure; no individual allowance is configured.',
              ),
            ],
          ],
        ),
      ),
    ),
  );

  List<Widget> _creditContent() {
    if (!_canReadCredit) {
      return [
        _empty(
          'Customer balances are restricted',
          'Your account can request credit sales through checkout. An owner or authorized manager reviews approvals below.',
        ),
      ];
    }
    if (_accounts.error != null) return [_error('Customer credit unavailable')];
    final customers = _customers(_accounts.rows);
    final search = _search.text.trim().toLowerCase();
    final visible = customers
        .where(
          (c) =>
              '${c.name} ${c.contact}'.toLowerCase().contains(search) &&
              (_filter == 0 ||
                  (_filter == 1 ? c.outstanding > 0 : c.outstanding == 0)),
        )
        .toList();
    return [
      _heading('Customer credit', count: '${customers.length} customers'),
      TrexvenTextField(
        controller: _search,
        decoration: const TrexvenInputDecoration(
          labelText: 'Search customers',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => _notify(),
      ),
      _tabs(const ['All', 'Owing', 'Settled'], _filter, (i) {
        _filter = i;
        _notify();
      }),
      SizedBox(height: TrexvenPresentation.spacing(context, 14)),
      if (visible.isEmpty)
        _empty(
          customers.isEmpty
              ? 'No customer credit yet'
              : 'No matching customers',
          customers.isEmpty
              ? 'Approved credit sales will appear here after the original checkout completes.'
              : 'Try another name, contact or filter.',
        ),
      for (final customer in visible) _customerTile(customer),
    ];
  }

  List<Widget> _returnContent() => [
    _heading(
      'Returns & refunds',
      count: _returns.error == null ? '${_returns.rows.length} requests' : null,
    ),
    if (_returns.error != null)
      _error('Returns unavailable')
    else if (_returns.rows.isEmpty)
      _empty(
        'No returns yet',
        'Customer return requests will appear here.',
        icon: Icons.inventory_2_outlined,
        action: _can('complete_sales')
            ? _button(
                'New return',
                () => unawaited(_requestReturn()),
                primary: true,
              )
            : null,
      )
    else ...[
      if (_can('complete_sales'))
        Align(
          alignment: Alignment.centerLeft,
          child: _button(
            'New return',
            () => unawaited(_requestReturn()),
            primary: true,
          ),
        ),
      const SizedBox(height: 12),
      for (final request in _returns.rows.reversed)
        Padding(
          padding: EdgeInsets.only(bottom: TrexvenPresentation.spacing(context, 10)),
          child: _CreditCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request['reason']?.toString() ?? 'Customer return',
                        style: TrexvenPresentation.typography(context, TrexvenTypography.input).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _CreditBadge(CustomerPresentation.label(request['status'])),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CustomerPresentation.date(
                    request['created_at'],
                    includeTime: true,
                  ),
                ),
                const SizedBox(height: 8),
                if (request['status'] == 'approved') ...[
                  Text('Return value ${_money(request['value'], _currency)}'),
                  Text(
                    'Debt reduced ${_money(request['debt_reduction'], _currency)}',
                  ),
                  Text(
                    'Actual refund ${_money(request['refund_amount'], _currency)}${request['refund_method'] == null ? '' : ' · ${CustomerPresentation.label(request['refund_method'])}'}',
                  ),
                ],
                SizedBox(height: TrexvenPresentation.spacing(context, 10)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _button(
                      'View receipt',
                      () => unawaited(
                        _prepare(() => _receipt(request['sale_id'] as String)),
                      ),
                    ),
                    if (request['status'] == 'requested' &&
                        _can('inspect_returns'))
                      _button(
                        'Inspect return',
                        () => unawaited(_inspect(request)),
                        primary: true,
                        icon: Icons.fact_check_outlined,
                      ),
                    if (request['status'] == 'inspected' &&
                        _can('approve_refund', sensitive: true))
                      _button(
                        'Approve return',
                        () => unawaited(_approveReturn(request)),
                        primary: true,
                        icon: Icons.check,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  ];

  Widget _secondary() => Column(
    children: [
      if (_can('complete_sales') ||
          _can('approve_credit', sensitive: true)) ...[
        _heading(
          'Credit approvals',
          count: _approvals.error == null
              ? '${_approvals.rows.where((a) => a['status'] == 'pending').length} pending'
              : null,
        ),
        _CreditCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Review credit requests'),
            subtitle: const Text('Decisions apply to the original saved sale.'),
            children: [
              if (_approvals.error != null)
                _error('Approvals unavailable')
              else if (_approvals.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No credit requests.'),
                ),
              for (final approval in _approvals.rows.reversed)
                _approvalTile(approval),
            ],
          ),
        ),
      ],
      if (widget.owner ||
          _can('review_cash_shifts', sensitive: true) ||
          _can('offline_cash')) ...[
        _heading('Offline reconciliation'),
        _CreditCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Cash discrepancies'),
            subtitle: const Text('Review retained offline sale differences.'),
            children: [
              if (_offline.error != null)
                _error('Reconciliation unavailable')
              else if (_offline.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No offline cash discrepancies.'),
                ),
              for (final row in _offline.rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row['reviewed_by'] == null ? 'Requires review' : 'Reviewed',
                  ),
                  subtitle: Text(
                    '${CustomerPresentation.date(row['occurred_at'], includeTime: true)}\n${CustomerPresentation.stockDiscrepancies(row['discrepancies'])}\n${row['review_reason'] ?? ''}',
                  ),
                  onTap:
                      row['reviewed_by'] == null &&
                          _can('review_cash_shifts', sensitive: true) &&
                          !_busy
                      ? () => unawaited(_review(row))
                      : null,
                ),
            ],
          ),
        ),
      ],
      _heading('Recovery & history'),
      _CreditCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recover the original operation after an interrupted connection. Do not collect payment twice.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button(
                  'Recover operation',
                  () => unawaited(
                    _run(() async {
                      final receipt = await widget.api.recoverPending();
                      _message = receipt == null
                          ? 'No pending operation was found.'
                          : 'The original operation was recovered. No second payment is required.';
                    }),
                  ),
                ),
                _button('Discard unsaved', () => unawaited(_discard())),
              ],
            ),
          ],
        ),
      ),
      if (widget.owner) ...[
        _heading('Owner financial overview'),
        if (_totals == null)
          _error('Financial totals unavailable')
        else
          _CreditCard(
            child: Column(
              children: [
                _info(
                  'Gross sales',
                  _money(_totals!['gross_sales'], _currency),
                ),
                _info(
                  'Sale collections',
                  _money(_totals!['sale_collections'], _currency),
                ),
                _info(
                  'Repayment collections',
                  _money(_totals!['repayment_collections'], _currency),
                ),
                _info('Actual refunds', _money(_totals!['refunds'], _currency)),
                _info(
                  'Net collected',
                  _money(_totals!['net_collected'], _currency),
                ),
                _info('Overdue credit', _money(_totals!['overdue'], _currency)),
              ],
            ),
          ),
      ],
    ],
  );

  Widget _approvalTile(_Row approval) {
    final payload = approval['payload'] is Map
        ? approval['payload'] as Map
        : const {};
    final credit = payload['credit'] is Map
        ? payload['credit'] as Map
        : const {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${credit['debtor_name'] ?? 'Credit customer'} · ${credit['contact'] ?? ''}',
            style: TrexvenPresentation.typography(context, TrexvenTypography.label),
          ),
          Text(
            '${CustomerPresentation.label(approval['status'])} · Sale total ${_money(payload['total'], _currency)}',
          ),
          Text('Due ${CustomerPresentation.date(credit['due_date'])}'),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Saved transaction details'),
            children: [
              if (payload['items'] is List)
                for (final item in (payload['items'] as List).whereType<Map>())
                  _info(
                    '${item['product_name'] ?? item['product_id'] ?? 'Original item'} × ${item['quantity']}',
                    '${_money(item['unit_price'], _currency)} per unit · discount ${_money(item['discount'] ?? 0, _currency)}',
                  ),
              if (payload['payments'] is List)
                for (final payment
                    in (payload['payments'] as List).whereType<Map>())
                  _info(
                    'Recorded ${CustomerPresentation.label(payment['method'])}',
                    _money(payment['amount'], _currency),
                  ),
              _info(
                'Request reference',
                approval['request_id']?.toString() ?? 'Unavailable',
              ),
            ],
          ),
          if (approval['status'] == 'pending' &&
              _can('approve_credit', sensitive: true)) ...[
            SizedBox(height: TrexvenPresentation.spacing(context, 10)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button(
                  'Approve',
                  () => unawaited(_decide(approval, true)),
                  primary: true,
                  icon: Icons.check,
                ),
                _button('Reject', () => unawaited(_decide(approval, false))),
              ],
            ),
          ],
          const Divider(),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              SizedBox(height: TrexvenPresentation.spacing(context, 6)),
              Text(value, style: TrexvenPresentation.typography(context, TrexvenTypography.label)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TrexvenPresentation.typography(context, TrexvenTypography.label),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metricPair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth < 350 ||
            MediaQuery.textScalerOf(context).scale(14) > 20
        ? Column(children: [first, const SizedBox(height: 12), second])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Credit & Returns'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy || _loading ? null : () => unawaited(_reload()),
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (widget.owner)
          IconButton(
            tooltip: 'Credit limits',
            onPressed: _busy ? null : () => unawaited(_openLimits()),
            icon: const Icon(Icons.tune_rounded),
          ),
      ],
    ),
    body: !_current
        ? _empty(
            'Verify your account',
            'Return to the original authorized account and business to continue.',
          )
        : _loading
        ? const Center(child: TrexvenLoading())
        : RefreshIndicator(
            onRefresh: () => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TrexvenSpacing.pagePadding,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _day == null
                            ? 'Business day unavailable'
                            : CustomerPresentation.date(_day!['local_date']),
                      ),
                    ),
                    _CreditBadge(
                      _day?['timezone']?.toString() ?? 'Business day',
                    ),
                  ],
                ),
                if (_dayError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Daily figures unavailable. Check the business timezone and retry.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _notice(),
                if (widget.owner)
                  _metricPair(
                    _CreditMetric(
                      'Outstanding credit',
                      _totals == null
                          ? 'Unavailable'
                          : _money(_totals!['receivables'], _currency),
                      _accounts.error == null
                          ? '${_customers(_accounts.rows).where((c) => c.outstanding > 0).length} customers owing'
                          : 'Customer count unavailable',
                    ),
                    _CreditMetric(
                      'Repayments today',
                      _totals == null
                          ? 'Unavailable'
                          : _money(
                              _totals!['repayment_collections'],
                              _currency,
                            ),
                      'Collected, net of reversals',
                    ),
                  )
                else
                  _CreditCard(
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.branchId == null
                                ? 'Authorized credit and return operations'
                                : 'Operations for your selected branch',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_totalsError != null && widget.owner)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Financial summary unavailable; no estimated totals shown.',
                    ),
                  ),
                const SizedBox(height: 20),
                _tabs(const ['Credit', 'Returns'], _tab, (i) {
                  _tab = i;
                  _notify();
                }),
                ...(_tab == 0 ? _creditContent() : _returnContent()),
                _secondary(),
                if (_freshAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Last refreshed $_freshAt · Pull to refresh',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
  );
}
