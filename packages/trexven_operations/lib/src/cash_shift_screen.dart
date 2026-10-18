import 'package:trexven_design_system/trexven_design_system.dart';
import 'customer_presentation.dart';
import 'package:flutter/material.dart';
import 'operations_client.dart';

/// Cash context is chosen before payment confirmation and retained in its journal.
Future<String?> chooseCashShift(
    BuildContext context,
    OperationsClient api, {
      bool allowNoDrawer = false,
      Map<String, dynamic>? cashContext,
    }) async {
  final current = cashContext ?? await api.cashContext();
  if (current['configured'] != true) return null;
  final shifts = (current['shifts'] as List).map(
        (r) => Map<String, dynamic>.from(r as Map),
  );
  if (!context.mounted) throw StateError('Cash drawer selection interrupted.');
  final shift = await showDialog<String>(
    animationStyle: TrexvenPresentation.motion(context),
context: context,
    builder: (context) => SimpleDialog(
      title: Text('Select your joined cash drawer'),
      children: [
        for (final s in shifts.where(
              (s) =>
          s['status'] == 'open' &&
              s['joined'] == true &&
              s['register_active'] == true,
        ))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, s['id'] as String),
            child: Text('${s['register_name']} · shared drawer'),
          ),
        Padding(
          padding: TrexvenSpacing.cardPadding,
          child: Text(
            'Open or join your assigned register in Cash shifts first. Server authorization checks membership.',
          ),
        ),
        if (allowNoDrawer)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue without cash payment'),
          ),
      ],
    ),
  );
  if (shift == null && !allowNoDrawer)
    throw StateError('Cash drawer selection cancelled.');
  return shift;
}

class CashShiftScreen extends StatefulWidget {
  final OperationsClient api;
  final bool owner;
  final bool reviewer;
  const CashShiftScreen({
    super.key,
    required this.api,
    required this.owner,
    this.reviewer = false,
  });
  @override
  State<CashShiftScreen> createState() => _CashShiftScreenState();
}

class _CashShiftScreenState extends State<CashShiftScreen> {
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
      widget.api.list('cash_registers'),
      widget.api.list('cash_shifts'),
      widget.api.list('cash_events'),
      widget.api.list('cash_handovers'),
    ]);
  }

  Future<Map<String, String>?> fields(
      String title,
      List<String> names, {
        bool confirm = false,
      }) async {
    final controls = {for (final n in names) n: TextEditingController()};
    var checked = false;
    String? formError;
    final result = await showDialog<Map<String, String>>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in controls.entries)
                  TrexvenTextField(
                    controller: c.value,
                    decoration: TrexvenInputDecoration(labelText: c.key),
                  ),
                if (confirm)
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => update(() => checked = v ?? false),
                    title: Text(
                      'The drawer has been physically counted. All employees have checked pending cash requests; late synchronization will require reconciliation.',
                    ),
                  ),
                if (formError != null)
                  Text(
                    formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
              onPressed: confirm && !checked
                  ? null
                  : () {
                try {
                  for (final entry in controls.entries) {
                    if (entry.key == 'Amount' ||
                        entry.key.startsWith('Actual '))
                      OperationsClient.moneyCents(
                        entry.value.text,
                        allowZero: entry.key != 'Amount',
                      );
                  }
                  Navigator.pop(
                    context,
                    controls.map((k, v) => MapEntry(k, v.text.trim())),
                  );
                } catch (e) {
                  update(() => formError = '$e');
                }
              },
              child: Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    for (final c in controls.values) {
      c.dispose();
    }
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
          message = 'Server confirmed.';
          load();
        });
    } catch (e) {
      if (mounted) setState(() => message = 'Not confirmed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> configure() async {
    final members = await widget.api.list('business_members');
    if (!mounted) return;
    final selected = <String>{};
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text('Named shared register'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrexvenTextField(
                  controller: name,
                  decoration: TrexvenInputDecoration(labelText: 'Register name'),
                ),
                for (final m in members.where((m) => m['status'] == 'active'))
                  CheckboxListTile(
                    title: Text('${m['full_name']}'),
                    value: selected.contains(m['id']),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        selected.add(m['id'] as String);
                      } else {
                        selected.remove(m['id']);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Save assignments'),
            ),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true) return;
    await run('configure_trexven_register', {
      'p_business_id': widget.api.businessId,
      'p_name': text,
      'p_members': selected.toList(),
    });
  }

  Future<void> open(Map<String, dynamic> r) async {
    final f = await fields('Open ${r['name']}', ['Actual opening cash']);
    if (f == null) return;
    await run('open_trexven_cash_shift', {
      'p_register_id': r['id'],
      'p_opening': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual opening cash']!, allowZero: true),
      ),
    });
  }

  Future<void> move(Map<String, dynamic> s, String kind) async {
    final f = await fields(kind, ['Amount', 'Reason']);
    if (f == null) return;
    await run('move_trexven_cash', {
      'p_shift_id': s['id'],
      'p_amount': OperationsClient.amount(
        OperationsClient.moneyCents(f['Amount']!),
      ),
      'p_kind': kind,
      'p_reason': f['Reason'],
    });
  }

  Future<void> close(Map<String, dynamic> s) async {
    final f = await fields('Close the shared drawer once', [
      'Actual counted cash',
      'Discrepancy reason',
    ], confirm: true);
    if (f == null) return;
    await run('close_trexven_cash_shift', {
      'p_shift_id': s['id'],
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
      'p_reason': f['Discrepancy reason'],
      'p_no_pending_cash': true,
    });
  }

  Future<void> recoverShift(Map<String, dynamic> s) async {
    final f = await fields(
      'Owner or authorized manager recovery: retain all pending cash',
      ['Actual counted cash', 'Recovery reason'],
      confirm: true,
    );
    if (f == null) return;
    await run('force_close_trexven_cash_shift', {
      'p_shift_id': s['id'],
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
      'p_reason': f['Recovery reason'],
      'p_review_pending_cash': true,
    });
  }

  Future<void> review(Map<String, dynamic> s) async {
    final f = await fields('Review closure and late events', ['Review reason']);
    if (f == null) return;
    await run('review_trexven_cash_shift', {
      'p_shift_id': s['id'],
      'p_reason': f['Review reason'],
    });
  }

  Future<void> handover(Map<String, dynamic> s) async {
    final members = await widget.api.list('business_members');
    if (!mounted) return;
    final member = await showDialog<Map<String, dynamic>>(
      animationStyle: TrexvenPresentation.motion(context),
context: context,
      builder: (context) => SimpleDialog(
        title: Text('Incoming employee'),
        children: [
          for (final m in members.where((m) => m['status'] == 'active'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text('${m['full_name']}'),
            ),
        ],
      ),
    );
    if (member == null) return;
    final f = await fields('Request shared drawer handover', [
      'Actual counted cash',
      'Reason',
    ]);
    if (f == null) return;
    await run('request_trexven_cash_handover', {
      'p_shift_id': s['id'],
      'p_incoming_member': member['id'],
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
      'p_reason': f['Reason'],
    });
  }

  Future<void> accept(Map<String, dynamic> h) async {
    final f = await fields('Incoming employee handover confirmation', [
      'Actual counted cash',
    ], confirm: true);
    if (f == null) return;
    await run('confirm_trexven_cash_handover', {
      'p_handover_id': h['id'],
      'p_accept': true,
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
    });
  }

  static const _bg = Color(0xFFF5F7FC);
  static const _navy = Color(0xFF14213D);
  static const _blue = Color(0xFF2864F0);
  static const _muted = Color(0xFF71809A);
  static const _border = Color(0xFFE6EAF2);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TrexvenPresentation.color(context, _bg, 'background'),
    appBar: AppBar(
      title: Text('Shared Cash Drawers', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 19), fontWeight: FontWeight.w800)),
      backgroundColor: TrexvenPresentation.color(context, _bg, 'background'),
      foregroundColor: TrexvenPresentation.color(context, _navy, 'ink'),
      surfaceTintColor: Colors.transparent,
      actions: [IconButton(tooltip: 'Refresh', onPressed: busy ? null : () => setState(load), icon: const Icon(Icons.refresh_rounded))],
    ),
    body: FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: TrexvenLoading());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, color: TrexvenPresentation.color(context, _muted, 'muted'), size: 38),
              const SizedBox(height: 12),
              Text('Cash drawer data unavailable', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Check the connection or backend and try again.', textAlign: TextAlign.center, style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'))),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => setState(load), child: const Text('Retry')),
            ],
          )));
        }
        final rows = snapshot.data!;
        final registers = rows[0];
        final shifts = rows[1];
        final events = rows[2];
        final handovers = rows[3];
        final registerNames = {for (final r in registers) r['id']: '${r['name'] ?? 'Register'}'};
        final openCount = shifts.where((s) => s['status'] == 'open').length;
        final pendingCount = handovers.where((h) => h['status'] == 'pending').length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (!TrexvenPresentation.isPos(context)) Text('Cash Management', style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 21), fontWeight: FontWeight.w800, color: TrexvenPresentation.color(context, _navy, 'ink'))),
            SizedBox(height: TrexvenPresentation.spacing(context, 5)),
            Text('Manage shared registers, cash movements, handovers and shift reconciliation.', style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 12), height: 1.5)),
            if (busy) ...[const SizedBox(height: 12), LinearProgressIndicator(color: TrexvenPresentation.color(context, _blue, 'brand'))],
            if (message != null) ...[const SizedBox(height: 12), _card(child: Text(message!, style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 12))))],
            SizedBox(height: TrexvenPresentation.spacing(context, 18)),
            if (TrexvenPresentation.isPos(context))
              _card(child: Wrap(spacing: 24, runSpacing: 12, children: [
                _compactMetric('Registers', '${registers.length}'),
                _compactMetric('Open shifts', '$openCount'),
                _compactMetric('Handovers', '$pendingCount'),
              ]))
            else
            Row(children: [
              Expanded(child: _metric('Registers', '${registers.length}', Icons.point_of_sale_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _metric('Open shifts', '$openCount', Icons.account_balance_wallet_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _metric('Handovers', '$pendingCount', Icons.swap_horiz_rounded)),
            ]),
            SizedBox(height: TrexvenPresentation.spacing(context, 23)),
            _heading('Cash registers', registers.length),
            SizedBox(height: TrexvenPresentation.spacing(context, 10)),
            if (widget.owner) ...[
              _card(child: _action(Icons.add_circle_outline_rounded, 'Configure register assignments', 'Create a named register and assign employees', busy ? null : configure)),
              SizedBox(height: TrexvenPresentation.spacing(context, 9)),
            ],
            if (registers.isEmpty) _empty('No shared cash registers configured.'),
            for (final r in registers) ...[
              _card(child: Row(children: [
                _iconBox(Icons.point_of_sale_outlined),
                SizedBox(width: TrexvenPresentation.spacing(context, 11)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['name'] ?? 'Register'}', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontWeight: FontWeight.w800, fontSize: TrexvenPresentation.fontSize(context, 13))),
                  const SizedBox(height: 4),
                  Text('Shared cash register', style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 11))),
                ])),
                TextButton(onPressed: busy ? null : () => open(r), child: const Text('Open')),
              ])),
              SizedBox(height: TrexvenPresentation.spacing(context, 9)),
            ],
            SizedBox(height: TrexvenPresentation.spacing(context, 15)),
            _heading('Shift history', shifts.length),
            SizedBox(height: TrexvenPresentation.spacing(context, 10)),
            if (shifts.isEmpty) _empty('No cash shifts yet.'),
            for (final s in shifts) ...[
              _shiftCard(s, registerNames[s['register_id']] ?? 'Register', events.where((e) => e['shift_id'] == s['id']).toList()),
              SizedBox(height: TrexvenPresentation.spacing(context, 10)),
            ],
            SizedBox(height: TrexvenPresentation.spacing(context, 14)),
            _heading('Employee handovers', handovers.length),
            SizedBox(height: TrexvenPresentation.spacing(context, 10)),
            if (handovers.isEmpty) _empty('No handover requests.'),
            for (final h in handovers) ...[
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Cash drawer handover', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontWeight: FontWeight.w800, fontSize: TrexvenPresentation.fontSize(context, 13)))),
                  _status(h['status']),
                ]),
                SizedBox(height: TrexvenPresentation.spacing(context, 9)),
                _detail('Counted', h['counted']),
                _detail('Reason', h['reason']),
                if (h['status'] == 'pending') ...[
                  SizedBox(height: TrexvenPresentation.spacing(context, 9)),
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: busy ? null : () => accept(h), child: const Text('Confirm handover'))),
                ],
              ])),
              SizedBox(height: TrexvenPresentation.spacing(context, 9)),
            ],
          ],
        );
      },
    ),
  );

  Widget _shiftCard(Map<String, dynamic> s, String registerName, List<Map<String, dynamic>> events) {
    final isOpen = s['status'] == 'open';
    final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _iconBox(Icons.account_balance_wallet_outlined),
        SizedBox(width: TrexvenPresentation.spacing(context, 10)),
        Expanded(child: Text(registerName, style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontWeight: FontWeight.w800, fontSize: TrexvenPresentation.fontSize(context, 13)))),
        _status(s['status']),
      ]),
      const SizedBox(height: 12),
      _detail('Opening cash', s['opening_amount']),
      _detail('Expected now', s['expected_current']),
      _detail('Expected at close', s['expected_at_close']),
      _detail('Counted', s['counted_amount']),
      _detail('Difference', s['difference_at_close']),
      _detail('Review', s['review_status']),
      Divider(height: 22, color: TrexvenPresentation.color(context, _border, 'border')),
      if (isOpen) ...[
        Wrap(spacing: 8, runSpacing: 6, children: [
          _smallButton('Join drawer', () => run('join_trexven_cash_shift', {'p_shift_id': s['id']})),
          _smallButton('Cash in', () => move(s, 'cash_in')),
          _smallButton('Cash out', () => move(s, 'cash_out')),
          _smallButton('Handover', () => handover(s)),
          _smallButton('Close drawer', () => close(s)),
          if (widget.owner || widget.reviewer) _smallButton('Recover drawer', () => recoverShift(s)),
        ]),
      ] else ...[
        OutlinedButton.icon(
          onPressed: busy ? null : () => review(s),
          icon: const Icon(Icons.fact_check_outlined, size: 17),
          label: const Text('Review reconciliation'),
        ),
      ],
      if (events.isNotEmpty) ...[
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('Cash events (${events.length})', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 12), fontWeight: FontWeight.w800)),
          children: [for (final e in events) Padding(
            padding: EdgeInsets.symmetric(vertical: TrexvenPresentation.spacing(context, 7)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.receipt_long_outlined, color: TrexvenPresentation.color(context, _blue, 'brand'), size: 17),
              SizedBox(width: TrexvenPresentation.spacing(context, 9)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${CustomerPresentation.label(e['kind'])} · ${e['amount'] ?? '—'}${e['late'] == true ? ' · Late sync' : ''}', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 11), fontWeight: FontWeight.w700)),
                SizedBox(height: TrexvenPresentation.spacing(context, 3)),
                Text('${e['created_at'] ?? ''} · ${e['reason'] ?? ''}', style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 10))),
              ])),
            ]),
          )],
        ),
      ],
    ]);
    if (TrexvenPresentation.isPos(context)) {
      return _card(child: ExpansionTile(tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero,
        title: Text(registerName, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${CustomerPresentation.label(s['status'])} · Expected ${s['expected_current'] ?? s['expected_at_close'] ?? 'Unavailable'}'),
        children: [details]));
    }
    return _card(child: details);

  }

  Widget _smallButton(String title, Future<void> Function() callback) => OutlinedButton(
    onPressed: busy ? null : () { callback(); },
    style: TrexvenPresentation.isPos(context) ? Theme.of(context).outlinedButtonTheme.style
      : OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.symmetric(horizontal: TrexvenPresentation.spacing(context, 11), vertical: 8)),
    child: Text(title, style: TextStyle(fontSize: TrexvenPresentation.fontSize(context, 11))),
  );

  Widget _compactMetric(String label, String value) => Column(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4), Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);

  Widget _metric(String label, String value, IconData icon) => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: TrexvenPresentation.color(context, _blue, 'brand'), size: 19),
    SizedBox(height: TrexvenPresentation.spacing(context, 9)),
    Text(value, style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontWeight: FontWeight.w800, fontSize: TrexvenPresentation.fontSize(context, 19))),
    SizedBox(height: TrexvenPresentation.spacing(context, 3)),
    Text(label, style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 10))),
  ]));

  Widget _heading(String title, int count) => Row(children: [
    Expanded(child: Text(title, style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 15), fontWeight: FontWeight.w800))),
    Container(padding: EdgeInsets.symmetric(horizontal: TrexvenPresentation.spacing(context, 9), vertical: 4), decoration: BoxDecoration(color: TrexvenPresentation.color(context, const Color(0xFFE8EFFF), 'soft'), borderRadius: BorderRadius.circular(20)), child: Text('$count', style: TextStyle(color: TrexvenPresentation.color(context, _blue, 'brand'), fontSize: TrexvenPresentation.fontSize(context, 11), fontWeight: FontWeight.w800))),
  ]);

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(TrexvenPresentation.spacing(context, 14)),
    decoration: BoxDecoration(color: TrexvenPresentation.color(context, Colors.white, 'surface'), border: Border.all(color: TrexvenPresentation.color(context, _border, 'border')), borderRadius: BorderRadius.circular(14)),
    child: child,
  );

  Widget _iconBox(IconData icon) => Container(
    width: 39, height: 39,
    decoration: BoxDecoration(color: TrexvenPresentation.color(context, const Color(0xFFEAF0FF), 'soft'), borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: TrexvenPresentation.color(context, _blue, 'brand'), size: 20),
  );

  Widget _action(IconData icon, String title, String subtitle, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Row(children: [
      _iconBox(icon),
      SizedBox(width: TrexvenPresentation.spacing(context, 11)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 12), fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 10))),
      ])),
      Icon(Icons.chevron_right_rounded, color: TrexvenPresentation.color(context, _muted, 'muted')),
    ]),
  );

  Widget _detail(String label, dynamic value) => Padding(
    padding: EdgeInsets.only(bottom: TrexvenPresentation.spacing(context, 5)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 115, child: Text(label, style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 11)))),
      Expanded(child: Text('${value ?? '—'}', style: TextStyle(color: TrexvenPresentation.color(context, _navy, 'ink'), fontSize: TrexvenPresentation.fontSize(context, 11), fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _status(dynamic raw) {
    final value = '${raw ?? 'unknown'}'.toLowerCase();
    final color = value == 'open' || value == 'completed' || value == 'accepted'
        ? TrexvenPresentation.color(context, const Color(0xFF16845A), 'success')
        : value == 'pending' ? TrexvenPresentation.color(context, const Color(0xFFB7791F), 'warning') : TrexvenPresentation.color(context, _muted, 'muted');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: TrexvenPresentation.spacing(context, 5)),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(8)),
      child: Text(CustomerPresentation.label(raw), style: TextStyle(color: color, fontSize: TrexvenPresentation.fontSize(context, 10), fontWeight: FontWeight.w700)),
    );
  }

  Widget _empty(String text) => _card(child: Padding(
    padding: EdgeInsets.symmetric(vertical: TrexvenPresentation.spacing(context, 14)),
    child: Column(children: [
      Icon(Icons.inbox_outlined, color: TrexvenPresentation.color(context, _muted, 'muted'), size: 27),
      const SizedBox(height: 8),
      Text(text, textAlign: TextAlign.center, style: TextStyle(color: TrexvenPresentation.color(context, _muted, 'muted'), fontSize: TrexvenPresentation.fontSize(context, 12))),
    ]),
  ));
}
