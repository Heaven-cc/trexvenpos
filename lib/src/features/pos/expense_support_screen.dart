import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';

/// Cash-only expense entry using server-authoritative, durable operations.
class PosExpenseSupportScreen extends ConsumerStatefulWidget {
  const PosExpenseSupportScreen({super.key});

  @override
  ConsumerState<PosExpenseSupportScreen> createState() => _PosExpenseSupportScreenState();
}

class _PosExpenseSupportScreenState extends ConsumerState<PosExpenseSupportScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Shop supplies';
  int _tab = 0;


  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;
  String? _shift;
  String? _day;
  String? _scopeKey;
  bool _branchHistory = false;
  bool _historyLoaded = false;
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _cursor;
  Map<String, dynamic>? _pending;
  OperationsClient? _api;

  String get _currentScope {
    final auth = ref.read(authStateProvider);
    return '${auth.employee?.userId}:${auth.activeBusiness?.id}:${ref.read(branchContextProvider)?.id}';
  }

  bool get _canRecord => !ref.read(authStateProvider).offlineCashOnly &&
      ref.read(permissionServiceProvider).hasPermission('pos_access') &&
      ref.read(permissionServiceProvider).hasPermission('record_expenses');
  bool get _canReadBranch {
    final access = ref.read(permissionServiceProvider);
    return !ref.read(authStateProvider).offlineCashOnly &&
        (access.isOwner || access.isManager) &&
        access.hasPermission('view_pos_expenses');
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    final business = auth.activeBusiness;
    final branch = ref.read(branchContextProvider);
    final key = _currentScope;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      if (business == null || auth.employee == null || auth.offlineCashOnly ||
          (business.branchesEnabled && branch == null)) {
        throw StateError('Connect and select an authorized business and branch.');
      }
      final api = OperationsClient.pos(ref.read(supabaseProvider), business.id);
      final pending = await api.journal.pending();
      final day = await ref.read(supabaseProvider).rpc(
        'get_trexven_business_day', params: {'p_business_id': business.id},
      ).timeout(const Duration(seconds: 20));
      final cash = ref.read(permissionServiceProvider).hasPermission('cash_shifts')
          ? await api.cashContext().timeout(const Duration(seconds: 20))
          : <String, dynamic>{'shifts': <dynamic>[]};
      if (!mounted || key != _currentScope) return;
      final shifts = (cash['shifts'] as List? ?? []).whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => r['status'] == 'open' && r['joined'] == true &&
              r['register_active'] == true && r['branch_id'] == branch?.id).toList();
      setState(() {
        _api = api; _scopeKey = key; _pending = pending;
        _day = (day as Map)['local_date']?.toString(); _shifts = shifts;
        if (!shifts.any((s) => s['id'] == _shift)) _shift = null;
        _history = []; _cursor = null; _historyLoaded = false;
      });
      if (_tab == 1) await _loadHistory();
    } catch (error) {
      if (mounted && key == _currentScope) setState(() =>
        _error = CustomerPresentation.error(error, fallback: 'Unable to verify Expenses. Retry.'));
    } finally {
      if (mounted && key == _currentScope) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory({bool more = false}) async {
    if (_busy || _api == null) return;
    final key = _scopeKey;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await ref.read(supabaseProvider).rpc('get_pos_expenses', params: {
        'p_business_id': ref.read(authStateProvider).activeBusiness!.id,
        'p_branch_id': ref.read(branchContextProvider)?.id,
        'p_branch_history': _branchHistory && _canReadBranch,
        'p_limit': 50,
        'p_before_created_at': more ? _cursor?['created_at'] : null,
        'p_before_id': more ? _cursor?['id'] : null,
      }).timeout(const Duration(seconds: 20));
      if (!mounted || key != _currentScope) return;
      final page = Map<String, dynamic>.from(result as Map);
      final rows = (page['items'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      setState(() {
        _history = more ? [..._history, ...rows] : rows;
        _cursor = page['next_cursor'] == null ? null : Map<String, dynamic>.from(page['next_cursor'] as Map);
        _historyLoaded = true;
      });
    } catch (error) {
      if (mounted && key == _currentScope) setState(() => _error =
        CustomerPresentation.error(error, fallback: 'Unable to load expense history.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool recover = false}) async {
    if (_busy || _api == null || _scopeKey != _currentScope) return;
    final api = _api!;
    final key = _scopeKey;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      final pending = await api.journal.pending();
      dynamic response;
      if (recover) {
        if (pending == null || pending['rpc'] != 'record_pos_expense' ||
            pending['user'] != ref.read(authStateProvider).employee?.userId ||
            pending['business'] != api.businessId) {
          throw StateError('Recover this operation with its original employee and business.');
        }
        response = await api.recoverPending();
      } else {
        if (!_canRecord) throw StateError('Ask your owner for expense recording permission.');
        if (pending != null) throw StateError('Recover the retained operation before recording another expense.');
        final cents = OperationsClient.moneyCents(_amount.text);
        if (_description.text.length > 2000) throw StateError('Keep the description within 2000 characters.');
        response = await api.call('record_pos_expense', {
          'p_business_id': api.businessId, 'p_request_id': api.requestId(),
          'p_amount': OperationsClient.amount(cents), 'p_category': _category,
          'p_description': _description.text.trim(),
          'p_branch_id': ref.read(branchContextProvider)?.id, 'p_shift_id': _shift,
        });
      }
      if (!mounted || key != _currentScope) return;
      if (response is! Map || response['id'] == null || response['business_id'] != api.businessId) {
        throw StateError('Expense receipt could not be verified. Check the original request.');
      }
      _amount.clear(); _description.clear();
      setState(() {
        _pending = null; _notice = 'Expense saved · ${response['business_date']}';
        _day = response['business_date']?.toString();
        _historyLoaded = false; _history = []; _cursor = null;
      });
    } catch (error) {
      if (mounted && key == _currentScope) {
        Map<String, dynamic>? retained = _pending;
        try { retained = await api.journal.pending(); } catch (_) { /* Keep the original journal intact. */ }
        if (mounted) setState(() {
          _pending = retained;
          _error = error is FormatException ? error.message : error is StateError ? error.message.toString() : CustomerPresentation.error(error,
            fallback: 'Save is unconfirmed. Recover the original request before recording again.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectTab(int value) {
    setState(() => _tab = value);
    if (value == 1 && !_historyLoaded && !_busy) _loadHistory();
  }

  static const _categories = [
    'Shop supplies',
    'Food & refreshments',
    'Transport',
    'Utilities',
    'Other expense',
  ];

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget _lockedField(String label, String value, IconData icon) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      _panel(Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if ((_scopeKey != null && _scopeKey != _currentScope) ||
        (!_canRecord && !_canReadBranch) || (_branchHistory && !_canReadBranch)) {
      return Scaffold(appBar: AppBar(title: const Text('Expenses')),
        body: const Center(child: Text('Verify your expense permission and reopen this workflow in the authorized branch.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses'),
        actions: [IconButton(
          tooltip: 'Expense history',
          onPressed: () => _selectTab(1),
          icon: const Icon(Icons.receipt_long_outlined),
        )]),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Record & manage cash spending',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _panel(Row(children: [
            Icon(Icons.store_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current branch', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(ref.watch(branchContextProvider)?.name ?? ref.watch(authStateProvider).activeBusiness?.name ?? 'Select business',
                  style: Theme.of(context).textTheme.bodySmall),
              ])),
            const Icon(Icons.shield_outlined),
          ])),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Record Expense')),
              ButtonSegment(value: 1, label: Text('Expense History')),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) => _selectTab(selection.first),
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: scheme.error)),
            TextButton(onPressed: _busy ? null : _load, child: const Text('Retry connection')),
          ],
          if (_notice != null) Text(_notice!),
          if (_pending != null) _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('A retained operation must be resolved before another expense.'),
            if (_pending!['rpc'] == 'record_pos_expense')
              FilledButton(onPressed: _busy ? null : () => _save(recover: true),
                child: const Text('Check & recover original expense'))
            else const Text('Use More → Operations to recover the original operation.'),
          ])),
          if (_tab == 0) ...[
            Row(children: [
              Expanded(child: Text('New Expense',
                style: Theme.of(context).textTheme.titleMedium)),
              Chip(label: const Text('Cash only'),
                avatar: const Icon(Icons.payments_outlined, size: 18)),
            ]),
            const SizedBox(height: 12),
            _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _amount,
                enabled: !_busy && _pending == null && _canRecord,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText: 'Currency follows the active business when connected',
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Expense category'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: _busy || _pending != null || !_canRecord ? null : (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _description,
                enabled: !_busy && _pending == null && _canRecord,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What was the money spent on?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lockedField('Payment method', 'Cash', Icons.payments_outlined),
                const SizedBox(width: 10),
                _lockedField('Date', _day ?? 'Checking business day…', Icons.calendar_today_outlined),
              ]),
            ])),
            const SizedBox(height: 14),
            if (_shifts.isNotEmpty) DropdownButtonFormField<String>(
              value: _shift ?? '',
              decoration: const InputDecoration(labelText: 'Cash drawer (optional)'),
              items: [
                const DropdownMenuItem(value: '', child: Text('No drawer')),
                for (final shift in _shifts) DropdownMenuItem(
                  value: shift['id'].toString(), child: Text(shift['register_name']?.toString() ?? 'Cash drawer')),
              ],
              onChanged: _busy || _pending != null ? null : (value) => setState(() => _shift = value == '' ? null : value),
            ),
            const SizedBox(height: 14),
            Text(_canRecord
              ? 'The server records today in the business timezone. Select a drawer only when this spending came from it.'
              : 'Ask your owner for expense recording permission.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading || _busy || _api == null || _pending != null || !_canRecord ? null : _save,
              icon: const Icon(Icons.add),
              label: Text(_busy ? 'Verifying expense…' : 'Save Expense'),
            ),
          ] else ...[
            Text('Expense History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_canReadBranch) SwitchListTile(
              title: const Text('Branch expense history'),
              subtitle: const Text('Off shows only your own records'),
              value: _branchHistory,
              onChanged: _busy ? null : (value) {
                setState(() { _branchHistory = value; _historyLoaded = false; });
                _loadHistory();
              },
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_historyLoaded && _history.isEmpty)
              _panel(const Text('No expenses in this scope.')),
            for (final row in _history) ListTile(
              title: Text(row['category']?.toString() ?? 'Expense'),
              subtitle: Text('${row['description'] ?? ''}\n${row['business_date'] ?? row['created_at']} · Cash'),
              trailing: Text(CustomerPresentation.amount(row['amount'],
                currency: ref.watch(authStateProvider).activeBusiness?.currency)),
            ),
            if (!_busy && !_historyLoaded)
              TextButton(onPressed: _loadHistory, child: const Text('Load history')),
            if (_cursor != null)
              TextButton(onPressed: _busy ? null : () => _loadHistory(more: true),
                child: const Text('Load more')),
          ],
        ],
      )),
    );
  }
}
