import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import '../../services/database_service.dart';
import '../../services/business_reporting.dart';
import 'transaction_history_screen.dart';
import 'operational_finance_screen.dart';

/// Authorized financial reporting using the existing business-time contract.
class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key, this.database});
  final DatabaseService? database;

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  static const _bg = Color(0xFFF5F7FC);
  static const _navy = Color(0xFF14213D);
  static const _blue = Color(0xFF2864F0);
  static const _muted = Color(0xFF71809A);

  late final DatabaseService _db;
  late Future<FinanceReport> _report;
  FinanceReport? _current;
  int? _selectedPoint;
  String _period = 'today';
  String _metric = 'sales';
  DateTimeRange? _customRange;

  String _money(num amount) => NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  ).format(amount);

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? DatabaseService();
    _load();
  }

  void _load() {
    _selectedPoint = null;
    _report = _db
        .getFinanceReport(
          _period,
          customStart: _customRange?.start,
          customEnd: _customRange?.end,
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _report;
    } catch (_) {
      // Each section displays its own retry state.
    }
  }

  Future<void> _choosePeriod(String? value) async {
    if (value == null) return;
    if (value == 'custom') {
      DateTime now;
      try {
        final today = BusinessPeriod.fromDay(
          await _db.getBusinessDay().timeout(const Duration(seconds: 20)),
          'today',
        );
        now = today.local(today.start);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to load the business calendar. Please retry.',
              ),
            ),
          );
        return;
      }
      if (!mounted) return;
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 6)),
              end: now,
            ),
      );
      if (!mounted || selected == null) return;
      setState(() {
        _period = value;
        _customRange = selected;
        _load();
      });
    } else {
      setState(() {
        _period = value;
        _load();
      });
    }
  }

  String get _periodLabel {
    switch (_period) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case '7':
        return 'Last 7 days';
      case '30':
        return 'Last 30 days';
      case 'month':
        return 'This month';
      case 'previous':
        return 'Last month';
      case 'custom':
        if (_customRange == null) return 'Custom range';
        return '${DateFormat('d MMM').format(_customRange!.start)} – ${DateFormat('d MMM').format(_customRange!.end)}';
      default:
        return 'Today';
    }
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _breakdownCard(Map<String, dynamic> summary) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          _breakdownRow('Net Collected', _money(financialNumber(summary['net_collected']))),
          const Divider(height: 16, color: Color(0xFFE8EDF5)),
          _breakdownRow('Refunds', _money(financialNumber(summary['refunds']))),
          const Divider(height: 16, color: Color(0xFFE8EDF5)),
          _breakdownRow('Sale Collections', _money(financialNumber(summary['sale_collections']))),
          const Divider(height: 16, color: Color(0xFFE8EDF5)),
          _breakdownRow('Repayments', _money(financialNumber(summary['repayment_collections']))),
          const Divider(height: 16, color: Color(0xFFE8EDF5)),
          _breakdownRow('Current Receivables (Balance)', _money(financialNumber(summary['receivables']))),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
        Text(value, style: const TextStyle(color: _navy, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: _navy,
      ),
    ),
  );

  Widget _error(String message) => _card(
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
        TextButton(
          onPressed: () => setState(_load),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _metricTile(
    String label,
    String value,
    IconData icon, {
    String? hint,
  }) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            Icon(icon, color: _blue, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(hint, style: const TextStyle(fontSize: 10, color: _muted)),
        ],
      ],
    ),
  );

  Widget _summary() => FutureBuilder<FinanceReport>(
    future: _report,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return _error('Unable to load revenue. Please retry.');
      if (!snapshot.hasData)
        return _card(child: const Center(child: TrexvenLoading()));
      final data = snapshot.data!;
      _current = data;
      final revenue = financialNumber(data.summary['gross_sales']);
      final count = data.sales.length;
      final revenueText = _money(revenue);
      final countText = count.toString();
      final averageText = _money(count == 0 ? 0 : revenue / count);
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GROSS SALES',
                  style: TextStyle(
                    color: Color(0xFFB9C8E3),
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 13),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    revenueText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_periodLabel · before refunds',
                  style: const TextStyle(
                    color: Color(0xFFB9C8E3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _breakdownCard(data.summary),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Business Expenses',
                  _money(data.expenseTotal),
                  Icons.wallet_outlined,
                  hint: 'Recorded in this period',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  'Estimated Profit',
                  '—',
                  Icons.trending_up_rounded,
                  hint: 'Historical costs unavailable',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Transactions',
                  countText,
                  Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  'Average Sale',
                  averageText,
                  Icons.analytics_outlined,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _graph() => _card(
    padding: EdgeInsets.zero,
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF080F24),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A simple view of your financial activity',
            style: TextStyle(color: Color(0xFFA7B5D0), fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              for (final entry in const [
                ('sales', 'Sales'),
                ('expenses', 'Expenses'),
                ('profit', 'Profit'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: InkWell(
                      onTap: () => setState(() => _metric = entry.$1),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _metric == entry.$1
                              ? _blue
                              : const Color(0xFF17243C),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: _metric == entry.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (_metric == 'profit')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'Profit unavailable: authorized historical costs are missing.',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            FutureBuilder<FinanceReport>(
              future: _report,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return _error(
                    'Unable to load financial history. Please retry.',
                  );
                if (!snapshot.hasData)
                  return const SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(color: _blue),
                    ),
                  );
                final report = snapshot.data!;
                final rows = _metric == 'sales'
                    ? report.sales
                    : report.expenses;
                final points = report.period.aggregate(
                  rows.map(
                    (row) => MapEntry(
                      DateTime.parse(
                        (_metric == 'sales'
                                ? row['sold_at'] ?? row['created_at']
                                : row['created_at'])
                            as String,
                      ),
                      financialNumber(
                        row[_metric == 'sales' ? 'total' : 'amount'],
                      ),
                    ),
                  ),
                  hourly: _period == 'today' || _period == 'yesterday',
                );
                if (points.isEmpty)
                  return const Text(
                    'No activity in this period.',
                    style: TextStyle(color: Colors.white),
                  );
                final selected = _selectedPoint == null
                    ? null
                    : points[_selectedPoint!.clamp(0, points.length - 1)];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metric == 'sales'
                          ? 'GROSS SALES ACTIVITY'
                          : 'RECORDED EXPENSES',
                      style: const TextStyle(
                        color: Color(0xFFA7B5D0),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        onTapDown: (event) => setState(
                          () => _selectedPoint =
                              (event.localPosition.dx /
                                      constraints.maxWidth *
                                      (points.length - 1))
                                  .round()
                                  .clamp(0, points.length - 1),
                        ),
                        child: SizedBox(
                          height: 170,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _FinanceLinePainter(
                              points.map((e) => e.value).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _axisDate(points.first.key),
                          style: const TextStyle(
                            color: Color(0xFFA7B5D0),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _axisDate(points.last.key),
                          style: const TextStyle(
                            color: Color(0xFFA7B5D0),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (selected != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${DateFormat('d MMM, h a').format(selected.key)}: ${_money(selected.value)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _metric == 'sales'
                          ? 'Complete period sales, before refunds. Tap the line for details.'
                          : 'Complete recorded expenses in this period. Tap the line for details.',
                      style: const TextStyle(
                        color: Color(0xFFA7B5D0),
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );

  String _axisDate(DateTime date) =>
      _period == 'today' || _period == 'yesterday'
      ? DateFormat('h a').format(date)
      : DateFormat('d MMM').format(date);

  void _openOperations() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OperationalFinanceScreen(period: _current?.period),
    ),
  );

  Widget _operations() => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: _openOperations,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: _blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Manage Financial Operations',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Expenses  •  Credit & Debts  •  Repayments  •  Returns',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _transactions() => FutureBuilder<FinanceReport>(
    future: _report,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return _error('Unable to load transactions. Please retry.');
      if (!snapshot.hasData)
        return _card(child: const Center(child: TrexvenLoading()));
      final report = snapshot.data!;
      return _card(
        child: Column(
          children: [
            if (report.sales.isEmpty)
              const Text('No transactions in this period.'),
            for (final row in report.sales.take(8))
              financialTransactionTile(row, report.period),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TransactionHistoryScreen(
                    database: _db,
                    period: report.period,
                  ),
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: RefreshIndicator(
      color: _blue,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
        children: [
          const Text(
            'Finance',
            style: TextStyle(
              color: _navy,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Your business financial overview',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Duration',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SizedBox(
                width: 184,
                child: DropdownButtonFormField<String>(
                  value: _period,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(
                      value: 'yesterday',
                      child: Text('Yesterday'),
                    ),
                    DropdownMenuItem(value: '7', child: Text('Last 7 days')),
                    DropdownMenuItem(value: '30', child: Text('Last 30 days')),
                    DropdownMenuItem(value: 'month', child: Text('This month')),
                    DropdownMenuItem(
                      value: 'previous',
                      child: Text('Last month'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom range'),
                    ),
                  ],
                  onChanged: _choosePeriod,
                ),
              ),
            ],
          ),
          if (_period == 'custom' && _customRange != null) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _periodLabel,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _summary(),
          const SizedBox(height: 22),
          _sectionTitle('Financial Insights'),
          _graph(),
          const SizedBox(height: 22),
          _sectionTitle('Financial Operations'),
          _operations(),
          const SizedBox(height: 22),
          _sectionTitle('Recent Transactions'),
          _transactions(),
        ],
      ),
    ),
  );
}

class _FinanceLinePainter extends CustomPainter {
  const _FinanceLinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final gridPaint = Paint()
      ..color = const Color(0xFF25344D)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final maxValue = math.max(1.0, values.reduce(math.max));
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final y = size.height - 9 - (values[i] / maxValue) * (size.height - 22);
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x883B7CFF), Color(0x002864F0)],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x664384FF)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4384FF)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        4,
        Paint()..color = const Color(0xFF4384FF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceLinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
