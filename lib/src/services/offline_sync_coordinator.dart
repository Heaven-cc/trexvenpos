import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../features/auth/branch_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';
import '../features/pos/offline_cash_screen.dart';
import '../features/pos/sales_provider.dart';
import '../features/inventory/product_provider.dart';

/// Flushes original cash intents on reconnect/resume. Verified receipts remain
/// encrypted for cashier acknowledgement; failures never delete queued sales.
class OfflineSyncCoordinator extends ConsumerStatefulWidget {
  final Widget child;
  const OfflineSyncCoordinator({super.key, required this.child});
  @override
  ConsumerState<OfflineSyncCoordinator> createState() => _OfflineSyncCoordinatorState();
}
class _OfflineSyncCoordinatorState extends ConsumerState<OfflineSyncCoordinator>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _running = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_sync()));
    Future.microtask(_sync);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }
  Future<void> _sync() async {
    if (!mounted || _running ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) return;
    final auth = ref.read(authStateProvider);
    final employee = auth.employee;
    final business = auth.activeBusiness;
    if (auth.isLoading || auth.offlineCashOnly || employee == null || business == null) return;
    bool current() {
      if (!mounted) return false;
      final value = ref.read(authStateProvider);
      return !value.isLoading && !value.offlineCashOnly &&
          value.employee?.userId == employee.userId &&
          value.employee?.membershipId == employee.membershipId &&
          value.activeBusiness?.id == business.id;
    }
    _running = true;
    try {
      final queue = await ref.read(offlineCashQueueProvider.future);
      final branch = ref.read(branchContextProvider)?.id;
      if (current() && (!business.branchesEnabled || branch != null)) {
        try {
          final device = await queue.store.mutate((state) => state['device_id'] ??= const Uuid().v4());
          if (current()) await ref.read(supabaseProvider).rpc('register_pos_device', params: {
            'p_business_id': business.id, 'p_device_id': device,
            'p_branch_id': branch, 'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          }).timeout(const Duration(seconds: 10));
        } catch (_) { /* Device telemetry must not replace or remove cash intents. */ }
      }
      for (final entry in await queue.entries()) {
        if (!current()) return;
        if (entry.receipt != null ||
            !entry.belongsTo(employee.userId, business.id, employee.membershipId)) continue;
        await queue.synchronize(entry, (original) async {
          if (!current()) throw StateError('Original cash context required.');
          final result = await ref.read(supabaseProvider).rpc(
            original.sale.branchId == null ? 'sync_trexven_offline_cash' : 'sync_pos_branch_offline_cash',
            params: {
              'p_request_id': original.requestId, 'p_ticket': original.ticket,
              'p_items': original.sale.items.map((i) => i.toJson()).toList(),
              'p_total': original.sale.total,
              'p_occurred_at': original.occurredAt.toUtc().toIso8601String(),
            }).timeout(const Duration(seconds: 25));
          return Map<String, dynamic>.from(result as Map);
        });
        if (current()) {
          ref.invalidate(recentSalesProvider);
          ref.invalidate(productSearchProvider);
        }
      }
    } catch (_) {
      // Connectivity, permissions and reconciliation errors retain every intent.
      // The existing Offline Cash screen exposes original requests for review.
    } finally { _running = false; }
  }
  @override
  Widget build(BuildContext context) {
    ref.listen(branchContextProvider, (_, next) { if (next != null) unawaited(_sync()); });
    ref.listen(authStateProvider, (_, next) {
      if (!next.isLoading && !next.offlineCashOnly) unawaited(_sync());
    });
    return widget.child;
  }
  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
