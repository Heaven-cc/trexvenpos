import 'dart:async';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'customer_presentation.dart';
import 'package:flutter/material.dart';
import 'operations_client.dart';
import 'stock_count_batch.dart';
import 'text_controller_scope.dart';

part 'inventory_operations_views.dart';

class InventoryOperationsScreen extends StatefulWidget {
  final OperationsClient api;
  final Future<String?> Function(BuildContext)? scanBarcode;
  final Set<String> permissions;
  final bool manager;
  final String? branchId;
  final String? branchName;
  final bool Function()? contextIsCurrent;
  final VoidCallback? onRecordsChanged;
  const InventoryOperationsScreen({
    super.key,
    required this.api,
    this.scanBarcode,
    this.permissions = const {},
    this.manager = false,
    this.branchId,
    this.branchName,
    this.contextIsCurrent,
    this.onRecordsChanged,
  });
  @override
  State<InventoryOperationsScreen> createState() =>
      _InventoryOperationsScreenState();
}

class _InventoryOperationsScreenState extends State<InventoryOperationsScreen>
    with WidgetsBindingObserver {
  late Future<List<List<Map<String, dynamic>>>> data;
  bool busy = false;
  String? message;
  static const _inventoryRpcs = {
    'start_trexven_stocktake', 'count_trexven_stock',
    'submit_trexven_stocktake', 'approve_trexven_stocktake',
    'manage_trexven_stocktake', 'classify_trexven_stock',
    'resolve_trexven_condition_stock', 'dispatch_trexven_supplier_return',
    'acknowledge_trexven_supplier_return',
    'review_trexven_inventory_discrepancy',
    'start_trexven_branch_stocktake', 'classify_trexven_branch_stock',
    'resolve_trexven_branch_condition_stock', 'dispatch_trexven_branch_supplier_return',
  };
  Timer? _timer;
  bool _refreshing = false;
  bool _allSessions = false;
  String _sessionQuery = '';
  String _sessionFilter = 'active';
  String? _pendingRpc;
  late final String? _user;
  Map<String, dynamic>? _business;
  bool _branchesEnabled = true;
  bool _branchBackendReady = false;
  bool _branchAllowed = false;
  String? _selectedBranchId;
  String? get _branchId => widget.branchId ?? _selectedBranchId;

  bool get _current => mounted && _user != null &&
      widget.api.client.auth.currentUser?.id == _user &&
      (widget.contextIsCurrent?.call() ?? true);
  bool get _owner => _current && _business?['owner_id'] == _user;
  bool get _writesSupported => _branchesEnabled
      ? _branchBackendReady && _branchAllowed && _branchId != null
      : _branchId == null;
  bool _sessionWritesSupported(Map<String, dynamic> session) =>
      _writesSupported && session['branch_id'] == _branchId;
  bool _can(String permission, {bool sensitive = false}) => _current &&
      (_owner || ((!sensitive || widget.manager) &&
          widget.permissions.contains(permission)));

  @override
  void initState() {
    super.initState();
    _user = widget.api.client.auth.currentUser?.id;
    WidgetsBinding.instance.addObserver(this);
    load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ModalRoute.of(context)?.isCurrent == true) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) _refresh();
  }

  void load() { data = _loadRows(); }

  Future<List<List<Map<String, dynamic>>>> _loadRows() async {
    final business = await widget.api.client.from('businesses')
        .select('id,owner_id,branches_enabled')
        .eq('id', widget.api.businessId).single()
        .timeout(const Duration(seconds: 20));
    if (!_current) throw StateError('Business access changed. Reopen inventory.');
    _business = Map<String, dynamic>.from(business);
    _branchesEnabled = business['branches_enabled'] == true;
    _branchBackendReady = false;
    if (_branchesEnabled) {
      try {
        final capabilities = await widget.api.call('get_trexven_inventory_capabilities',
            {'p_business_id': widget.api.businessId})
            .timeout(const Duration(seconds: 20));
        _branchBackendReady = capabilities is Map &&
            capabilities['branch_inventory_version'] == 1;
      } catch (_) {
        // Old deployments and unavailable capability reads remain view-only.
        _branchBackendReady = false;
      }
    }
    if (!_current) throw StateError('Business access changed. Reopen inventory.');
    final pending = await widget.api.journal.pending();
    _pendingRpc = pending != null && pending['user'] == _user &&
            pending['business'] == widget.api.businessId
        ? pending['rpc']?.toString() : null;
    final rows = await Future.wait([
      widget.api.list('products'),
      widget.api.list('stocktake_sessions'),
      widget.api.list('stock_condition_entries'),
      widget.api.list('inventory_reconciliation_reviews'),
      widget.api.list('supplier_stock_returns'),
      if (_branchesEnabled) widget.api.list('inventory')
      else Future.value(<Map<String, dynamic>>[]),
      if (_branchesEnabled) widget.api.list('branches')
      else Future.value(<Map<String, dynamic>>[]),
    ].map((read) => read.timeout(const Duration(seconds: 20))));
    if (!_current) throw StateError('Business access changed. Reopen inventory.');
    final authorized = rows[6].where((row) => row['is_active'] == true)
        .map((row) => row['id']).toSet();
    if (_selectedBranchId != null && !authorized.contains(_selectedBranchId)) {
      _selectedBranchId = null;
    }
    _branchAllowed = _branchId != null && authorized.contains(_branchId);
    if (_branchId != null) {
      final sessionIds = rows[1].where((row) => row['branch_id'] == _branchId)
          .map((row) => row['id']).toSet();
      rows[1] = rows[1].where((row) => row['branch_id'] == _branchId).toList();
      rows[2] = rows[2].where((row) => row['branch_id'] == _branchId).toList();
      rows[3] = rows[3].where((row) => sessionIds.contains(row['session_id'])).toList();
      rows[4] = rows[4].where((row) => row['branch_id'] == _branchId).toList();
      rows[5] = rows[5].where((row) => row['branch_id'] == _branchId).toList();
      final stock = {for (final row in rows[5]) row['product_id']: row['quantity']};
      rows[0] = [
        for (final product in rows[0])
          if (stock.containsKey(product['id']))
            {...product, 'quantity': stock[product['id']]},
      ];
    }
    rows[1].sort((a, b) =>
        '${b['created_at']}'.compareTo('${a['created_at']}'));
    return rows;
  }

  Future<void> _refresh() async {
    if (!_current || busy || _refreshing) return;
    _refreshing = true;
    setState(load);
    try { await data; } catch (_) {
      // The FutureBuilder displays the retry state.
    } finally { _refreshing = false; }
  }

  Future<void> _prepare(Future<void> Function() action) async {
    if (!_current || busy) return;
    try { await action(); } catch (error) {
      if (_current) setState(() => message = CustomerPresentation.error(
        error, fallback: 'Unable to open inventory. Refresh and try again.'));
    }
  }

  bool _rpcAllowed(String rpc, Map<String, dynamic> args) {
    if (!_writesSupported) return false;
    return switch (rpc) {
      'start_trexven_stocktake' || 'count_trexven_stock' ||
      'submit_trexven_stocktake' => _can('stocktake'),
      'approve_trexven_stocktake' || 'manage_trexven_stocktake' ||
      'review_trexven_inventory_discrepancy' =>
        _can('approve_stocktake', sensitive: true),
      'classify_trexven_stock' =>
        _can('dispose_stock') && _can('adjust_stock'),
      'resolve_trexven_condition_stock' =>
        _can(args['p_action'] == 'restore' ? 'restore_stock' : 'writeoff_stock',
            sensitive: true) && _can('adjust_stock'),
      'dispatch_trexven_supplier_return' => _can('supplier_returns'),
      'acknowledge_trexven_supplier_return' =>
        _can('approve_supplier_returns', sensitive: true),
      _ => false,
    };
  }

  Future<void> _recover() async {
    if (!_current || busy) return;
    setState(() => busy = true);
    try {
      final pending = await widget.api.journal.pending();
      if (pending == null) {
        if (_current) setState(() { _pendingRpc = null; message = 'No interrupted operation.'; });
        return;
      }
      if (!_inventoryRpcs.contains(pending['rpc'])) {
        throw StateError('Recover this operation from its original screen.');
      }
      if (!_current) return;
      await widget.api.recoverPending();
      if (_current) {
        setState(() { _pendingRpc = null; message = 'Original inventory operation confirmed.'; load(); });
        try { widget.onRecordsChanged?.call(); } catch (_) {
          setState(() => message = 'Original action confirmed. Refresh inventory for the latest stock.');
        }
      }
    } catch (error) {
      if (_current) setState(() => message = CustomerPresentation.error(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancelPending() async {
    if (!_current || busy) return;
    setState(() => busy = true);
    try {
      final pending = await widget.api.journal.pending();
      if (pending == null || !_inventoryRpcs.contains(pending['rpc'])) {
        throw StateError('Manage this request from its original screen.');
      }
      var noMoneyMoved = false;
      if (!_current) return;
      final confirmed = await showDialog<bool>(
        animationStyle: TrexvenPresentation.motion(context),
context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) =>
          AlertDialog(
            scrollable: true,
            title: const Text('Cancel unconfirmed request?'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('The server will cancel only an uncommitted request. This does not undo saved stock changes or cancel the stocktake itself. Recover a committed operation instead.'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: noMoneyMoved,
                title: const Text('I confirm no payment or refund was made for this request.'),
                onChanged: (value) => refresh(() => noMoneyMoved = value == true)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep request')),
              FilledButton(onPressed: !noMoneyMoved ? null : () => Navigator.pop(dialogContext, true),
                child: const Text('Cancel request')),
            ],
          )),
      );
      if (confirmed != true || !_current) return;
      final current = await widget.api.journal.pending();
      if (current?['args']?['p_request_id'] != pending['args']['p_request_id']) {
        throw StateError('The pending request changed. Reopen inventory.');
      }
      if (!_current) return;
      await widget.api.discardUncommitted(noMoneyMoved: noMoneyMoved);
      if (_current) setState(() {
        _pendingRpc = null;
        message = 'The uncommitted inventory request was cancelled. No saved stock change was undone.';
        load();
      });
    } catch (error) {
      if (_current) setState(() => message = CustomerPresentation.error(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, String>?> fields(String title, List<String> names) async {
    if (!_current) return null;
    final controls = {for (final name in names) name: TextEditingController()};
    final form = GlobalKey<FormState>();
    return showDialog<Map<String, String>>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (dialogContext) => TextControllerScope(
        controllers: controls.values.toList(),
        child: AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Form(
            key: form,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in controls.entries)
                    if (entry.key.startsWith('Condition:'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: (TrexvenPresentation.isPos(context) ? TrexvenDropdown<String>(gap: 0,
                          decoration: const TrexvenInputDecoration(labelText: 'Stock condition'),
                          items: [
                            for (final condition in entry.key.split(':').last.split('/'))
                              DropdownMenuItem(
                                value: condition.trim(),
                                child: Text(CustomerPresentation.label(condition.trim())),
                              ),
                          ],
                          validator: (value) => value == null ? 'Select a condition.' : null,
                          onChanged: (value) => entry.value.text = value ?? '',
                        ) : DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const TrexvenInputDecoration(labelText: 'Stock condition'),
                          items: [
                            for (final condition in entry.key.split(':').last.split('/'))
                              DropdownMenuItem(
                                value: condition.trim(),
                                child: Text(CustomerPresentation.label(condition.trim())),
                              ),
                          ],
                          validator: (value) => value == null ? 'Select a condition.' : null,
                          onChanged: (value) => entry.value.text = value ?? '',
                        )),
                      )
                    else
                      TrexvenTextFormField(
                        controller: entry.value,
                        maxLines: entry.key == 'Barcode counts' ? 6 :
                            entry.key.toLowerCase().contains('reason') ? 3 : 1,
                        keyboardType: entry.key.toLowerCase().contains('quantity')
                            ? const TextInputType.numberWithOptions(decimal: true) : null,
                        decoration: TrexvenInputDecoration(labelText: entry.key),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Enter ${entry.key.toLowerCase()}.';
                          if (entry.key.toLowerCase().contains('quantity')) {
                            final quantity = num.tryParse(text);
                            if (quantity == null || !quantity.isFinite || quantity < 0 ||
                                !RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
                              return 'Enter a non-negative quantity with up to 3 decimals.';
                            }
                          }
                          return null;
                        },
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!_current || !form.currentState!.validate()) return;
                Navigator.pop(dialogContext,
                    controls.map((key, value) => MapEntry(key, value.text.trim())));
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> run(String rpc, Map<String, dynamic> args) async {
    if (!_current || busy) return;
    if (_pendingRpc != null) {
      setState(() => message = 'Recover or cancel the original unconfirmed request first.');
      return;
    }
    if (!_rpcAllowed(rpc, args)) {
      setState(() => message = !_writesSupported
          ? 'Stock changes for branch-enabled businesses require backend support.'
          : 'Your current role does not permit this action.');
      return;
    }
    setState(() => busy = true);
    try {
      final branchRpc = !_branchesEnabled || _branchId == null ? rpc : switch (rpc) {
        'start_trexven_stocktake' => 'start_trexven_branch_stocktake',
        'classify_trexven_stock' => 'classify_trexven_branch_stock',
        'resolve_trexven_condition_stock' => 'resolve_trexven_branch_condition_stock',
        'dispatch_trexven_supplier_return' => 'dispatch_trexven_branch_supplier_return',
        _ => rpc,
      };
      await widget.api.call(branchRpc, {
        'p_request_id': widget.api.requestId(),
        ...args,
        if (branchRpc != rpc) 'p_branch_id': _branchId,
      });
      if (_current) {
        setState(() {
          _pendingRpc = null;
          message = 'The action has been confirmed.';
          load();
        });
        try { widget.onRecordsChanged?.call(); } catch (_) {
          setState(() => message = 'Action confirmed. Refresh inventory to see the latest stock.');
        }
      }
    } catch (e) {
      if (_current) {
        final pending = await widget.api.journal.pending();
        if (_current) setState(() {
          _pendingRpc = pending?['rpc']?.toString();
          message = CustomerPresentation.error(e,
              fallback: 'No confirmation received. Recover the original operation before starting another.');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> start() async {
    final f = await fields('Start online stocktaking', ['Count name']);
    if (f == null) return;
    await run('start_trexven_stocktake', {
      'p_business_id': widget.api.businessId,
      'p_name': f['Count name'],
    });
  }

  Future<void> session(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> products,
  ) async {
    if (!_current) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _InventorySessionPage(
          operations: this, initialSession: s, products: products),
      ),
    );
    if (_current) await _refresh();
  }

  Future<void> count(Map<String, dynamic> s, Map<String, dynamic> c) async {
    final f = await fields('Physical count', ['Quantity']);
    if (f == null) return;
    await run('count_trexven_stock', {
      'p_session_id': s['id'],
      'p_counts': [
        {
          'product_id': c['product_id'],
          'version': c['version'],
          'quantity': f['Quantity'],
        },
      ],
    });
  }

  Future<void> scannedCount(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> counts,
    List<Map<String, dynamic>> products,
  ) async {
    final batch = StockCountBatch();
    String? action = 'scan';
    try {
      while (mounted) {
        if (action == 'scan') {
          final barcode = await widget.scanBarcode!(context);
          if (!mounted) return;
          if (barcode != null) {
            final line = batch.resolve(barcode, products, counts);
            final input = await fields(
              'Count ${line['name']} (add scanned units)',
              ['Quantity'],
            );
            if (input != null) batch.set(line, input['Quantity']!, add: true);
          }
        } else if (action != null && action.startsWith('edit:')) {
          final id = action.substring(5);
          final input = await fields('Set reviewed physical quantity', [
            'Quantity',
          ]);
          if (input != null)
            batch.set(
              counts.firstWhere((c) => c['product_id'] == id),
              input['Quantity']!,
            );
        } else if (action != null && action.startsWith('remove:')) {
          batch.lines.remove(action.substring(7));
        }
        if (!mounted) return;
        action = await showDialog<String>(
          animationStyle: TrexvenPresentation.motion(context),
context: context,
          builder: (context) => SimpleDialog(
            title: Text('Review camera count · ${s['name']}'),
            children: [
              for (final line in batch.lines.values)
                ListTile(
                  title: Text(
                    products
                        .firstWhere(
                          (p) => p['id'] == line['product_id'],
                        )['name']
                        .toString(),
                  ),
                  subtitle: Text(
                    'Qty ${line['quantity']} · version ${line['version']}',
                  ),
                  onTap: () =>
                      Navigator.pop(context, 'edit:${line['product_id']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        Navigator.pop(context, 'remove:${line['product_id']}'),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'scan'),
                child: const Text('Scan another product'),
              ),
              FilledButton(
                onPressed: batch.lines.isEmpty
                    ? null
                    : () => Navigator.pop(context, 'submit'),
                child: const Text('Submit reviewed batch'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        if (action == null) return;
        if (action == 'submit') {
          await run('count_trexven_stock', {
            'p_session_id': s['id'],
            'p_counts': batch.lines.values.toList(),
          });
          return;
        }
      }
    } catch (e) {
      if (mounted)
        setState(
          () => message = CustomerPresentation.error(
            e,
            fallback: 'Count not submitted. Please try again.',
          ),
        );
    }
  }

  Future<void> bulkCount(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> counts,
    List<Map<String, dynamic>> products,
  ) async {
    final f = await fields('Barcode counts: one barcode,quantity per line', [
      'Barcode counts',
    ]);
    if (f == null) return;
    try {
      final lines = <Map<String, dynamic>>[];
      for (final line
          in f['Barcode counts']!
              .split('\n')
              .where((l) => l.trim().isNotEmpty)) {
        final parts = line.split(',');
        if (parts.length != 2) throw FormatException('Use barcode,quantity.');
        final matches = products
            .where((p) => p['barcode'] == parts[0].trim())
            .toList();
        if (matches.length != 1)
          throw FormatException('Barcode is missing or ambiguous.');
        final c = counts
            .where((c) => c['product_id'] == matches.single['id'])
            .first;
        lines.add({
          'product_id': c['product_id'],
          'version': c['version'],
          'quantity': parts[1].trim(),
        });
      }
      if (lines.isEmpty) throw const FormatException('Enter at least one count.');
      final seen = <dynamic>{};
      for (final line in lines) {
        if (!seen.add(line['product_id'])) {
          throw const FormatException('Enter each product only once in a barcode batch.');
        }
        final quantity = num.tryParse(line['quantity'] as String);
        if (quantity == null || !quantity.isFinite || quantity < 0) {
          throw const FormatException('Enter valid non-negative physical quantities.');
        }
      }
      await run('count_trexven_stock', {
        'p_session_id': s['id'],
        'p_counts': lines,
      });
    } catch (e) {
      if (mounted)
        setState(
          () => message = CustomerPresentation.error(
            e,
            fallback: 'Counts were not submitted. Please try again.',
          ),
        );
    }
  }

  Future<void> approve(Map<String, dynamic> s) async {
    final f = await fields(
      'Approve physical discrepancy; later movements are retained',
      ['Reason'],
    );
    if (f == null) return;
    await run('approve_trexven_stocktake', {
      'p_session_id': s['id'],
      'p_reason': f['Reason'],
    });
  }

  Future<void> manage(Map<String, dynamic> s, String action) async {
    final f = await fields('$action count session', ['Reason']);
    if (f == null) return;
    await run('manage_trexven_stocktake', {
      'p_session_id': s['id'],
      'p_action': action,
      'p_reason': f['Reason'],
    });
  }

  Future<void> reassign(
    Map<String, dynamic> s,
    Map<String, dynamic> count,
  ) async {
    final members = await widget.api.list('business_members');
    if (!mounted) return;
    final user = await showDialog<String>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (context) => SimpleDialog(
        title: Text('Reassign this count to an active employee'),
        children: [
          for (final m in members.where((m) => m['status'] == 'active'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m['user_id'] as String),
              child: Text('${m['full_name'] ?? m['role']}'),
            ),
        ],
      ),
    );
    if (user == null || !mounted) return;
    final f = await fields('Explain count reassignment', ['Reason']);
    if (f == null) return;
    await run('manage_trexven_stocktake', {
      'p_session_id': s['id'],
      'p_action': 'reassign',
      'p_product_id': count['product_id'],
      'p_counter_id': user,
      'p_reason': f['Reason'],
    });
  }

  Future<Map<String, dynamic>?> product(List<Map<String, dynamic>> products) async {
    if (!_current) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      sheetAnimationStyle: TrexvenPresentation.motion(context, sheet: true),
context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InventoryProductPicker(products: products),
    );
  }
  Future<void> classify(List<Map<String, dynamic>> products) async {
    final p = await product(products);
    if (p == null) return;
    final f = await fields('Classify ${p['name']}', [
      'Quantity',
      'Condition: damaged / expired / defective / lost',
      'Reason',
    ]);
    if (f == null) return;
    await run('classify_trexven_stock', {
      'p_business_id': widget.api.businessId,
      'p_product_id': p['id'],
      'p_quantity': f['Quantity'],
      'p_condition': f['Condition: damaged / expired / defective / lost'],
      'p_reason': f['Reason'],
    });
  }

  Future<void> resolve(
    List<Map<String, dynamic>> products,
    String action,
  ) async {
    final p = await product(products);
    if (p == null) return;
    final f = await fields(
      action == 'supplier'
          ? 'Dispatch nonsellable supplier return'
          : '$action inspected stock',
      [
        'Quantity',
        'Condition: damaged / expired / defective',
        if (action == 'supplier') 'Supplier name',
        'Inspection and reason',
      ],
    );
    if (f == null) return;
    await run(
      action == 'supplier'
          ? 'dispatch_trexven_supplier_return'
          : 'resolve_trexven_condition_stock',
      {
        'p_business_id': widget.api.businessId,
        'p_product_id': p['id'],
        'p_quantity': f['Quantity'],
        'p_condition': f['Condition: damaged / expired / defective'],
        'p_reason': f['Inspection and reason'],
        if (action == 'supplier')
          'p_supplier_name': f['Supplier name']
        else
          'p_action': action,
      },
    );
  }

  Future<void> review(Map<String, dynamic> r) async {
    final f = await fields(
      'Review late offline movement; closed counts remain unchanged',
      ['Reconciliation reason'],
    );
    if (f == null) return;
    await run('review_trexven_inventory_discrepancy', {
      'p_review_id': r['id'],
      'p_reason': f['Reconciliation reason'],
    });
  }

  Future<void> supplier(Map<String, dynamic> r) async {
    final f = await fields('Supplier acknowledgment: ${r['supplier_name']}', [
      'Accepted quantity',
      'Returned nonsellable quantity',
      'Acknowledgment and discrepancy reason',
    ]);
    if (f == null) return;
    await run('acknowledge_trexven_supplier_return', {
      'p_return_id': r['id'],
      'p_accepted': f['Accepted quantity'],
      'p_returned': f['Returned nonsellable quantity'],
      'p_reason': f['Acknowledgment and discrepancy reason'],
    });
  }

  Color get _blue => Theme.of(context).trexvenColors.brandBlue ??
      Theme.of(context).colorScheme.primary;

  Widget _surface(Widget child, {EdgeInsetsGeometry? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).trexvenColors.cardBackground ??
          Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _status(dynamic value) {
    final status = value?.toString() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'open' || 'dispatched' => _blue,
      'review' || 'pending' => Theme.of(context).trexvenColors.warning ?? scheme.primary,
      'closed' || 'acknowledged' || 'resolved' =>
          Theme.of(context).trexvenColors.success ?? scheme.primary,
      'cancelled' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: TrexvenPresentation.spacing(context, 9), vertical: TrexvenPresentation.spacing(context, 5)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(TrexvenRadii.status),
      ),
      child: Text(CustomerPresentation.label(value),
        style: TextStyle(color: color, fontSize: TrexvenPresentation.fontSize(context, 12), fontWeight: FontWeight.w600)),
    );
  }

  Widget _notice(String text, {IconData icon = Icons.info_outline}) => _surface(
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: _blue),
      SizedBox(width: TrexvenPresentation.spacing(context, 10)),
      Expanded(child: Semantics(liveRegion: true, child: Text(text))),
    ]),
  );

  Widget _empty(String title, String description, IconData icon) => Padding(
    padding: EdgeInsets.symmetric(vertical: TrexvenPresentation.spacing(context, 22), horizontal: 12),
    child: Column(children: [
      Icon(icon, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center,
        style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 16), fontWeight: FontWeight.w700)),
      SizedBox(height: TrexvenPresentation.spacing(context, 6)),
      Text(description, textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );

  Widget _heading(String title, {Widget? action}) => Padding(
    padding: EdgeInsets.only(top: TrexvenPresentation.spacing(context, 22), bottom: 12),
    child: Row(children: [
      Expanded(child: Text(title,
        style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 17), fontWeight: FontWeight.w700))),
      if (action != null) action,
    ]),
  );

  Widget _entry({
    required String title, required String subtitle, required IconData icon,
    dynamic status, VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: TrexvenPresentation.spacing(context, 5)),
    leading: Container(
      padding: EdgeInsets.all(TrexvenPresentation.spacing(context, 10)),
      decoration: BoxDecoration(color: _blue.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, color: _blue, size: 21),
    ),
    title: Text(title,
      style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 14), fontWeight: FontWeight.w600)),
    subtitle: Padding(
      padding: EdgeInsets.only(top: TrexvenPresentation.spacing(context, 5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(subtitle),
        if (status != null) ...[SizedBox(height: TrexvenPresentation.spacing(context, 6)), _status(status)],
      ]),
    ),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  Widget _summary(List<List<Map<String, dynamic>>> rows) {
    final metrics = [
      ('Open counts', rows[1].where((r) => r['status'] == 'open').length),
      ('In review', rows[1].where((r) => r['status'] == 'review').length),
      ('Pending', rows[3].where((r) => r['status'] == 'pending').length),
    ];
    return _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Stock operations',
          style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 15), fontWeight: FontWeight.w600))),
        Tooltip(message: 'Counts from records you are authorized to view',
          child: Icon(Icons.sync_rounded, size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      SizedBox(height: TrexvenPresentation.spacing(context, 18)),
      LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final cards = [
          for (final metric in metrics)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${metric.$2}',
                style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 27), fontWeight: FontWeight.w700)),
              SizedBox(height: TrexvenPresentation.spacing(context, 5)),
              Text(metric.$1, style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 12),
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
        ];
        if (stacked) return Wrap(spacing: 24, runSpacing: 16, children: cards);
        return Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final card in cards) Expanded(child: card)]);
      }),
    ]));
  }

  Widget _management(List<Map<String, dynamic>> products) {
    final actions = <Widget>[
      if (_can('dispose_stock') && _can('adjust_stock'))
        _entry(title: 'Damaged, expired or lost',
          subtitle: 'Record non-sellable stock', icon: Icons.inventory_2_outlined,
          onTap: busy || _pendingRpc != null || !_writesSupported ? null : () => _prepare(() => classify(products))),
      if (_can('restore_stock', sensitive: true) && _can('adjust_stock'))
        _entry(title: 'Restore stock', subtitle: 'Return inspected items to inventory',
          icon: Icons.restore_rounded,
          onTap: busy || !_writesSupported ? null : () => _prepare(() => resolve(products, 'restore'))),
      if (_can('writeoff_stock', sensitive: true) && _can('adjust_stock'))
        _entry(title: 'Write off stock', subtitle: 'Remove stock with an audit record',
          icon: Icons.remove_circle_outline,
          onTap: busy || !_writesSupported ? null : () => _prepare(() => resolve(products, 'writeoff'))),
      if (_can('supplier_returns'))
        _entry(title: 'Supplier returns', subtitle: 'Return non-sellable products to suppliers',
          icon: Icons.local_shipping_outlined,
          onTap: busy || !_writesSupported ? null : () => _prepare(() => resolve(products, 'supplier'))),
    ];
    if (actions.isEmpty) return _notice(
      'You can view stock and saved sessions. Stock changes require the appropriate permission.',
      icon: Icons.lock_outline);
    return _surface(Column(children: [
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const Divider(height: 20),
        actions[i],
      ],
    ]), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4));
  }

  Widget _sessions(List<List<Map<String, dynamic>>> rows) {
    final filtered = rows[1].where((row) {
      final status = row['status'];
      final matches = switch (_sessionFilter) {
        'active' => status == 'open' || status == 'review',
        'closed' => status == 'closed' || status == 'cancelled',
        _ => true,
      };
      return (!_allSessions || matches) &&
          '${row['name']}'.toLowerCase().contains(_sessionQuery.toLowerCase());
    }).toList();
    final visible = _allSessions
        ? filtered
        : filtered.where((row) => row['status'] == 'open' || row['status'] == 'review').take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('Count sessions', action: TextButton(
        onPressed: () => setState(() { _allSessions = !_allSessions; _sessionQuery = ''; }),
        child: Text(_allSessions ? 'Show active' : 'View all'),
      )),
      if (_allSessions) ...[
        TrexvenTextField(
          variant: TrexvenFieldVariant.search,
          onChanged: (value) => setState(() => _sessionQuery = value.trim()),
          decoration: const TrexvenInputDecoration(
            hintText: 'Search count sessions', prefixIcon: Icon(Icons.search_rounded)),
        ),
        Wrap(spacing: 8, children: [
          for (final filter in const [('active', 'Active'), ('closed', 'Completed'), ('all', 'All')])
            ChoiceChip(label: Text(filter.$2), selected: _sessionFilter == filter.$1,
              onSelected: (_) => setState(() => _sessionFilter = filter.$1)),
        ]),
        SizedBox(height: TrexvenPresentation.spacing(context, 10)),
      ],
      _surface(visible.isEmpty
        ? _empty(_allSessions ? 'No matching sessions' : 'No active stocktakes',
            _allSessions ? 'Try a different search or status.' : 'New counting sessions will appear here.',
            Icons.assignment_turned_in_outlined)
        : Column(children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _entry(title: '${visible[i]['name']}',
                subtitle: visible[i]['branch_id'] == null ? 'Business stock · Open to resume or review' :
                    'Branch stock · Open to view',
                status: visible[i]['status'], icon: Icons.fact_check_outlined,
                onTap: busy ? null : () => _prepare(() => session(visible[i], rows[0]))),
            ],
          ])),
    ]);
  }

  Widget _records(String title, String description, List<Widget> children, {
    required String empty, required IconData icon,
  }) => Padding(
    padding: EdgeInsets.only(top: TrexvenPresentation.spacing(context, 14)),
    child: _surface(ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: _blue, size: 21),
      title: Text(title, style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 14), fontWeight: FontWeight.w600)),
      subtitle: Text(description),
      children: children.isEmpty
          ? [Padding(padding: const EdgeInsets.all(16), child: Text(empty))]
          : [for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1), children[i],
            ]],
    ), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: false, elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Inventory options',
            onSelected: (value) {
              if (value == 'refresh') _refresh();
              else setState(() { _allSessions = true; _sessionFilter = 'all'; });
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'refresh', enabled: !busy, child: const Text('Refresh inventory')),
              const PopupMenuItem(value: 'sessions', child: Text('All count sessions')),
            ],
          ),
        ],
      ),
      body: SafeArea(top: false, child: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: TrexvenLoading());
          }
          if (!_current || snapshot.hasError || !snapshot.hasData) {
            return Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_outlined, size: 32),
                const SizedBox(height: 12),
                const Text('Unable to load current inventory. Check your connection and business access.',
                  textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _current && !busy ? _refresh : null,
                  icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
              ])));
          }
          final rows = snapshot.data!;
          final names = {for (final product in rows[0]) product['id']: product['name'] ?? 'Product'};
          final branches = {for (final branch in rows[6]) branch['id']: branch['name'] ?? 'Branch'};
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (busy) const Padding(padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 3)),
                  if (message != null) ...[
                    _notice(message!),
                    Align(alignment: Alignment.centerRight, child: TextButton(
                      onPressed: () => setState(() => message = null), child: const Text('Dismiss'))),
                  ],
                  if (_pendingRpc != null) ...[
                    _notice('An interrupted operation needs confirmation. Recover its original request before starting another.'),
                    OutlinedButton.icon(onPressed: busy ? null : _recover,
                      icon: const Icon(Icons.history_rounded), label: const Text('Recover original operation')),
                    if (_inventoryRpcs.contains(_pendingRpc))
                      TextButton(onPressed: busy ? null : _cancelPending,
                        child: const Text('Cancel uncommitted request')),
                    const SizedBox(height: 12),
                  ],
                  if (widget.branchName != null)
                    Padding(padding: EdgeInsets.only(bottom: TrexvenPresentation.spacing(context, 10)),
                      child: Text(widget.branchName!, style: theme.textTheme.labelLarge)),
                  _summary(rows),
                  if (_branchesEnabled && _owner && widget.branchId == null) ...[
                    SizedBox(height: TrexvenPresentation.spacing(context, 14)),
                    (TrexvenPresentation.isPos(context) ? TrexvenDropdown<String>(gap: 0,
                      key: ValueKey(_selectedBranchId),
                      initialValue: _selectedBranchId,
                      decoration: const TrexvenInputDecoration(labelText: 'Inventory branch'),
                      items: [
                        const DropdownMenuItem<String>(value: null,
                          child: Text('All branches (view only)')),
                        for (final branch in rows[6].where((row) => row['is_active'] == true))
                          DropdownMenuItem<String>(value: branch['id'] as String,
                            child: Text('${branch['name']}')),
                      ],
                      onChanged: busy || _pendingRpc != null ? null : (value) {
                        setState(() { _selectedBranchId = value; load(); });
                      },
                    ) : DropdownButtonFormField<String>(
                      key: ValueKey(_selectedBranchId),
                      initialValue: _selectedBranchId,
                      isExpanded: true,
                      decoration: const TrexvenInputDecoration(labelText: 'Inventory branch'),
                      items: [
                        const DropdownMenuItem<String>(value: null,
                          child: Text('All branches (view only)')),
                        for (final branch in rows[6].where((row) => row['is_active'] == true))
                          DropdownMenuItem<String>(value: branch['id'] as String,
                            child: Text('${branch['name']}')),
                      ],
                      onChanged: busy || _pendingRpc != null ? null : (value) {
                        setState(() { _selectedBranchId = value; load(); });
                      },
                    )),
                  ],
                  SizedBox(height: TrexvenPresentation.spacing(context, 14)),
                  if (_can('stocktake'))
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        padding: EdgeInsets.symmetric(horizontal: TrexvenPresentation.spacing(context, 18), vertical: TrexvenPresentation.spacing(context, 14)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        backgroundColor: theme.brightness == Brightness.dark
                            ? theme.colorScheme.onSurface : _blue,
                        foregroundColor: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surface : theme.colorScheme.onPrimary,
                      ),
                      onPressed: busy || !_writesSupported || _pendingRpc != null
                          ? null : () => _prepare(start),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Start stocktake'),
                    ),
                  if (!_writesSupported) ...[
                    const SizedBox(height: 12),
                    _notice(_branchBackendReady && _branchId == null
                        ? 'Select a branch to start counting or manage its stock.'
                        : 'Branch inventory is available to view. Stock changes are currently unavailable for this branch.',
                      icon: Icons.store_outlined),
                  ],
                  _heading('Stock management'),
                  _management(rows[0]),
                  _sessions(rows),
                  if (_branchesEnabled)
                    _records('Branch inventory', 'On-hand and reserved quantities',
                      [
                        for (final row in rows[5])
                          _entry(title: '${names[row['product_id']] ?? 'Product'}',
                            subtitle: '${branches[row['branch_id']] ?? 'Branch'} · On hand ${row['quantity']} · Reserved ${row['reserved_quantity']}',
                            icon: Icons.store_outlined),
                      ], empty: 'No branch inventory records available.', icon: Icons.store_outlined),
                  _records('Non-sellable stock', 'Condition ledger and recorded reasons',
                    [
                      for (final row in rows[2])
                        _entry(title: '${names[row['product_id']] ?? 'Product'} · ${row['quantity']}',
                          subtitle: '${CustomerPresentation.label(row['kind'])} · ${row['reason'] ?? ''}',
                          status: row['condition'], icon: Icons.inventory_2_outlined),
                    ], empty: 'No non-sellable stock entries yet.', icon: Icons.inventory_2_outlined),
                  _records('Supplier returns', '${rows[4].where((r) => r['status'] == 'dispatched').length} awaiting acknowledgment',
                    [
                      for (final row in rows[4])
                        _entry(title: '${row['supplier_name']} · ${row['quantity']}',
                          subtitle: '${names[row['product_id']] ?? 'Product'}',
                          status: row['status'], icon: Icons.local_shipping_outlined,
                          onTap: busy || !_writesSupported || row['status'] != 'dispatched' ||
                              !_can('approve_supplier_returns', sensitive: true)
                            ? null : () => _prepare(() => supplier(row))),
                    ], empty: 'No supplier returns yet.', icon: Icons.local_shipping_outlined),
                  _records('Offline reconciliation', 'Review late stock movements',
                    [
                      for (final row in rows[3])
                        _entry(title: 'Late stock movement · ${row['quantity']}',
                          subtitle: '${row['reason'] ?? ''}', status: row['status'],
                          icon: Icons.sync_problem_outlined,
                          onTap: busy || !_writesSupported || row['status'] != 'pending' ||
                              !_can('approve_stocktake', sensitive: true)
                            ? null : () => _prepare(() => review(row))),
                    ], empty: 'No late movements to review.', icon: Icons.sync_problem_outlined),
                ]),
              ))],
            ),
          );
        },
      )),
    );
  }
}
