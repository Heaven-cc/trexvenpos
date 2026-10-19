import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';

class PosOperationHistoryScreen extends ConsumerStatefulWidget {
  const PosOperationHistoryScreen({super.key});
  @override
  ConsumerState<PosOperationHistoryScreen> createState() => _PosOperationHistoryScreenState();
}
class _PosOperationHistoryScreenState extends ConsumerState<PosOperationHistoryScreen> {
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? pending;
  bool busy = false, more = true;
  String? message;
  late final String user, business;
  late final String? branch;
  late final OperationsClient api;
  bool get current => mounted &&
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
  Future<void> load({bool append = false}) async {
    if (!current || busy) return;
    setState(() { busy = true; message = null; });
    try {
      final retained = await api.journal.pending();
      final result = await api.client.rpc('get_pos_operation_history', params: {
        'p_business_id': business, 'p_branch_id': branch, 'p_offset': append ? rows.length : 0,
      }).timeout(const Duration(seconds: 20));
      if (!current) return;
      final page = (result as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      setState(() {
        rows = append ? [...rows, ...page] : page; more = page.length == 100;
        pending = retained != null && retained['user'] == user && retained['business'] == business ? retained : null;
      });
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to verify operational history. Connect and retry.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> recover() async {
    if (!current || busy) return;
    setState(() => busy = true);
    try {
      await api.recoverPending();
      if (mounted) setState(() => message = 'Original operation confirmed. Refresh history.');
    } catch (_) {
      if (mounted) setState(() => message = 'Operation retained. Recheck its original access and recover without repeating money movement.');
    } finally {
      if (mounted) { setState(() => busy = false); await load(); }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Operational history'),
      actions: [IconButton(onPressed: busy ? null : () => load(), icon: const Icon(Icons.refresh))]),
    body: !current ? const Center(child: Text('Reopen history in your authorized branch.')) :
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Your confirmed operational requests in this branch. Sales receipts are in Sales History.'),
        if (message != null) Text(message!),
        if (busy) const LinearProgressIndicator(),
        if (pending != null) ListTile(
          title: const Text('Retained operation'),
          subtitle: Text(CustomerPresentation.label(pending!['rpc'])),
          trailing: TextButton(onPressed: busy ? null : recover, child: const Text('Recover original'))),
        if (!busy && rows.isEmpty) const Text('No confirmed operations in this scope.'),
        for (final row in rows) ListTile(
          title: Text(CustomerPresentation.label(row['operation'])),
          subtitle: Text('${CustomerPresentation.date(row['created_at'], includeTime: true)}\n${row['request_id']}'),
          trailing: const Icon(Icons.check_circle_outline)),
        if (more) TextButton(onPressed: busy ? null : () => load(append: true), child: const Text('Load more')),
      ]),
  );
}
