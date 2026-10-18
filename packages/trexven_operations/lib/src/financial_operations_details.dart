part of 'financial_operations_screen.dart';

extension _FinancialDetails on _FinancialOperationsScreenState {
  Future<void> _openCustomer(String customerKey) async {
    var detailsTab = 0;
    String? selectedSale;
    ++_childRoutes;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (routeContext) => ValueListenableBuilder<int>(
            valueListenable: _revision,
            builder: (context, _, child) => StatefulBuilder(
              builder: (context, update) {
                if (!mounted) return const SizedBox.shrink();
                final customer = _customers(
                  _accounts.rows,
                ).where((c) => c.key == customerKey).firstOrNull;
                if (!_current || _accounts.error != null || customer == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Customer Credit')),
                    body: _empty(
                      'Credit information unavailable',
                      'Verify your account or refresh the original credit page.',
                    ),
                  );
                }
                selectedSale ??= customer.accounts.first['sale_id'] as String;
                final account =
                    customer.accounts
                        .where((a) => a['sale_id'] == selectedSale)
                        .firstOrNull ??
                    customer.accounts.first;
                final entries =
                    _entries.rows
                        .where((e) => e['sale_id'] == account['sale_id'])
                        .toList()
                      ..sort(
                        (a, b) => '${b['created_at']}'.compareTo(
                          '${a['created_at']}',
                        ),
                      );
                final repayments = -entries
                    .where(
                      (e) => [
                        'repayment',
                        'repayment_reversal',
                      ].contains(e['kind']),
                    )
                    .fold<int>(0, (sum, e) => sum + _cents(e['amount']));
                final adjustments = -entries
                    .where((e) => e['kind'] == 'return')
                    .fold<int>(0, (sum, e) => sum + _cents(e['amount']));
                final original = _cents(account['original_amount']);
                final outstanding = _cents(account['outstanding']);
                final progress = original == 0
                    ? 1.0
                    : ((original - outstanding) / original).clamp(0.0, 1.0);
                final overdue =
                    outstanding > 0 &&
                    _day != null &&
                    '${account['due_date']}'.compareTo(
                          '${_day!['local_date']}',
                        ) <
                        0;
                final status = outstanding == 0
                    ? 'Settled'
                    : overdue
                    ? 'Overdue credit'
                    : 'Active credit';
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Customer Credit'),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh customer credit',
                        onPressed: _busy || _preparing
                            ? null
                            : () => unawaited(_reload(background: true)),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  body: RefreshIndicator(
                    onRefresh: () => _reload(background: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: TrexvenSpacing.pagePadding,
                      children: [
                        _notice(),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.person_outline,
                                size: 30,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: TrexvenPresentation.typography(context, TrexvenTypography.title),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(customer.contact),
                                  const SizedBox(height: 8),
                                  _CreditBadge(status, active: outstanding > 0),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (customer.accounts.length > 1) ...[
                          Text(
                            'Customer total outstanding ${_cash(customer.outstanding, _currency)}',
                          ),
                          const SizedBox(height: 12),
                          TrexvenDropdown<String>(
                            value: account['sale_id'] as String,
                            decoration: const TrexvenInputDecoration(
                              labelText: 'Select original credit sale',
                            ),
                            items: [
                              for (final row in customer.accounts)
                                DropdownMenuItem(
                                  value: row['sale_id'] as String,
                                  child: Text(
                                    '${CustomerPresentation.date(row['created_at'])} · ${_money(row['outstanding'], _currency)} outstanding',
                                  ),
                                ),
                            ],
                            onChanged: _busy || _preparing
                                ? null
                                : (id) => update(() => selectedSale = id),
                          ),
                        ],
                        _CreditCard(
                          highlighted: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Outstanding balance'),
                              SizedBox(height: TrexvenPresentation.spacing(context, 14)),
                              Text(
                                _cash(outstanding, _currency),
                                style: TrexvenPresentation.typography(context, TrexvenTypography.display),
                              ),
                              const SizedBox(height: 20),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  TrexvenRadii.progress,
                                ),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 7,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _info(
                                'Original credit',
                                _cash(original, _currency),
                              ),
                              _info(
                                'Amount repaid',
                                _entries.error == null
                                    ? _cash(repayments, _currency)
                                    : 'Unavailable',
                              ),
                              if (adjustments != 0)
                                _info(
                                  'Return debt adjustments',
                                  _cash(adjustments, _currency),
                                ),
                              const Divider(),
                              _info(
                                'Payment due',
                                CustomerPresentation.date(account['due_date']),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (outstanding > 0 && _can('record_credit_repayment'))
                          SizedBox(
                            width: double.infinity,
                            child: _button(
                              'Record repayment',
                              () => unawaited(_repay(account)),
                              primary: true,
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        const SizedBox(height: 20),
                        _tabs(
                          const ['Credit details', 'Payment history'],
                          detailsTab,
                          (i) => update(() => detailsTab = i),
                        ),
                        if (detailsTab == 0) ...[
                          _heading(
                            'Credit information',
                            count: outstanding == 0 ? 'Settled' : 'Recorded',
                          ),
                          _CreditCard(
                            child: Column(
                              children: [
                                _info(
                                  'Credit amount',
                                  _cash(original, _currency),
                                ),
                                const Divider(),
                                _info(
                                  'Due date',
                                  CustomerPresentation.date(
                                    account['due_date'],
                                  ),
                                ),
                                const Divider(),
                                _info(
                                  'Created',
                                  CustomerPresentation.date(
                                    account['created_at'],
                                    includeTime: true,
                                  ),
                                ),
                                const Divider(),
                                _info(
                                  'Approval',
                                  account['approval_id'] == null
                                      ? 'Legacy credit record'
                                      : 'Approved transaction',
                                ),
                                const Divider(),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Related sale'),
                                  subtitle: Text(account['sale_id'] as String),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _busy || _preparing
                                      ? null
                                      : () => unawaited(
                                          _prepare(
                                            () => _receipt(
                                              account['sale_id'] as String,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _heading(
                            'Payment history',
                            count: '${entries.length} entries',
                          ),
                          if (_entries.error != null)
                            _error('Payment history unavailable')
                          else if (entries.isEmpty)
                            _empty(
                              'No ledger entries available',
                              'No repayment is assumed when history is unavailable.',
                            )
                          else
                            for (final entry in entries)
                              Padding(
                                padding: EdgeInsets.only(bottom: TrexvenPresentation.spacing(context, 10)),
                                child: _CreditCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _entryLabel(entry['kind']),
                                        style: TrexvenPresentation.typography(context, TrexvenTypography.label),
                                      ),
                                      SizedBox(height: TrexvenPresentation.spacing(context, 6)),
                                      Text(
                                        _money(entry['amount'], _currency),
                                        style: TrexvenPresentation.typography(context, TrexvenTypography.section),
                                      ),
                                      Text(
                                        CustomerPresentation.date(
                                          entry['created_at'],
                                          includeTime: true,
                                        ),
                                      ),
                                      if (entry['method'] != null)
                                        Text(
                                          CustomerPresentation.label(
                                            entry['method'],
                                          ),
                                        ),
                                      if ((entry['reason'] ??
                                              entry['evidence']) !=
                                          null)
                                        Text(
                                          '${entry['reason'] ?? entry['evidence']}',
                                        ),
                                      if (widget.owner &&
                                          entry['kind'] == 'repayment') ...[
                                        const SizedBox(height: 8),
                                        if (entries.any(
                                          (r) =>
                                              r['kind'] ==
                                                  'repayment_reversal' &&
                                              r['reference_id'] == entry['id'],
                                        ))
                                          const _CreditBadge('Reversed')
                                        else
                                          _button(
                                            'Reverse repayment',
                                            () => unawaited(_reverse(entry)),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          const SizedBox(height: 8),
                          const Text(
                            'Negative ledger entries reduce debt. A return adjustment is not a cash repayment. Initial sale payments appear on the receipt.',
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } finally {
      --_childRoutes;
    }
  }

  String _entryLabel(Object? kind) => switch (kind) {
    'sale' => 'Credit issued',
    'repayment' => 'Repayment received',
    'repayment_reversal' => 'Repayment reversed',
    'return' => 'Return debt adjustment',
    _ => CustomerPresentation.label(kind),
  };

  Future<void> _openLimits() async {
    if (!widget.owner || !_current) return;
    var search = '';
    var owingOnly = false;
    ++_childRoutes;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (routeContext) => ValueListenableBuilder<int>(
            valueListenable: _revision,
            builder: (context, _, child) => StatefulBuilder(
              builder: (context, update) {
                if (!mounted) return const SizedBox.shrink();
                if (!_current) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Credit Limits')),
                    body: _empty(
                      'Owner access required',
                      'Verify the original owner account and business.',
                    ),
                  );
                }
                final customers = _customers(_accounts.rows);
                final businessLimit = _limits.rows
                    .where((row) => row['branch_id'] == null)
                    .firstOrNull;
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Credit Limits'),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh credit limits',
                        onPressed: _busy || _preparing
                            ? null
                            : () => unawaited(_reload(background: true)),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  body: RefreshIndicator(
                    onRefresh: () => _reload(background: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: TrexvenSpacing.pagePadding,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: const _CreditBadge('Owner controls'),
                        ),
                        const SizedBox(height: 16),
                        _notice(),
                        _CreditMetric(
                          'Total outstanding credit',
                          _totals == null
                              ? 'Unavailable'
                              : _money(_totals!['receivables'], _currency),
                          _accounts.error == null
                              ? '${customers.where((c) => c.outstanding > 0).length} customers owing'
                              : 'Customer count unavailable',
                        ),
                        _heading('Business credit policy'),
                        if (_limits.error != null)
                          _error('Credit limits unavailable')
                        else
                          _CreditCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Business exposure limit',
                                  style: TrexvenPresentation.typography(context, TrexvenTypography.section),
                                ),
                                SizedBox(height: TrexvenPresentation.spacing(context, 10)),
                                Text(
                                  businessLimit == null
                                      ? 'Not configured'
                                      : _money(
                                          businessLimit['amount'],
                                          _currency,
                                        ),
                                  style: TrexvenPresentation.typography(context, TrexvenTypography.title),
                                ),
                                SizedBox(height: TrexvenPresentation.spacing(context, 10)),
                                const Text(
                                  'The maximum outstanding credit across all customers. This does not assign an individual customer allowance.',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: _button(
                                    'Save business limit',
                                    () => unawaited(
                                      _setLimit(limit: businessLimit),
                                    ),
                                    primary: true,
                                    icon: Icons.tune,
                                  ),
                                ),
                                const Divider(height: 28),
                                const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Credit approval required'),
                                  subtitle: Text(
                                    'Every credit sale requires approval for its exact saved transaction.',
                                  ),
                                  trailing: Icon(Icons.check_circle_outline),
                                ),
                                const Divider(),
                                const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Over-limit exceptions'),
                                  subtitle: Text(
                                    'Only an owner may approve a specific sale with a recorded exception reason.',
                                  ),
                                  trailing: Icon(Icons.shield_outlined),
                                ),
                              ],
                            ),
                          ),
                        for (final limit in _limits.rows.where(
                          (row) => row['branch_id'] != null,
                        )) ...[
                          _heading('Branch exposure limit'),
                          _CreditCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Branch ${limit['branch_id']}'),
                                _info(
                                  'Maximum outstanding',
                                  _money(limit['amount'], _currency),
                                ),
                                _button(
                                  'Edit branch limit',
                                  () => unawaited(_setLimit(limit: limit)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        _heading(
                          'Customer exposure',
                          count: _accounts.error == null
                              ? '${customers.length} customers'
                              : null,
                        ),
                        if (_accounts.error != null)
                          _error('Customer balances unavailable')
                        else ...[
                          TrexvenTextField(
                            decoration: const TrexvenInputDecoration(
                              labelText: 'Search customers',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) => update(
                              () => search = value.trim().toLowerCase(),
                            ),
                          ),
                          _tabs(
                            const ['All', 'Owing'],
                            owingOnly ? 1 : 0,
                            (i) => update(() => owingOnly = i == 1),
                          ),
                          SizedBox(height: TrexvenPresentation.spacing(context, 14)),
                          if (customers.isEmpty)
                            _empty(
                              'No customer credit yet',
                              'Recorded customer balances will appear here.',
                            ),
                          for (final customer in customers.where(
                            (c) =>
                                (!owingOnly || c.outstanding > 0) &&
                                '${c.name} ${c.contact}'.toLowerCase().contains(
                                  search,
                                ),
                          ))
                            _customerTile(customer, limitView: true),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } finally {
      --_childRoutes;
    }
  }

  Future<void> _receipt(String saleId) async {
    final sale = await widget.api.client
        .from('sales')
        .select()
        .eq('business_id', widget.api.businessId)
        .eq('id', saleId)
        .single()
        .timeout(const Duration(seconds: 20));
    if (widget.branchId != null && sale['branch_id'] != widget.branchId) {
      throw StateError('Select the original authorized branch.');
    }
    final items = await _saleItems(saleId);
    final payments = await widget.api.list(
      'sale_payments',
      foreignKey: 'sale_id',
      foreignId: saleId,
    );
    if (!mounted || !_current) return;
    await showDialog<void>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Original sale receipt'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale['sale_number']?.toString() ?? saleId,
                style: TrexvenPresentation.typography(context, TrexvenTypography.label),
              ),
              Text(
                CustomerPresentation.date(
                  sale['created_at'],
                  includeTime: true,
                ),
              ),
              if (sale['customer_name'] != null)
                Text('${sale['customer_name']}'),
              const Divider(),
              for (final item in items)
                _info(
                  '${item['product_name']} × ${item['quantity']}',
                  _money(item['total'], _currency),
                ),
              const Divider(),
              _info('Sale total', _money(sale['total'], _currency)),
              _info(
                'Payment type',
                CustomerPresentation.label(
                  sale['payment_kind'] ?? sale['payment_method'],
                ),
              ),
              for (final payment in payments)
                _info(
                  'Collected · ${CustomerPresentation.label(payment['method'])}',
                  _money(payment['amount'], _currency),
                ),
              if (payments.isEmpty)
                const Text(
                  'No separate payment lines were stored on this receipt. The original payment type is shown above.',
                ),
              const SizedBox(height: 12),
              const Text(
                'Repayments and return adjustments remain in their own ledger; they are not additional sales.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
