import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';

/// POS operational requests only. Sales and receipts belong in Sales History.
class PosOperationHistoryScreen extends ConsumerStatefulWidget {
  const PosOperationHistoryScreen({super.key});

  @override
  ConsumerState<PosOperationHistoryScreen> createState() =>
      _PosOperationHistoryScreenState();
}

enum _HistoryPeriod { all, today, yesterday, sevenDays }
enum _HistoryCategory { all, inventory, expenses, returns, stocktaking, other }

class _PosOperationHistoryScreenState
    extends ConsumerState<PosOperationHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? pending;
  bool busy = false, more = true;
  String? message;
  String _query = '';
  _HistoryPeriod _period = _HistoryPeriod.all;
  _HistoryCategory _category = _HistoryCategory.all;
  late final String user, business;
  late final String? branch;
  late final OperationsClient api;

  bool get current =>
      mounted &&
      ref.read(authStateProvider).employee?.userId == user &&
      ref.read(authStateProvider).activeBusiness?.id == business &&
      !ref.read(authStateProvider).offlineCashOnly &&
      ref.read(branchContextProvider)?.id == branch;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider);
    user = auth.employee?.userId ?? '';
    business = auth.activeBusiness?.id ?? '';
    branch = ref.read(branchContextProvider)?.id;
    api = OperationsClient.pos(ref.read(supabaseProvider), business);
    Future.microtask(() => load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final retained = await api.journal.pending();
      final result = await api.client.rpc('get_pos_operation_history', params: {
        'p_business_id': business,
        'p_branch_id': branch,
        'p_offset': append ? rows.length : 0,
      }).timeout(const Duration(seconds: 20));
      if (!current) return;
      final page = (result as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      setState(() {
        rows = append ? [...rows, ...page] : page;
        more = page.length == 100;
        pending = retained != null &&
                retained['user'] == user &&
                retained['business'] == business
            ? retained
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Unable to verify operational history. Connect and retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recover() async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    String notice;
    try {
      await api.recoverPending();
      notice = 'Original operation confirmed. History refreshed.';
    } catch (_) {
      notice = 'Operation retained. Recover the original request when '
          'access and connection are available; do not repeat a money movement.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!current) return;
    await load();
    if (mounted) setState(() => message = notice);
  }

  static _HistoryCategory _categoryOf(Object? raw) {
    final operation = (raw?.toString() ?? '').toLowerCase();
    if (operation.contains('stocktake') ||
        operation.contains('reconcil') ||
        operation.contains('count_adjustment')) {
      return _HistoryCategory.stocktaking;
    }
    if (operation.contains('return') || operation.contains('refund') ||
        operation.contains('credit_approval') || operation.contains('credit')) {
      return _HistoryCategory.returns;
    }
    if (operation.contains('expense') || operation.contains('cash_out') ||
        operation.contains('cash_in') || operation.contains('cash_shift')) {
      return _HistoryCategory.expenses;
    }
    if (operation.contains('inventory') || operation.contains('stock') ||
        operation.contains('product') || operation.contains('transfer')) {
      return _HistoryCategory.inventory;
    }
    return _HistoryCategory.other;
  }

  static IconData _iconOf(_HistoryCategory category) => switch (category) {
        _HistoryCategory.inventory => Icons.inventory_2_outlined,
        _HistoryCategory.expenses => Icons.payments_outlined,
        _HistoryCategory.returns => Icons.assignment_return_outlined,
        _HistoryCategory.stocktaking => Icons.fact_check_outlined,
        _ => Icons.check_circle_outline,
      };

  static String _labelOf(_HistoryCategory category) => switch (category) {
        _HistoryCategory.all => 'All',
        _HistoryCategory.inventory => 'Inventory',
        _HistoryCategory.expenses => 'Expenses',
        _HistoryCategory.returns => 'Returns & credit',
        _HistoryCategory.stocktaking => 'Stocktaking',
        _HistoryCategory.other => 'Other',
      };

  static DateTime? _dateOf(Map<String, dynamic> row) =>
      DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _inPeriod(Map<String, dynamic> row) {
    if (_period == _HistoryPeriod.all) return true;
    final date = _dateOf(row);
    if (date == null) return false;
    final today = _dayOf(DateTime.now());
    final day = _dayOf(date);
    return switch (_period) {
      _HistoryPeriod.all => true,
      _HistoryPeriod.today => day == today,
      _HistoryPeriod.yesterday => day == today.subtract(const Duration(days: 1)),
      _HistoryPeriod.sevenDays =>
        !day.isBefore(today.subtract(const Duration(days: 6))) &&
        !day.isAfter(today),
    };
  }

  List<Map<String, dynamic>> get _visible => rows.where((row) {
        if (_category != _HistoryCategory.all &&
            _categoryOf(row['operation']) != _category) return false;
        if (!_inPeriod(row)) return false;
        if (_query.trim().isEmpty) return true;
        final haystack = '${CustomerPresentation.label(row['operation'])} '
                '${row['request_id'] ?? ''}'
            .toLowerCase();
        return haystack.contains(_query.trim().toLowerCase());
      }).toList();

  void _showDetails(Map<String, dynamic> row) {
    if (!current) return;
    final scheme = Theme.of(context).colorScheme;
    final category = _categoryOf(row['operation']);
    final date = CustomerPresentation.date(row['created_at'], includeTime: true);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _operationIcon(category),
                  const SizedBox(width: TrexvenSpacing.labelGap),
                  Expanded(child: Text(
                    CustomerPresentation.label(row['operation']),
                    style: Theme.of(sheetContext).textTheme.titleLarge)),
                ]),
                const SizedBox(height: TrexvenSpacing.fieldGap),
                _detailField('Status', CustomerPresentation.label(
                  row['status'] ?? 'confirmed')),
                _detailField('Recorded', date),
                _detailField('Operation type', _labelOf(category)),
                _detailField('Branch', ref.read(branchContextProvider)?.name ??
                    ref.read(authStateProvider).activeBusiness?.name ??
                    'Current business'),
                _detailField('Request ID',
                    row['request_id']?.toString() ?? 'Not available'),
                const SizedBox(height: TrexvenSpacing.fieldGap),
                Text('This is a confirmed operational request.',
                  style: Theme.of(sheetContext).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: TrexvenSpacing.fieldGap),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Done'),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailField(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: TrexvenSpacing.labelGap),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label,
            style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: TrexvenSpacing.fieldGap),
          Flexible(child: SelectableText(value, textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );

  Widget _operationIcon(_HistoryCategory category) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(TrexvenRadii.status),
      ),
      child: Icon(_iconOf(category), color: scheme.primary, size: 21),
    );
  }

  Widget _recordCard(Map<String, dynamic> row) {
    final scheme = Theme.of(context).colorScheme;
    final category = _categoryOf(row['operation']);
    final when = CustomerPresentation.date(row['created_at'], includeTime: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: TrexvenSpacing.labelGap),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          onTap: () => _showDetails(row),
          child: Container(
            constraints: const BoxConstraints(minHeight: TrexvenSpacing.quantityTarget),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Row(children: [
              _operationIcon(category),
              const SizedBox(width: TrexvenSpacing.labelGap),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(CustomerPresentation.label(row['operation']),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(when, style: Theme.of(context).textTheme.bodySmall),
                ],
              )),
              const SizedBox(width: TrexvenSpacing.labelGap),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline,
                  color: Theme.of(context).trexvenColors.success, size: 20),
                const SizedBox(height: 4),
                Text('Confirmed', style: Theme.of(context)
                    .textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).trexvenColors.success)),
              ]),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _recoveryPanel() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RECOVERY AVAILABLE', style: Theme.of(context)
          .textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: TrexvenSpacing.labelGap),
        Row(children: [
          Icon(Icons.restore_rounded, color: scheme.onTertiaryContainer),
          const SizedBox(width: TrexvenSpacing.labelGap),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Retained operation', style: Theme.of(context)
                .textTheme.labelLarge?.copyWith(color: scheme.onTertiaryContainer)),
              Text(CustomerPresentation.label(pending!['rpc']),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer)),
            ])),
          const SizedBox(width: TrexvenSpacing.labelGap),
          OutlinedButton(onPressed: busy ? null : recover,
            child: const Text('Recover')),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchName = ref.watch(branchContextProvider)?.name ??
        ref.watch(authStateProvider).activeBusiness?.name ?? 'Current business';
    final visible = _visible;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Operational History'), actions: [
        IconButton(
          tooltip: 'Refresh operational history',
          onPressed: busy ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
      ]),
      body: !current
          ? const Center(child: Text(
              'Reopen history in your authorized branch.'))
          : ListView(
              padding: TrexvenSpacing.pagePadding,
              children: [
                Row(children: [
                  Icon(Icons.storefront_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: TrexvenSpacing.labelGap),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACTIVE BRANCH', style: Theme.of(context)
                        .textTheme.labelSmall),
                      Text(branchName, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge),
                    ],
                  )),
                  DropdownButtonHideUnderline(child: DropdownButton<_HistoryPeriod>(
                    value: _period,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: _HistoryPeriod.all,
                        child: Text('All dates')),
                      DropdownMenuItem(value: _HistoryPeriod.today,
                        child: Text('Today')),
                      DropdownMenuItem(value: _HistoryPeriod.yesterday,
                        child: Text('Yesterday')),
                      DropdownMenuItem(value: _HistoryPeriod.sevenDays,
                        child: Text('Last 7 days')),
                    ],
                    onChanged: (value) => setState(
                      () => _period = value ?? _HistoryPeriod.all),
                  )),
                ]),
                const SizedBox(height: TrexvenSpacing.fieldGap),
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search operation or request ID',
                    suffixIcon: _query.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: TrexvenSpacing.labelGap),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final category in _HistoryCategory.values) ...[
                      ChoiceChip(
                        label: Text(_labelOf(category)),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                      const SizedBox(width: TrexvenSpacing.labelGap),
                    ],
                  ]),
                ),
                if (message != null) ...[
                  const SizedBox(height: TrexvenSpacing.labelGap),
                  Text(message!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (busy) const LinearProgressIndicator(),
                if (pending != null) ...[
                  const SizedBox(height: TrexvenSpacing.fieldGap),
                  _recoveryPanel(),
                ],
                const SizedBox(height: TrexvenSpacing.fieldGap),
                Row(children: [
                  Expanded(child: Text('Activity log',
                    style: Theme.of(context).textTheme.titleMedium)),
                  Text('${visible.length} loaded record${visible.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: TrexvenSpacing.labelGap),
                if (!busy && visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: TrexvenSpacing.sectionGap),
                    child: Text(
                      rows.isEmpty
                        ? 'No confirmed operations in this scope.'
                        : 'No matching operational records. Change your filters or load more.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ..._groupedHistory(visible),
                if (more) Padding(
                  padding: const EdgeInsets.only(top: TrexvenSpacing.labelGap),
                  child: Center(child: TextButton(
                    onPressed: busy ? null : () => load(append: true),
                    child: const Text('Load more'),
                  )),
                ),
              ],
            ),
    );
  }

  List<Widget> _groupedHistory(List<Map<String, dynamic>> visible) {
    final result = <Widget>[];
    String? previousDay;
    final today = _dayOf(DateTime.now());
    for (final row in visible) {
      final date = _dateOf(row);
      final day = date == null ? 'Unknown date' :
          _dayOf(date) == today ? 'Today' :
          _dayOf(date) == today.subtract(const Duration(days: 1))
              ? 'Yesterday' : CustomerPresentation.date(date);
      if (day != previousDay) {
        result.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(day.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ));
        previousDay = day;
      }
      result.add(_recordCard(row));
    }
    return result;
  }
}
