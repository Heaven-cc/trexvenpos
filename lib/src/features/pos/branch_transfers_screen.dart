import 'package:flutter/material.dart';
import '../../ui/trexven_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import '../inventory/product_provider.dart';

/// Operates on original transfer records; dispatch and receipt are separate.
class PosBranchTransfersScreen extends ConsumerStatefulWidget {
  const PosBranchTransfersScreen({super.key});
  @override
  ConsumerState<PosBranchTransfersScreen> createState() => _PosBranchTransfersScreenState();
}
class _PosBranchTransfersScreenState extends ConsumerState<PosBranchTransfersScreen> {
  final quantity = TextEditingController();
  final reason = TextEditingController();
  String? destination, product;
  String? message;
  bool busy = false;
  bool enabled = false;
  late final String user, business, branch;
  late final OperationsClient api;
  late Future<List<List<Map<String, dynamic>>>> data;
  bool get current {
    final auth = ref.read(authStateProvider);
    final access = ref.read(permissionServiceProvider);
    return mounted && !auth.isLoading && !auth.offlineCashOnly &&
        auth.employee?.userId == user && auth.activeBusiness?.id == business &&
        ref.read(branchContextProvider)?.id == branch &&
        (access.isOwner || access.isManager) && access.hasPermission('transfer_stock');
  }
  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider);
    user = auth.employee?.userId ?? '';
    business = auth.activeBusiness?.id ?? '';
    branch = ref.read(branchContextProvider)?.id ?? '';
    api = OperationsClient.pos(ref.read(supabaseProvider), business);
    data = load();
  }
  Future<List<List<Map<String, dynamic>>>> load() async {
    if (!current || branch.isEmpty) throw StateError('Authorized manager and branch required.');
    final rows = await Future.wait([
      api.list('branches'), api.list('products'), api.list('stock_transfers'),
      api.list('inventory'),
      api.client.from('businesses').select('inventory_transfers_enabled').eq('id', business).single()
        .then((r) => <Map<String, dynamic>>[Map<String, dynamic>.from(r)]),
    ]).timeout(const Duration(seconds: 20));
    if (!current) throw StateError('Branch access changed.');
    enabled = rows[4].single['inventory_transfers_enabled'] == true;
    rows[0] = rows[0].where((b) => b['is_active'] == true && b['id'] != branch).toList();
    rows[2] = rows[2].where((t) => t['source_branch'] == branch || t['destination_branch'] == branch).toList();
    final mapped = rows[3].where((i) => i['branch_id'] == branch).map((i) => i['product_id']).toSet();
    rows[1] = rows[1].where((p) => mapped.contains(p['id'])).toList();
    return rows;
  }
  String validQuantity(String value, {bool zero = false}) {
    final parsed = num.tryParse(value.trim());
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(value.trim()) ||
        parsed == null || !parsed.isFinite || parsed < 0 || (!zero && parsed == 0)) {
      throw const FormatException('Enter a positive quantity with up to three decimals.');
    }
    return value.trim();
  }
  Future<void> run(String rpc, Map<String, dynamic> args) async {
    if (!current || busy) return;
    if (!enabled) { setState(() => message = 'Branch transfers are not enabled for this business. Ask the owner to review configuration.'); return; }
    setState(() { busy = true; message = null; });
    try {
      if (await api.journal.pending() != null) throw StateError('Recover the original operation before another stock movement.');
      await api.call(rpc, {'p_request_id': api.requestId(), ...args});
      if (current) {
        setState(() { message = 'Stock transfer confirmed.'; data = load(); });
        ref.invalidate(productSearchProvider);
      }
    } catch (error) {
      if (mounted) setState(() => message = error is FormatException ? error.message :
        CustomerPresentation.error(error, fallback: 'Not confirmed. Recover the original request before another movement.'));
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> recover() async {
    if (!current || busy) return;
    setState(() => busy = true);
    try {
      final pending = await api.journal.pending();
      if (pending == null) {
        if (mounted) setState(() => message = 'No retained transfer operation.');
        return;
      }
      if (!const {'dispatch_trexven_stock_transfer','receive_trexven_stock_transfer'}.contains(pending['rpc'])) {
        throw StateError('Recover the operation from its original workflow.');
      }
      await api.recoverPending();
      if (current) {
        setState(() { message = 'Original transfer confirmed.'; data = load(); });
        ref.invalidate(productSearchProvider);
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Transfer retained. Verify current access and recover the original request.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> receive(Map<String, dynamic> transfer) async {
    final count = TextEditingController();
    final form = GlobalKey<FormState>();
    final received = await showDialog<String>(
      context: context,
      animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
      builder: (dialog) => TextControllerScope(controllers: [count], child: AlertDialog(
        scrollable: true, title: const Text('Confirm goods received'),
        content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Dispatched: ${transfer['quantity']} · Already received: ${transfer['received']}'),
          TextFormField(controller: count, decoration: const InputDecoration(labelText: 'Actual quantity received now'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) { try { validQuantity(v ?? ''); return null; } catch (_) { return 'Enter the actual positive quantity.'; } }),
          const Text('Record only physically received units. Short deliveries stay in transit for owner review.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(dialog, count.text.trim());
          }, child: const Text('Confirm receipt')),
        ],
      )));
    if (received != null && current) await run('receive_trexven_stock_transfer', {
      'p_transfer_id': transfer['id'], 'p_quantity': received,
      'p_close_discrepancy': false, 'p_reason': null,
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Branch transfers')),
    body: !current ? const Center(child: Text('Verify your manager permission and branch access.')) :
      FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: data, builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: TextButton(
            onPressed: () => setState(() => data = load()), child: const Text('Retry transfer access')));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Dispatch from the current branch. Inventory is credited at the destination only after confirmed receipt.'),
            if (!enabled) const Text('Transfers are disabled in this business configuration. Existing history remains available.'),
            if (message != null) Text(message!),
            if (busy) const LinearProgressIndicator(),
            DropdownButtonFormField<String>(
              value: rows[0].any((b) => b['id'] == destination) ? destination : null,
              decoration: const InputDecoration(labelText: 'Authorized destination'),
              items: [for (final b in rows[0]) DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'].toString()))],
              onChanged: busy ? null : (v) => setState(() => destination = v)),
            DropdownButtonFormField<String>(
              value: rows[1].any((p) => p['id'] == product) ? product : null,
              decoration: const InputDecoration(labelText: 'Product from this branch'),
              items: [for (final p in rows[1]) DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString()))],
              onChanged: busy ? null : (v) => setState(() => product = v)),
            TextField(controller: quantity, enabled: !busy, decoration: const InputDecoration(labelText: 'Dispatch quantity'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            TextField(controller: reason, enabled: !busy, decoration: const InputDecoration(labelText: 'Transfer reason')),
            FilledButton(onPressed: busy || !enabled ? null : () async {
              try {
                if (destination == null || product == null || reason.text.trim().isEmpty) throw const FormatException('Choose a destination, product and reason.');
                await run('dispatch_trexven_stock_transfer', {
                  'p_business_id': business, 'p_source': branch, 'p_destination': destination,
                  'p_product_id': product, 'p_quantity': validQuantity(quantity.text), 'p_reason': reason.text.trim(),
                });
              } catch (error) {
                if (mounted) setState(() => message = error is FormatException ? error.message : 'Check transfer details.');
              }
            }, child: const Text('Dispatch transfer')),
            TextButton(onPressed: busy ? null : recover, child: const Text('Recover retained transfer')),
            const SizedBox(height: 16),
            const Text('Transfer history'),
            if (rows[2].isEmpty) const Text('No transfers in this branch.'),
            for (final t in rows[2]) ListTile(
              title: Text('${rows[1].firstWhere((p) => p['id'] == t['product_id'], orElse: () => <String, dynamic>{'name': 'Transferred product'})['name']} · ${t['quantity']} units'),
              subtitle: Text('${t['status']} · Received ${t['received']}\n${t['reason']}'),
              trailing: t['status'] == 'in_transit' && t['destination_branch'] == branch
                ? TextButton(onPressed: busy || !enabled ? null : () => receive(t), child: const Text('Receive')) : null,
            ),
          ]);
        }),
  );
  @override
  void dispose() { quantity.dispose(); reason.dispose(); super.dispose(); }
}
