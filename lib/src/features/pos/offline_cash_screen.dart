import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/offline_cash_queue.dart';
import '../../services/offline_cash_unsupported.dart'
    if (dart.library.io) '../../services/offline_cash_file.dart'
    as storage;
import '../../models/product.dart';
import '../auth/auth_provider.dart';
import 'cart_provider.dart';
import 'checkout_screen.dart';

final offlineCashQueueProvider = FutureProvider<OfflineCashQueue>(
  (ref) => storage.createOfflineCashQueue(),
);

class OfflineCashScreen extends ConsumerStatefulWidget {
  const OfflineCashScreen({super.key});
  @override
  ConsumerState<OfflineCashScreen> createState() => _OfflineCashScreenState();
}

class _OfflineCashScreenState extends ConsumerState<OfflineCashScreen> {
  bool busy = false;
  String? message;
  String search = '';
  Future<void> operation(Future<void> Function(OfflineCashQueue) action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action(await ref.read(offlineCashQueueProvider.future));
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

  Future<void> prepare(OfflineCashQueue queue) async {
    final auth = ref.read(authStateProvider);
    final user = auth.employee;
    final business = auth.activeBusiness;
    if (user == null || business == null) throw StateError('Sign in first.');
    if (auth.offlineCashOnly)
      throw StateError('Reconnect and verify access first.');
    if (business.branchesEnabled)
      throw StateError('Offline branch cash workflow is not activated.');
    final device = await queue.store.mutate(
      (state) => state['device_id'] ??= Uuid().v4(),
    );
    if (!mounted) return;
    final shift = await chooseCashShift(
      context,
      OperationsClient.pos(ref.read(supabaseProvider), business.id),
    );
    final ticket = await ref
        .read(supabaseProvider)
        .rpc(
          'issue_trexven_offline_scope',
          params: {
            'p_business_id': business.id,
            'p_device_id': device,
            'p_shift_id': shift,
          },
        );
    await queue.cacheTicket(
      Map<String, dynamic>.from(ticket as Map),
      DateTime.now(),
      authContext: {'employee': user.toJson(), 'business': business.toJson()},
    );
    if (mounted)
      setState(() => message = 'Signed cash catalog saved for up to 24 hours.');
  }

  Future<void> sync(OfflineCashQueue queue, OfflineCashEntry entry) async {
    final auth = ref.read(authStateProvider);
    if (!entry.belongsTo(
      auth.employee?.userId ?? '',
      auth.activeBusiness?.id ?? '',
      auth.employee?.membershipId ?? '',
    )) {
      throw StateError('Use the original employee, business and membership.');
    }
    final receipt = await queue.synchronize(entry, (entry) async {
      final value = await ref
          .read(supabaseProvider)
          .rpc(
            'sync_trexven_offline_cash',
            params: {
              'p_request_id': entry.requestId,
              'p_ticket': entry.ticket,
              'p_items': entry.sale.items.map((i) => i.toJson()).toList(),
              'p_total': entry.sale.total,
              'p_occurred_at': entry.occurredAt.toUtc().toIso8601String(),
            },
          );
      return Map<String, dynamic>.from(value as Map);
    });
    if (!mounted) return;
    final current = ref.read(authStateProvider);
    if (!entry.belongsTo(
      current.employee?.userId ?? '',
      current.activeBusiness?.id ?? '',
      current.employee?.membershipId ?? '',
    ))
      throw StateError('Original user must view this receipt.');
    final acknowledge = await showDialog<bool>(
      animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Synced cash receipt'),
        content: SelectableText(
          'Receipt ${receipt['id']}\nTotal ${receipt['total']}\nStock reconciliation ${receipt['offline_discrepancies']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep for review'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Acknowledge'),
          ),
        ],
      ),
    );
    if (acknowledge == true) {
      final user = ref.read(authStateProvider);
      if (!entry.belongsTo(
        user.employee?.userId ?? '',
        user.activeBusiness?.id ?? '',
        user.employee?.membershipId ?? '',
      ))
        throw StateError('Original context required.');
      await queue.acknowledge(entry.requestId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Cash & Sync')),
    body: ref
        .watch(offlineCashQueueProvider)
        .when(
          loading: () => Center(child: TrexvenLoading()),
          error: (e, s) => Center(
            child: Text(
              CustomerPresentation.error(
                e,
                fallback: 'Encrypted storage unavailable. Please try again.',
              ),
            ),
          ),
          data: (queue) => FutureBuilder<Map<String, dynamic>>(
            future: queue.store.readState(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return Center(
                  child: snapshot.hasError
                      ? Text(
                          'Cannot authenticate cash storage. Preserve the file.',
                        )
                      : CircularProgressIndicator(),
                );
              final state = snapshot.data!;
              final ticket = state['ticket'] as Map?;
              final scope = ticket?['scope'] as Map?;
              final auth = ref.watch(authStateProvider);
              final own =
                  scope?['user_id'] == auth.employee?.userId &&
                  scope?['business_id'] == auth.activeBusiness?.id &&
                  scope?['membership_id'] == auth.employee?.membershipId;
              final products = own ? (scope?['products'] as List? ?? []) : [];
              final entries = (state['entries'] as List? ?? [])
                  .map(
                    (x) => OfflineCashEntry.fromJson(
                      Map<String, dynamic>.from(x as Map),
                    ),
                  )
                  .toList();
              return ListView(
                padding: TrexvenSpacing.cardPadding,
                children: [
                  if (message != null) Text(message!),
                  if (busy) LinearProgressIndicator(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          const Expanded(child: Text(
                            'Cash only. Encrypted requests stay on this device until the server receipt is acknowledged. Transfers, credit and refunds require online access.',
                          )),
                        ],
                      ),
                    ),
                  ),
                  if (auth.offlineCashOnly)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(authStateProvider.notifier)
                                .restoreSession(),
                      child: Text('Reconnect and verify current access'),
                    ),
                  OutlinedButton(
                    onPressed: busy || auth.offlineCashOnly
                        ? null
                        : () => operation(prepare),
                    child: Text('Refresh signed cash catalog online'),
                  ),
                  if (own) Text('Authorization ends ${scope?['expires_at']}'),
                  TrexvenTextField(
                    variant: TrexvenFieldVariant.search,
                    decoration: TrexvenInputDecoration(
                      hintText: 'Search cached name or barcode',
                    ),
                    onChanged: (v) => setState(() => search = v),
                  ),
                  for (final raw in products)
                    if ('${raw['name']} ${raw['barcode'] ?? ''} ${raw['sku'] ?? ''}'
                        .toLowerCase()
                        .contains(search.toLowerCase()))
                      ListTile(
                        title: Text('${raw['name']}'),
                        subtitle: Text('${raw['price']} · ${raw['unit']}'),
                        onTap: busy
                            ? null
                            : () {
                                final p = Product.fromJson({
                                  ...Map<String, dynamic>.from(raw as Map),
                                  'business_id': auth.activeBusiness!.id,
                                  'selling_price': raw['price'],
                                  'quantity': raw['quantity'],
                                  'is_active': true,
                                  'active': true,
                                });
                                ref
                                    .read(cartProvider.notifier)
                                    .addProduct(p, p.sellingPrice!, 'standard');
                                setState(
                                  () =>
                                      message = 'Added ${p.name} to cash cart.',
                                );
                              },
                      ),
                  if (ref.watch(cartProvider).isNotEmpty)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CheckoutScreen(offlineCash: true),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                      child: Text('Cash checkout · Pending Sync'),
                    ),
                  const SizedBox(height: 16),
                  Text('Retained requests', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (!entries.any((e) => e.belongsTo(auth.employee?.userId ?? '',
                      auth.activeBusiness?.id ?? '', auth.employee?.membershipId ?? '')))
                    const TrexvenEmptyState(title: 'No retained cash requests',
                      message: 'Offline cash receipts will remain here until synchronization is confirmed.'),

                  for (final entry in entries.where(
                    (e) => e.belongsTo(
                      auth.employee?.userId ?? '',
                      auth.activeBusiness?.id ?? '',
                      auth.employee?.membershipId ?? '',
                    ),
                  ))
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(entry.receipt == null
                            ? Icons.sync_outlined : Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.primary),
                        title: Text('${entry.sale.total}'),
                        subtitle: Text(entry.receipt == null
                            ? 'Pending synchronization · original request retained'
                            : 'Server receipt verified · acknowledgement required'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: busy || auth.offlineCashOnly
                            ? null
                            : () => operation((q) => sync(q, entry)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
  );
}
