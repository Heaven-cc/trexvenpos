part of 'inventory_operations_screen.dart';

/// Detail view reads the latest session and versions before every edit.
/// Count entry saves evidence only; approval remains a separate server RPC.
class _InventorySessionPage extends StatefulWidget {
  final _InventoryOperationsScreenState operations;
  final Map<String, dynamic> initialSession;
  final List<Map<String, dynamic>> products;
  const _InventorySessionPage({
    required this.operations, required this.initialSession, required this.products,
  });

  @override
  State<_InventorySessionPage> createState() => _InventorySessionPageState();
}

class _InventorySessionPageState extends State<_InventorySessionPage>
    with WidgetsBindingObserver {
  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _data;
  final _search = TextEditingController();
  Timer? _timer;
  bool _working = false;
  String _query = '';
  String _filter = 'all';
  String? _notice;
  _InventoryOperationsScreenState get ops => widget.operations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _data = _read();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ModalRoute.of(context)?.isCurrent == true) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) _refresh();
  }

  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _read() async {
    if (!ops._current) throw StateError('Access changed. Reopen inventory.');
    final session = await ops.widget.api.client.from('stocktake_sessions')
        .select().eq('business_id', ops.widget.api.businessId)
        .eq('id', widget.initialSession['id']).single()
        .timeout(const Duration(seconds: 20));
    if (ops._branchId != null && session['branch_id'] != ops._branchId) {
      throw StateError('This session is outside your selected branch.');
    }
    final counts = await ops.widget.api.list('stocktake_counts',
      foreignKey: 'session_id', foreignId: session['id'] as String)
      .timeout(const Duration(seconds: 20));
    if (!ops._current) throw StateError('Access changed. Reopen inventory.');
    return (Map<String, dynamic>.from(session), counts);
  }

  Future<void> _refresh() async {
    if (!mounted || _working || !ops._current) return;
    _working = true;
    setState(() => _data = _read());
    try { await _data; } catch (_) {
      // The FutureBuilder presents a retry action.
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_working || !ops._current) return;
    setState(() { _working = true; _notice = null; });
    try {
      ops.message = null;
      await action();
      if (mounted && ops._current) {
        setState(() { _notice = ops.message; _data = _read(); });
      }
    } catch (error) {
      if (mounted) setState(() => _notice = CustomerPresentation.error(error,
        fallback: 'Refresh the session before trying again.'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submit(Map<String, dynamic> session) async {
    final confirm = await showDialog<bool>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit counts for review?'),
        content: const Text('Your saved quantities will be sent for review. Stock is adjusted only after authorized approval.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep counting')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit for review')),
        ],
      ),
    );
    if (confirm == true && mounted && ops._current) {
      await ops.run('submit_trexven_stocktake', {'p_session_id': session['id']});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocktake'),
        actions: [
          IconButton(tooltip: 'Refresh saved counts',
            onPressed: _working ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(top: false,
        child: FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: TrexvenLoading());
            }
            if (!ops._current || snapshot.hasError || !snapshot.hasData) {
              return Center(child: Padding(padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Unable to load current counts. Refresh or reopen inventory.',
                    textAlign: TextAlign.center),
                  TextButton(onPressed: _working ? null : _refresh, child: const Text('Try again')),
                ])));
            }
            final (session, counts) = snapshot.data!;
            final products = {for (final product in widget.products) product['id']: product};
            final saved = counts.where((count) => count['counted'] != null).length;
            final differences = counts.where((count) =>
                count['counted'] != null && count['expected_at_count'] != null &&
                count['counted'] != count['expected_at_count']).length;
            final canCount = session['status'] == 'open' &&
                ops._sessionWritesSupported(session) && ops._can('stocktake');
            final canReview = ops._sessionWritesSupported(session) &&
                ops._can('approve_stocktake', sensitive: true);
            final showExpected = ops._can('stocktake') || ops._can('approve_stocktake', sensitive: true);
            final visible = counts.where((count) {
              final product = products[count['product_id']];
              final search = [product?['name'], product?['barcode'], product?['unit']]
                  .join(' ').toLowerCase().contains(_query.toLowerCase());
              final matches = switch (_filter) {
                'remaining' => count['counted'] == null,
                'differences' => count['counted'] != null &&
                    count['expected_at_count'] != null &&
                    count['counted'] != count['expected_at_count'],
                _ => true,
              };
              return search && matches;
            }).toList();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_working) const LinearProgressIndicator(minHeight: 3),
                    if (_notice != null) ...[
                      ops._notice(_notice!), const SizedBox(height: 12),
                    ],
                    ops._surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${session['name']}',
                        style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 20), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ops._status(session['status']),
                      const SizedBox(height: 16),
                      Text('$saved of ${counts.length} products counted',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: TrexvenPresentation.spacing(context, 10)),
                      LinearProgressIndicator(value: counts.isEmpty ? 0 : saved / counts.length,
                        minHeight: 5, borderRadius: BorderRadius.circular(8)),
                      SizedBox(height: TrexvenPresentation.spacing(context, 10)),
                      Text(showExpected ? '$differences stock differences' : 'Saved progress is available across your authorized devices.',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    ])),
                    const SizedBox(height: 12),
                    ops._notice(!ops._sessionWritesSupported(session)
                        ? 'This session is available to view. Select its active branch from Inventory to count or review it.'
                        : 'Counts save progress without changing stock. Authorized approval applies the physical difference and retains later movements.'),
                    if (ops._pendingRpc != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _working ? null : () => _act(ops._recover),
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Recover original operation')),
                    ],
                    if (_InventoryOperationsScreenState._inventoryRpcs.contains(ops._pendingRpc))
                      TextButton(
                        onPressed: _working ? null : () => _act(ops._cancelPending),
                        child: const Text('Cancel uncommitted request')),
                    if (canCount) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (ops.widget.scanBarcode != null)
                          OutlinedButton.icon(
                            onPressed: _working || ops._pendingRpc != null ? null :
                                () => _act(() => ops.scannedCount(session, counts, widget.products)),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Scan product')),
                        OutlinedButton.icon(
                          onPressed: _working || ops._pendingRpc != null ? null :
                              () => _act(() => ops.bulkCount(session, counts, widget.products)),
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: const Text('Barcode batch')),
                      ]),
                    ],
                    SizedBox(height: TrexvenPresentation.spacing(context, 18)),
                    TrexvenTextField(
                      controller: _search, variant: TrexvenFieldVariant.search,
                      onChanged: (value) => setState(() => _query = value.trim()),
                      decoration: const TrexvenInputDecoration(hintText: 'Search product or barcode',
                        prefixIcon: Icon(Icons.search_rounded)),
                    ),
                    Wrap(spacing: 8, children: [
                      for (final filter in [
                        ('all', 'All'), ('remaining', 'Not counted'),
                        if (showExpected) ('differences', 'Differences'),
                      ])
                        ChoiceChip(label: Text(filter.$2), selected: _filter == filter.$1,
                          onSelected: (_) => setState(() => _filter = filter.$1)),
                    ]),
                    SizedBox(height: TrexvenPresentation.spacing(context, 10)),
                    ops._surface(visible.isEmpty
                        ? ops._empty('No matching products', 'Adjust your search or count filter.', Icons.search_off_rounded)
                        : Column(children: [
                            for (var i = 0; i < visible.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _countRow(session, visible[i], products[visible[i]['product_id']],
                                  canCount, canReview, showExpected),
                            ],
                          ])),
                    if (session['reason'] != null) ...[
                      const SizedBox(height: 12),
                      ops._notice('Review note: ${session['reason']}'),
                    ],
                    SizedBox(height: TrexvenPresentation.spacing(context, 18)),
                    if (canCount)
                      FilledButton.icon(
                        onPressed: _working || ops._pendingRpc != null || saved != counts.length
                            ? null : () => _act(() => _submit(session)),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Submit for review')),
                    if (canReview && session['status'] == 'review') ...[
                      FilledButton.icon(
                        onPressed: _working || ops._pendingRpc != null ? null : () => _act(() => ops.approve(session)),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Approve reconciliation')),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _working || ops._pendingRpc != null ? null : () => _act(() => ops.manage(session, 'reopen')),
                        child: const Text('Reopen for recount')),
                    ],
                    if (canReview && (session['status'] == 'open' || session['status'] == 'review'))
                      TextButton(
                        onPressed: _working || ops._pendingRpc != null ? null : () => _act(() => ops.manage(session, 'cancel')),
                        child: const Text('Cancel stocktake')),
                  ]),
                ))],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _countRow(Map<String, dynamic> session, Map<String, dynamic> count,
      Map<String, dynamic>? product, bool canCount, bool canReview, bool showExpected) {
    final assignedElsewhere = count['counted_by'] != null && count['counted_by'] != ops._user;
    final counted = count['counted'];
    final expected = count['expected_at_count'];
    final delta = counted is num && expected is num ? counted - expected : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Text('${product?['name'] ?? 'Product'}',
        style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 14), fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: EdgeInsets.only(top: TrexvenPresentation.spacing(context, 5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(counted == null ? 'Not counted' : 'Counted $counted ${product?['unit'] ?? ''}'),
          if (showExpected && expected != null)
            Text('Expected $expected · Difference ${delta ?? '—'}'),
          if (showExpected && count['applied_delta'] != null)
            Text('Applied ${count['applied_delta']} · Stock after ${count['stock_after']}'),
          if (assignedElsewhere) const Text('Assigned to another counter'),
        ]),
      ),
      onTap: !canCount || _working || assignedElsewhere || ops._pendingRpc != null ? null :
          () => _act(() => ops.count(session, count)),
      trailing: canReview && session['status'] == 'open'
          ? IconButton(tooltip: 'Reassign count',
              onPressed: _working || ops._pendingRpc != null ? null : () => _act(() => ops.reassign(session, count)),
              icon: const Icon(Icons.person_outline_rounded))
          : canCount && !assignedElsewhere ? const Icon(Icons.edit_outlined, size: 19) : null,
    );
  }
}

class _InventoryProductPicker extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  const _InventoryProductPicker({required this.products});
  @override
  State<_InventoryProductPicker> createState() => _InventoryProductPickerState();
}

class _InventoryProductPickerState extends State<_InventoryProductPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final products = widget.products.where((product) =>
        [product['name'], product['barcode']].join(' ').toLowerCase().contains(_query)).toList();
    if (TrexvenPresentation.isPos(context)) {
      return SafeArea(child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: LayoutBuilder(builder: (context, box) => SizedBox(
          height: (box.hasBoundedHeight ? box.maxHeight : MediaQuery.sizeOf(context).height)
              .clamp(0, MediaQuery.sizeOf(context).height * .8).toDouble(),
          child: CustomScrollView(slivers: [
            SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverToBoxAdapter(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Select product', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TrexvenTextField(variant: TrexvenFieldVariant.search,
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: const TrexvenInputDecoration(hintText: 'Search name or barcode', prefixIcon: Icon(Icons.search_rounded))),
              ]))),
            if (products.isEmpty) const SliverFillRemaining(hasScrollBody: false,
              child: Center(child: TrexvenEmptyState(title: 'No matching products')))
            else SliverList.builder(itemCount: products.length, itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${product['name']}'),
                subtitle: Text('In stock ${product['quantity']} ${product['unit']}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, product));
            }),
          ])))));
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Select product', style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 18), fontWeight: FontWeight.w700)),
            SizedBox(height: TrexvenPresentation.spacing(context, 14)),
            TrexvenTextField(
              variant: TrexvenFieldVariant.search,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: const TrexvenInputDecoration(hintText: 'Search name or barcode',
                prefixIcon: Icon(Icons.search_rounded)),
            ),
            Expanded(child: products.isEmpty
              ? const Center(child: Text('No matching products.'))
              : ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text('${product['name']}'),
                      subtitle: Text('In stock ${product['quantity']} ${product['unit']}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, product),
                    );
                  },
                )),
          ]),
        ),
      ),
    );
  }
}
