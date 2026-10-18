
import 'package:trexven_design_system/trexven_design_system.dart';
import 'customer_presentation.dart';
import 'package:flutter/material.dart';
import 'operations_client.dart';
import 'cash_shift_screen.dart';

class FinancialOperationsScreen extends StatefulWidget {
final OperationsClient api;
final bool owner;
const FinancialOperationsScreen({
super.key,
required this.api,
required this.owner,
});
@override
State<FinancialOperationsScreen> createState() =>
_FinancialOperationsScreenState();
}

class _FinancialOperationsScreenState extends State<FinancialOperationsScreen> {
late Future<List<List<Map<String, dynamic>>>> data;
bool busy = false;
Future<Map<String, dynamic>>? summary;
String? message;
@override
void initState() {
super.initState();
load();
}

void load() {
data = Future.wait([
widget.api.list('credit_approvals'),
widget.api.list('credit_accounts'),
widget.api.list('sale_returns'),
widget.api.list('credit_entries'),
widget.api.list('offline_sale_reconciliations'),
]);
if (widget.owner) summary = today();
}

Future<Map<String, dynamic>> today() async {
final day = Map<String, dynamic>.from(
await widget.api.call('get_trexven_business_day', {
'p_business_id': widget.api.businessId,
})
as Map,
);
final totals = Map<String, dynamic>.from(
await widget.api.call('get_trexven_financial_summary', {
'p_business_id': widget.api.businessId,
'p_start': day['starts_at'],
'p_end': day['ends_at'],
})
as Map,
);
return {...totals, 'day': day['local_date'], 'timezone': day['timezone']};
}

Future<void> execute(Future<void> Function() action) async {
if (busy) return;
setState(() {
busy = true;
message = null;
});
try {
await action();
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
fallback: 'Operation is not confirmed. Please try again.',
),
);
} finally {
if (mounted) setState(() => busy = false);
}
}

Future<Map<String, String>?> form(
String title,
List<String> fields, {
bool confirm = false,
}) async {
final controls = {for (final name in fields) name: TextEditingController()};
var checked = false;
final result = await showDialog<Map<String, String>>(
context: context,
builder: (context) => StatefulBuilder(
builder: (context, update) => AlertDialog(
scrollable: true,
title: Text(title),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
for (final entry in controls.entries)
if (entry.key == 'Method: cash / bank_transfer / card')
TrexvenDropdown<String>(
decoration: TrexvenInputDecoration(
labelText: 'Payment method',
),
items: [
for (final method in ['cash', 'bank_transfer', 'card'])
DropdownMenuItem(
value: method,
child: Text(CustomerPresentation.label(method)),
),
],
onChanged: (value) => entry.value.text = value ?? '',
)
else
TrexvenTextField(
controller: entry.value,
decoration: TrexvenInputDecoration(labelText: entry.key),
),
if (confirm)
CheckboxListTile(
value: checked,
onChanged: (v) => update(() => checked = v ?? false),
title: Text(
'I verified the actual cash, bank-account or external-terminal outcome. A screenshot alone is insufficient.',
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
    : () => Navigator.pop(
context,
controls.map((k, v) => MapEntry(k, v.text.trim())),
),
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

Future<void> decide(Map<String, dynamic> a, bool approve) async {
final input = await form(
approve ? 'Approve this exact credit sale' : 'Reject credit sale',
widget.owner && approve
? ['Over-limit exception reason (leave blank for ordinary approval)']
    : [],
);
if (input == null) return;
await execute(() async {
await widget.api.call('decide_trexven_credit_approval', {
'p_approval_id': a['id'],
'p_approve': approve,
'p_over_limit_reason':
input.values.isEmpty || input.values.first.isEmpty
? null
    : input.values.first,
});
});
}

Future<void> repay(Map<String, dynamic> a) async {
final input = await form('Record a confirmed repayment', [
'Amount',
'Method: cash / bank_transfer / card',
'Verified external reference (noncash)',
], confirm: true);
if (input == null) return;
final shift =
input['Method: cash / bank_transfer / card'] == 'cash' && mounted
? await chooseCashShift(context, widget.api)
    : null;
final request = widget.api.requestId();
await execute(() async {
await widget.api.call('repay_trexven_credit', {
'p_sale_id': a['sale_id'],
'p_request_id': request,
'p_amount': OperationsClient.amount(
OperationsClient.moneyCents(input['Amount']!),
),
'p_method': input['Method: cash / bank_transfer / card'],
'p_confirmed': true,
'p_evidence': input['Verified external reference (noncash)'],
'p_shift_id': shift,
});
});
}

Future<void> inspect(Map<String, dynamic> r) async {
final items =
(await widget.api.call('get_trexven_return_inspection_items', {
'p_return_id': r['id'],
})
as List)
    .map((i) => Map<String, dynamic>.from(i as Map))
    .toList();
if (!mounted) return;
final fields = items
    .map(
(i) =>
'${i['name']} (${i['quantity']}): sellable / damaged / defective',
)
    .toList();
final input = await form('Inspect every returned item', fields);
if (input == null) return;
await execute(() async {
await widget.api.call('inspect_trexven_return', {
'p_return_id': r['id'],
'p_request_id': widget.api.requestId(),
'p_conditions': [
for (var i = 0; i < items.length; i++)
{
'sale_item_id': items[i]['sale_item_id'],
'condition': input[fields[i]],
},
],
});
});
}

Future<void> approveReturn(Map<String, dynamic> r) async {
final input =
await form('Approve inspected return; debt is reduced first', [
'Method: cash / bank_transfer / card',
'Verified external refund reference (noncash)',
], confirm: true);
if (input == null) return;
final shift =
input['Method: cash / bank_transfer / card'] == 'cash' && mounted
? await chooseCashShift(context, widget.api)
    : null;
await execute(() async {
await widget.api.call('approve_trexven_return', {
'p_return_id': r['id'],
'p_request_id': widget.api.requestId(),
'p_method': input['Method: cash / bank_transfer / card'],
'p_confirmed': true,
'p_evidence': input['Verified external refund reference (noncash)'],
'p_shift_id': shift,
});
});
}

Future<void> requestReturn() async {
final sales = await widget.api.list('sales');
if (!mounted) return;
final sale = await showDialog<Map<String, dynamic>>(
context: context,
builder: (context) => SimpleDialog(
title: Text('Select the original receipt'),
children: [
for (final s in sales.where((s) => s['status'] == 'completed'))
SimpleDialogOption(
onPressed: () => Navigator.pop(context, s),
child: Text(
'${s['created_at']} · ${s['total']} · ${s['payment_kind'] ?? s['payment_method']}',
),
),
],
),
);
if (sale == null) return;
final items = await widget.api.list(
'sale_items',
foreignKey: 'sale_id',
foreignId: sale['id'] as String,
);
final products = await widget.api.list('products');
if (!mounted) return;
final item = await showDialog<Map<String, dynamic>>(
context: context,
builder: (context) => SimpleDialog(
title: Text('Select the returned item'),
children: [
for (final i in items)
SimpleDialogOption(
onPressed: () => Navigator.pop(context, i),
child: Text(
'${products.where((p) => p['id'] == i['product_id']).firstOrNull?['name'] ?? 'Original product'} · sold ${i['quantity']}',
),
),
],
),
);
if (item == null) return;
final input = await form('Return original item', ['Quantity', 'Reason']);
if (input == null) return;
await execute(() async {
await widget.api.call('request_trexven_return', {
'p_sale_id': sale['id'],
'p_request_id': widget.api.requestId(),
'p_items': [
{'sale_item_id': item['id'], 'quantity': input['Quantity']},
],
'p_reason': input['Reason'],
});
});
}

Future<void> history(
Map<String, dynamic> a,
List<Map<String, dynamic>> entries,
) async {
await showDialog<void>(
context: context,
builder: (context) => SimpleDialog(
title: Text('${a['debtor_name']} · payment history'),
children: [
for (final e in entries.where((e) => e['sale_id'] == a['sale_id']))
ListTile(
title: Text(
'${CustomerPresentation.label(e['kind'])} · ${e['amount']} · ${e['method'] ?? 'Debt adjustment'}',
),
subtitle: Text(
'${e['created_at']} · ${e['reason'] ?? e['evidence'] ?? ''}',
),
trailing: widget.owner && e['kind'] == 'repayment'
? TextButton(
child: Text('Reverse'),
onPressed: () {
Navigator.pop(context);
reverse(e);
},
)
    : null,
),
],
),
);
}

Future<void> reverse(Map<String, dynamic> e) async {
final input = await form('Confirm repayment reversal', [
'Reason',
'Verified external reference (noncash)',
], confirm: true);
if (input == null) return;
final shift = e['method'] == 'cash' && mounted
? await chooseCashShift(context, widget.api)
    : null;
await execute(() async {
await widget.api.call('reverse_trexven_credit_repayment', {
'p_entry_id': e['id'],
'p_request_id': widget.api.requestId(),
'p_reason': input['Reason'],
'p_confirmed': true,
'p_evidence': input['Verified external reference (noncash)'],
'p_shift_id': shift,
});
});
}

Future<void> limit() async {
final input = await form('Set business credit exposure limit', ['Amount']);
if (input == null) return;
await execute(() async {
await widget.api.call('set_trexven_credit_limit', {
'p_business_id': widget.api.businessId,
'p_amount': OperationsClient.amount(
OperationsClient.moneyCents(input['Amount']!, allowZero: true),
),
});
});
}

Future<void> discard() async {
final input = await form(
'Discard only an unsaved operation with no money collected or returned',
[],
confirm: true,
);
if (input == null) return;
await execute(() => widget.api.discardUncommitted(noMoneyMoved: true));
}

static const _bg = Color(0xFFF5F7FC);
static const _navy = Color(0xFF14213D);
static const _blue = Color(0xFF2864F0);
static const _muted = Color(0xFF71809A);
static const _border = Color(0xFFE6EAF2);

Widget _panel({required Widget child}) => Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(15),
border: Border.all(color: _border),
),
child: child,
);

Widget _section(String title, int count) => Padding(
padding: const EdgeInsets.only(top: 22, bottom: 10),
child: Row(children: [
Expanded(child: Text(title, style: const TextStyle(
color: _navy, fontWeight: FontWeight.w800, fontSize: 15))),
Container(
padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
decoration: BoxDecoration(color: const Color(0xFFEAF0FF),
borderRadius: BorderRadius.circular(12)),
child: Text('$count', style: const TextStyle(color: _blue,
fontSize: 11, fontWeight: FontWeight.w700)),
),
]),
);

Widget _smallButton(String label, VoidCallback? action, {
bool filled = false,
bool danger = false,
}) => filled
? FilledButton(
onPressed: action,
style: FilledButton.styleFrom(
backgroundColor: danger ? const Color(0xFFB54750) : _blue,
foregroundColor: Colors.white,
visualDensity: VisualDensity.compact,
padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
child: Text(label, style: const TextStyle(fontSize: 11)),
)
    : OutlinedButton(
onPressed: action,
style: OutlinedButton.styleFrom(
foregroundColor: danger ? const Color(0xFFB54750) : _navy,
side: const BorderSide(color: _border),
visualDensity: VisualDensity.compact,
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
child: Text(label, style: const TextStyle(fontSize: 11)),
);

Widget _entry({
required String title,
required String subtitle,
Widget? actions,
VoidCallback? onTap,
}) => _panel(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
InkWell(
onTap: onTap,
child: Row(children: [
Expanded(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(title, style: const TextStyle(color: _navy,
fontSize: 13, fontWeight: FontWeight.w700)),
const SizedBox(height: 5),
Text(subtitle, style: const TextStyle(color: _muted,
fontSize: 11, height: 1.5)),
],
)),
if (onTap != null) const Icon(Icons.chevron_right_rounded,
color: _muted, size: 20),
]),
),
if (actions != null) ...[
const SizedBox(height: 10),
const Divider(height: 1, color: _border),
const SizedBox(height: 9),
actions,
],
],
));

Widget _gapEntry(Widget child) => Padding(
padding: const EdgeInsets.only(bottom: 9), child: child);

Widget _empty(String text) => _panel(child: Padding(
padding: const EdgeInsets.symmetric(vertical: 14),
child: Text(text, textAlign: TextAlign.center,
style: const TextStyle(color: _muted, fontSize: 12)),
));

Widget _summaryPanel() {
final future = summary;
if (future == null) return const SizedBox.shrink();
return FutureBuilder<Map<String, dynamic>>(
future: future,
builder: (context, snapshot) {
if (snapshot.hasError) return _panel(child: const Text(
'Financial totals unavailable. No estimated totals shown.',
style: TextStyle(color: _muted, fontSize: 12)));
if (!snapshot.hasData) return const LinearProgressIndicator(color: _blue);
final t = snapshot.data!;
final metrics = <MapEntry<String, dynamic>>[
MapEntry('Gross sales', t['gross_sales']),
MapEntry('Net collected', t['net_collected']),
MapEntry('Outstanding debt', t['receivables']),
MapEntry('Overdue', t['overdue']),
MapEntry('Refunds', t['refunds']),
];
return _panel(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Business day · ${CustomerPresentation.date(t['day'])}',
style: const TextStyle(color: _navy, fontSize: 13,
fontWeight: FontWeight.w800)),
const SizedBox(height: 3),
Text('${t['timezone'] ?? ''}', style: const TextStyle(
color: _muted, fontSize: 11)),
const SizedBox(height: 12),
Wrap(spacing: 8, runSpacing: 8, children: [
for (final metric in metrics)
Container(
width: 142,
padding: const EdgeInsets.all(11),
decoration: BoxDecoration(color: _bg,
borderRadius: BorderRadius.circular(10)),
child: Column(crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(metric.key, style: const TextStyle(
color: _muted, fontSize: 10)),
const SizedBox(height: 5),
Text(CustomerPresentation.amount(metric.value),
style: const TextStyle(color: _navy,
fontSize: 14, fontWeight: FontWeight.w800)),
]),
),
]),
],
));
},
);
}

@override
Widget build(BuildContext context) => Scaffold(
backgroundColor: _bg,
appBar: AppBar(
backgroundColor: _bg,
surfaceTintColor: Colors.transparent,
title: const Text('Credit & Returns', style: TextStyle(
color: _navy, fontSize: 18, fontWeight: FontWeight.w800)),
actions: [IconButton(
tooltip: 'Refresh',
onPressed: busy ? null : () => setState(load),
icon: const Icon(Icons.refresh_rounded, color: _navy),
)],
),
body: FutureBuilder<List<List<Map<String, dynamic>>>>(
future: data,
builder: (context, snapshot) {
if (snapshot.connectionState != ConnectionState.done) {
return const Center(child: TrexvenLoading());
}
if (snapshot.hasError) {
return Center(child: Padding(
padding: const EdgeInsets.all(24),
child: Column(mainAxisSize: MainAxisSize.min, children: [
const Icon(Icons.cloud_off_outlined, color: _muted, size: 36),
const SizedBox(height: 12),
const Text('Financial operations unavailable',
style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
const SizedBox(height: 8),
const Text('We could not load your financial operations.',
style: TextStyle(color: _muted)),
const SizedBox(height: 12),
_smallButton('Retry', () => setState(load), filled: true),
]),
));
}
final rows = snapshot.data!;
return ListView(
padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
children: [
const Text('Financial operations', style: TextStyle(
color: _navy, fontSize: 21, fontWeight: FontWeight.w800)),
const SizedBox(height: 5),
const Text('Manage customer credit, repayments, returns and refunds.',
style: TextStyle(color: _muted, fontSize: 12)),
const SizedBox(height: 16),
if (message != null) ...[
_panel(child: Text(message!, style: const TextStyle(
color: _navy, fontSize: 12))),
const SizedBox(height: 10),
],
if (busy) ...[
const LinearProgressIndicator(color: _blue),
const SizedBox(height: 12),
],
if (summary != null) ...[
_summaryPanel(),
const SizedBox(height: 14),
],
_panel(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('Quick actions', style: TextStyle(color: _navy,
fontSize: 14, fontWeight: FontWeight.w800)),
const SizedBox(height: 9),
Wrap(spacing: 8, runSpacing: 7, children: [
_smallButton('Request return', busy ? null : requestReturn,
filled: true),
_smallButton('Recover operation', busy ? null : () => execute(() async {
await widget.api.recoverPending();
})),
_smallButton('Discard unsaved', busy ? null : discard),
if (widget.owner) _smallButton('Credit limit',
busy ? null : limit),
]),
],
)),
_section('Credit approvals', rows[0].length),
if (rows[0].isEmpty) _empty('No credit approvals')
else for (final a in rows[0]) _gapEntry(_entry(
title: '${((a['payload'] as Map)['credit'] as Map)['debtor_name']}',
subtitle: '${((a['payload'] as Map)['credit'] as Map)['contact']} · '
'${CustomerPresentation.label(a['status'])} · '
'Total ${(a['payload'] as Map)['total']}',
actions: a['status'] == 'pending'
? Wrap(spacing: 8, runSpacing: 6, children: [
_smallButton('Approve', busy ? null : () => decide(a, true),
filled: true),
_smallButton('Reject', busy ? null : () => decide(a, false),
danger: true),
])
    : null,
)),
_section('Customer balances', rows[1].length),
if (rows[1].isEmpty) _empty('No customer credit balances')
else for (final a in rows[1]) _gapEntry(_entry(
title: '${a['debtor_name']} · ${a['contact']}',
subtitle: 'Outstanding ${a['outstanding']} · Due ${a['due_date']}\n'
'Sale ${a['sale_id']}',
actions: Wrap(spacing: 8, runSpacing: 6, children: [
_smallButton('Record repayment', busy ? null : () => repay(a),
filled: true),
_smallButton('Payment history', busy ? null : () => history(a, rows[3])),
]),
)),
_section('Returns & refunds', rows[2].length),
if (rows[2].isEmpty) _empty('No returns or refunds')
else for (final r in rows[2]) _gapEntry(_entry(
title: '${r['reason'] ?? 'Return'}',
subtitle: '${CustomerPresentation.label(r['status'])} · '
'Sale ${r['sale_id']} · Refund ${r['refund_amount'] ?? '—'}',
actions: r['status'] == 'requested'
? _smallButton('Inspect return', busy ? null : () => inspect(r),
filled: true)
    : r['status'] == 'inspected'
? _smallButton('Approve refund', busy ? null : () => approveReturn(r),
filled: true)
    : null,
)),
_section('Offline cash reconciliation', rows[4].length),
if (rows[4].isEmpty) _empty('No offline cash discrepancies')
else for (final r in rows[4]) _gapEntry(_entry(
title: r['reviewed_by'] == null ? 'Requires review' : 'Reviewed',
subtitle: '${CustomerPresentation.date(r['occurred_at'], includeTime: true)} · '
'${CustomerPresentation.stockDiscrepancies(r['discrepancies'])}\n'
'${r['review_reason'] ?? ''}',
actions: r['reviewed_by'] == null
? _smallButton('Review discrepancy', busy ? null : () async {
final input = await form('Explain the reviewed discrepancy',
['Review reason']);
if (input == null) return;
await execute(() async {
await widget.api.call('review_trexven_offline_reconciliation', {
'p_reconciliation_id': r['id'],
'p_request_id': widget.api.requestId(),
'p_reason': input['Review reason'],
});
});
}, filled: true)
    : null,
)),
],
);
},
),
);
}
