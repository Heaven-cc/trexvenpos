import 'package:trexven_design_system/trexven_design_system.dart';
import 'customer_presentation.dart';
import 'package:flutter/material.dart';
import 'operations_client.dart';
import 'stock_count_batch.dart';
import 'text_controller_scope.dart';

class InventoryOperationsScreen extends StatefulWidget {
  final OperationsClient api;
  final Future<String?> Function(BuildContext)? scanBarcode;
  const InventoryOperationsScreen({
    super.key,
    required this.api,
    this.scanBarcode,
  });
  @override
  State<InventoryOperationsScreen> createState() =>
      _InventoryOperationsScreenState();
}

class _InventoryOperationsScreenState extends State<InventoryOperationsScreen> {
  late Future<List<List<Map<String, dynamic>>>> data;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = Future.wait([
      widget.api.list('products'),
      widget.api.list('stocktake_sessions'),
      widget.api.list('stock_condition_entries'),
      widget.api.list('inventory_reconciliation_reviews'),
      widget.api.list('supplier_stock_returns'),
    ]);
  }

  Future<Map<String, String>?> fields(String title, List<String> names) async {
    final controls = {for (final n in names) n: TextEditingController()};
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => TextControllerScope(
        controllers: controls.values.toList(),
        child: AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in controls.entries)
                  TrexvenTextField(
                    controller: c.value,
                    maxLines: c.key == 'Barcode counts' ? 6 : 1,
                    decoration: TrexvenInputDecoration(labelText: c.key),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                controls.map((k, v) => MapEntry(k, v.text.trim())),
              ),
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> run(String rpc, Map<String, dynamic> args) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api.call(rpc, {
        'p_request_id': widget.api.requestId(),
        ...args,
      });
      if (mounted)
        setState(() {
          message = 'The action has been confirmed.';
          load();
        });
    } catch (e) {
      if (mounted)
        setState(
          () => message = CustomerPresentation.error(
            e,
            fallback: 'Not confirmed. Please try again.',
          ),
        );
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
    final counts = await widget.api.list(
      'stocktake_counts',
      foreignKey: 'session_id',
      foreignId: s['id'] as String,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          '${s['name']} · ${CustomerPresentation.label(s['status'])}',
        ),
        children: [
          for (final c in counts)
            ListTile(
              title: Text(
                '${products.where((p) => p['id'] == c['product_id']).firstOrNull?['name'] ?? 'Product'}',
              ),
              subtitle: Text(
                'Count ${c['counted'] ?? 'not entered'} · stock at count ${c['expected_at_count'] ?? '—'} · adjustment ${c['applied_delta'] ?? '—'}',
              ),
              onTap: s['status'] != 'open'
                  ? null
                  : () {
                      Navigator.pop(context);
                      count(s, c);
                    },
              onLongPress: s['status'] != 'open'
                  ? null
                  : () {
                      Navigator.pop(context);
                      reassign(s, c);
                    },
            ),
          if (s['status'] == 'open')
            if (widget.scanBarcode != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  scannedCount(s, counts, products);
                },
                child: Text('Scan a product to count'),
              ),
          if (s['status'] == 'open')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                bulkCount(s, counts, products);
              },
              child: Text('Enter counts by barcode'),
            ),
          if (s['status'] == 'open')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                run('submit_trexven_stocktake', {'p_session_id': s['id']});
              },
              child: Text('Submit complete count for review'),
            ),
          if (s['status'] == 'review')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                approve(s);
              },
              child: Text('Approve reconciliation'),
            ),
          if (s['status'] == 'review')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                manage(s, 'reopen');
              },
              child: Text('Reopen for recount'),
            ),
          if (s['status'] == 'open' || s['status'] == 'review')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                manage(s, 'cancel');
              },
              child: Text('Cancel count with reason'),
            ),
        ],
      ),
    );
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

  Future<Map<String, dynamic>?> product(
    List<Map<String, dynamic>> products,
  ) async => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Select product'),
      children: [
        for (final p in products)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, p),
            child: Text(
              '${p['name']} · available ${p['quantity']} ${p['unit']}',
            ),
          ),
      ],
    ),
  );
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

  Color get _blue =>
      Theme.of(context).trexvenColors.brandBlue ??
      Theme.of(context).colorScheme.primary;

  Widget _surface(Widget child, {EdgeInsetsGeometry? padding}) {
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(
          color: theme.trexvenColors.border ?? theme.colorScheme.outlineVariant,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }

  Widget _status(dynamic value) {
    final status = value?.toString() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    switch (status) {
      case 'open':
      case 'dispatched':
        color = _blue;
      case 'review':
      case 'pending':
        color = Theme.of(context).trexvenColors.warning ?? scheme.primary;
      case 'approved':
      case 'completed':
      case 'acknowledged':
      case 'resolved':
        color = Theme.of(context).trexvenColors.success ?? scheme.primary;
      case 'cancelled':
        color = scheme.error;
      default:
        color = scheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(TrexvenRadii.status),
      ),
      child: Text(
        CustomerPresentation.label(value),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _metric(String label, int value, IconData icon) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _blue),
        const SizedBox(height: 10),
        Text('$value', style: TrexvenTypography.title),
        const SizedBox(height: 4),
        Text(
          label,
          style: TrexvenTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(14),
  );

  Widget _summary(List<List<Map<String, dynamic>>> rows) {
    final metrics = <Widget>[
      _metric(
        'Open counts',
        rows[1].where((r) => r['status'] == 'open').length,
        Icons.fact_check_outlined,
      ),
      _metric(
        'Counts in review',
        rows[1].where((r) => r['status'] == 'review').length,
        Icons.rule_outlined,
      ),
      _metric(
        'Pending reconciliation',
        rows[3].where((r) => r['status'] == 'pending').length,
        Icons.sync_problem_outlined,
      ),
      _metric(
        'Returns dispatched',
        rows[4].where((r) => r['status'] == 'dispatched').length,
        Icons.local_shipping_outlined,
      ),
    ];
    // Natural heights let the two-column layout grow with accessibility text.
    return Column(
      children: [
        for (var i = 0; i < metrics.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: metrics[i]),
              const SizedBox(width: 10),
              Expanded(child: metrics[i + 1]),
            ],
          ),
        ],
      ],
    );
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback callback, {
    bool primary = false,
  }) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.field),
        ),
      ),
    );
    return primary
        ? FilledButton.icon(
            style: style,
            onPressed: busy ? null : callback,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            style: style,
            onPressed: busy ? null : callback,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }

  Widget _section({
    required String title,
    required String description,
    required IconData icon,
    required int total,
    required List<Widget> children,
    required String emptyMessage,
  }) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total',
                style: TrexvenTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TrexvenTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                emptyMessage,
                style: TrexvenTypography.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              children[i],
            ],
        ],
      ),
    ),
  );

  Widget _entry({
    required String title,
    required String subtitle,
    required IconData icon,
    dynamic status,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: _blue),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TrexvenTypography.caption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (status != null) ...[const SizedBox(height: 6), _status(status)],
        ],
      ),
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Inventory operations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Refresh inventory operations',
            onPressed: busy ? null : () => setState(load),
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: TrexvenLoading());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 32,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'We could not load inventory operations. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => setState(load),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final rows = snapshot.data!;
            final productNames = {
              for (final p in rows[0])
                p['id']: p['name']?.toString() ?? 'Product',
            };
            return RefreshIndicator(
              onRefresh: () async {
                if (busy) return;
                setState(load);
                try {
                  await data;
                } catch (_) {
                  // The FutureBuilder displays the load error and retry action.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (busy) ...[
                            const LinearProgressIndicator(minHeight: 3),
                            const SizedBox(height: 12),
                          ],
                          if (message != null) ...[
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final pending = await widget.api.journal
                                          .pending();
                                      if (pending == null) return;
                                      if (pending['rpc'] !=
                                          'count_trexven_stock') {
                                        if (mounted)
                                          setState(
                                            () => message =
                                                'Recover the original operation in its checkout screen.',
                                          );
                                        return;
                                      }
                                      setState(() => busy = true);
                                      try {
                                        await widget.api.recoverPending();
                                        if (mounted)
                                          setState(() {
                                            message =
                                                'Original count batch recovered.';
                                            load();
                                          });
                                      } catch (e) {
                                        if (mounted)
                                          setState(
                                            () => message =
                                                CustomerPresentation.error(e),
                                          );
                                      } finally {
                                        if (mounted)
                                          setState(() => busy = false);
                                      }
                                    },
                              child: const Text('Recover original count batch'),
                            ),
                            _surface(
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: _blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        message!,
                                        style: TrexvenTypography.body,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Dismiss message',
                                    onPressed: () =>
                                        setState(() => message = null),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111B35),
                              borderRadius: BorderRadius.circular(
                                TrexvenRadii.card,
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STOCK CONTROL',
                                  style: TextStyle(
                                    color: Color(0xFFB0BED0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Keep every count clear.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Count stock, review discrepancies and manage nonsellable items.',
                                  style: TextStyle(
                                    color: Color(0xFFB0BED0),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _summary(rows),
                          const SizedBox(height: 16),
                          _surface(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inventory actions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _action(
                                      'Start stocktake',
                                      Icons.add_rounded,
                                      start,
                                      primary: true,
                                    ),
                                    _action(
                                      'Damaged, expired or lost',
                                      Icons.inventory_2_outlined,
                                      () => classify(rows[0]),
                                    ),
                                    _action(
                                      'Restore stock',
                                      Icons.restore_rounded,
                                      () => resolve(rows[0], 'restore'),
                                    ),
                                    _action(
                                      'Write off stock',
                                      Icons.remove_circle_outline,
                                      () => resolve(rows[0], 'writeoff'),
                                    ),
                                    _action(
                                      'Supplier return',
                                      Icons.local_shipping_outlined,
                                      () => resolve(rows[0], 'supplier'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _section(
                            title: 'Count sessions',
                            description:
                                'Open a session to count, assign or review stock.',
                            icon: Icons.fact_check_outlined,
                            total: rows[1].length,
                            emptyMessage:
                                'No stocktake sessions yet. Start a count above.',
                            children: [
                              for (final s in rows[1])
                                _entry(
                                  title: '${s['name']}',
                                  subtitle:
                                      'View counts and available session actions',
                                  status: s['status'],
                                  icon: Icons.checklist_rounded,
                                  onTap: busy
                                      ? null
                                      : () => session(s, rows[0]),
                                ),
                            ],
                          ),
                          _section(
                            title: 'Nonsellable stock ledger',
                            description:
                                'Condition changes, quantities and recorded reasons.',
                            icon: Icons.inventory_2_outlined,
                            total: rows[2].length,
                            emptyMessage: 'No nonsellable stock entries yet.',
                            children: [
                              for (final e in rows[2])
                                _entry(
                                  title:
                                      '${productNames[e['product_id']] ?? 'Product'} · ${e['quantity']}',
                                  subtitle:
                                      '${CustomerPresentation.label(e['kind'])} · ${e['reason']}',
                                  status: e['condition'],
                                  icon: Icons.inventory_2_outlined,
                                ),
                            ],
                          ),
                          _section(
                            title: 'Late offline reconciliation',
                            description:
                                'Review late movements while keeping closed counts unchanged.',
                            icon: Icons.sync_problem_outlined,
                            total: rows[3].length,
                            emptyMessage:
                                'No late offline movements to review.',
                            children: [
                              for (final r in rows[3])
                                _entry(
                                  title: 'Late cash sale · ${r['quantity']}',
                                  subtitle: '${r['reason'] ?? ''}',
                                  status: r['status'],
                                  icon: Icons.receipt_long_outlined,
                                  onTap: busy || r['status'] != 'pending'
                                      ? null
                                      : () => review(r),
                                ),
                            ],
                          ),
                          _section(
                            title: 'Supplier returns',
                            description:
                                'Track dispatched stock and supplier acknowledgments.',
                            icon: Icons.local_shipping_outlined,
                            total: rows[4].length,
                            emptyMessage: 'No supplier returns recorded yet.',
                            children: [
                              for (final r in rows[4])
                                _entry(
                                  title:
                                      '${r['supplier_name']} · ${r['quantity']}',
                                  subtitle: r['status'] == 'dispatched'
                                      ? 'Open to record supplier acknowledgment'
                                      : 'Supplier return record',
                                  status: r['status'],
                                  icon: Icons.local_shipping_outlined,
                                  onTap: busy || r['status'] != 'dispatched'
                                      ? null
                                      : () => supplier(r),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.store_outlined,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Branch transfers are not available yet.',
                                  style: TrexvenTypography.caption.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
