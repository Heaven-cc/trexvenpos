import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'operations_client.dart';

class NotificationCenterScreen extends StatefulWidget {
  final OperationsClient api;
  final String? branchId;
  final bool posScoped;
  final bool Function()? contextIsCurrent;
  final void Function(BuildContext context, String route, String? referenceId)
  open;
  const NotificationCenterScreen({
    super.key,
    required this.api,
    required this.open,
    this.branchId,
    this.posScoped = false,
    this.contextIsCurrent,
  });
  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late Future<List<Map<String, dynamic>>> rows;
  late String? user;
  bool busy = false;
  String? error;
  String _posFilter = 'all';
  StreamSubscription<AuthState>? accountChanges;
  Timer? refreshTimer;
  bool get current => mounted && widget.api.client.auth.currentUser?.id == user && (widget.contextIsCurrent?.call() ?? true);
  @override
  void initState() {
    super.initState();
    user = widget.api.client.auth.currentUser?.id;
    accountChanges = widget.api.client.auth.onAuthStateChange.listen((_) {
      if (mounted && !current) {
        setState(() {
          rows = Future.value([]);
          error = null;
        });
      }
    });
    rows = load();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (current && !busy && ModalRoute.of(context)?.isCurrent == true) setState(() => rows = load());
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    accountChanges?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (user == null || !current) {
      throw StateError('Original authenticated account required.');
    }
    final result = <Map<String, dynamic>>[];
    // Bounded pages; no broad direct table access or Vision endpoint in POS.
    for (var offset = 0; offset < 1000; offset += 100) {
      final page =
          await widget.api.call(widget.posScoped ? 'get_pos_notifications' : 'get_trexven_notifications', {
                'p_business_id': widget.api.businessId,
                if (!widget.posScoped) 'p_application': widget.api.application,
                if (widget.posScoped) 'p_branch_id': widget.branchId,
                'p_offset': offset,
              }).timeout(const Duration(seconds: 20))
              as List;
      if (!current) {
        throw StateError('Account changed during notification refresh.');
      }
      result.addAll(page.map((row) => Map<String, dynamic>.from(row as Map)));
      if (page.length < 100) break;
    }
    return result;
  }

  Future<void> mark(Map<String, dynamic> row) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!current)
        throw StateError('Account changed.');
      await widget.api.call(widget.posScoped ? 'mark_pos_notification_read' : 'mark_trexven_notification_read', {
        'p_business_id': widget.api.businessId,
        'p_alert_key': row['alert_key'],
        'p_read': row['read_at'] == null,
        if (!widget.posScoped) 'p_application': widget.api.application,
        if (widget.posScoped) 'p_branch_id': widget.branchId,
      });
      if (mounted) setState(() => rows = load());
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Read status was not confirmed. Refresh current access before retrying.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Open the entire message first. Navigation to a related workflow is optional.
  /// This keeps notifications readable when the route is restricted or absent.
  Future<void> _readMessage(Map<String, dynamic> row) async {
    if (!current || busy) return;
    final title = (row['title']?.toString() ?? 'Notification').trim();
    final message = (row['message']?.toString() ?? '').trim();
    final route = row['route']?.toString() ?? '';
    final referenceId = row['reference_id']?.toString();
    if (row['read_at'] == null) unawaited(mark(row));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title.isEmpty ? 'Notification' : title,
                  style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 12),
                SelectableText(message.isEmpty ? 'No further message details were supplied.' : message,
                  style: Theme.of(sheetContext).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                  if (route.isNotEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open related'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (current) widget.open(context, route, referenceId);
                      },
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _dismiss(Map<String, dynamic> row) async {
    if (busy || !current || !widget.posScoped) return false;
    setState(() { busy = true; error = null; });
    try {
      await widget.api.call('dismiss_pos_notification', {
        'p_business_id': widget.api.businessId,
        'p_alert_key': row['alert_key'],
        'p_branch_id': widget.branchId,
      }).timeout(const Duration(seconds: 20));
      return true;
    } catch (_) {
      if (mounted) setState(() => error =
        'Could not delete the notification. Your message is unchanged; retry while connected.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool _isPriority(Map<String, dynamic> row) {
    final priority = (row['priority'] ?? row['severity'])?.toString().toLowerCase();
    final key = row['alert_key']?.toString() ?? '';
    return key.startsWith('cash_review:') || key.startsWith('inventory_review:') || key.startsWith('credit_approval:') || priority == 'high' || priority == 'critical' ||
        priority == 'urgent' || priority == 'priority';
  }

  Widget _posNotifications(List<Map<String, dynamic>> notifications) {
    final scheme = Theme.of(context).colorScheme;
    final unread = notifications.where((row) => row['read_at'] == null).length;
    final visible = notifications.where((row) {
      if (_posFilter == 'unread') return row['read_at'] == null;
      if (_posFilter == 'priority') return _isPriority(row);
      return true;
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs your attention', style: TextStyle(
                  color: scheme.onPrimaryContainer, fontSize: 13)),
                const SizedBox(height: 6),
                Text('$unread unread', style: TextStyle(
                  color: scheme.onPrimaryContainer, fontSize: 24,
                  fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Operational updates for your business',
                  style: TextStyle(color: scheme.onPrimaryContainer,
                    fontSize: 12)),
              ],
            )),
            Icon(Icons.notifications_active_outlined, size: 30,
              color: scheme.onPrimaryContainer),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          for (final option in const [
            ('all', 'All'), ('unread', 'Unread'), ('priority', 'Priority')
          ]) ...[
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(option.$2),
                selected: _posFilter == option.$1,
                onSelected: (_) => setState(() => _posFilter = option.$1),
              ),
            )),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Recent updates',
            style: TextStyle(fontWeight: FontWeight.w700))),
          Text('${visible.length} notifications',
            style: TextStyle(fontSize: 12,
              color: scheme.onSurfaceVariant)),
        ]),
        if (error != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(error!, style: TextStyle(color: scheme.error))),
        if (busy) const LinearProgressIndicator(),
        if (visible.isEmpty) Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(children: [
            Icon(Icons.notifications_none_rounded, size: 34,
              color: scheme.primary),
            const SizedBox(height: 12),
            Text(_posFilter == 'unread' ? 'No unread notifications'
              : _posFilter == 'priority' ? 'No priority notifications'
              : 'No notifications'),
            const SizedBox(height: 4),
            Text('Updates will appear here when available.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
        ),
        for (final row in visible) Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Dismissible(
            key: ValueKey('pos-notification-${row['alert_key']}'),
            direction: DismissDirection.endToStart,
            dismissThresholds: const {DismissDirection.endToStart: 0.5},
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                const SizedBox(width: 6),
                Text('Delete', style: TextStyle(color: scheme.onErrorContainer)),
              ]),
            ),
            confirmDismiss: (_) => _dismiss(row),
            onDismissed: (_) {
              if (mounted && current) setState(() => rows = load());
            },
            child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(_isPriority(row)
                    ? Icons.priority_high_rounded
                    : Icons.notifications_outlined,
                    color: scheme.onPrimaryContainer)),
                title: Row(children: [
                  Expanded(child: Text(row['title']?.toString() ?? 'Update',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (row['read_at'] == null)
                    Icon(Icons.circle, size: 8, color: scheme.primary),
                ]),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(row['message']?.toString() ?? ''),
                ),
                onTap: busy ? null : () => unawaited(_readMessage(row)),
                trailing: IconButton(
                  tooltip: row['read_at'] == null ? 'Mark read' : 'Mark unread',
                  onPressed: busy ? null : () => mark(row),
                  icon: Icon(row['read_at'] == null
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined),
                ),
              ),
            ),
          ),
          ),
        ),
        if (notifications.length == 1000) const Text('Showing the latest 1,000 authorized updates.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!current) {
      return Scaffold(
        body: Center(
          child: Text(
            'Sign in with the original account or reopen notifications.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: busy ? null : () => setState(() => rows = load()),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (context, state) {
          if (state.hasError && TrexvenPresentation.isPos(context))
            return Center(child: TrexvenErrorState(
              message: 'Notifications unavailable. Check your connection and current access.',
              onRetry: () => setState(() => rows = load())));
          if (state.hasError)
            return Center(
              child: Text(
                'Notifications unavailable. Current access must be verified online.',
              ),
            );
          if (!state.hasData) return Center(child: TrexvenLoading());
          if (TrexvenPresentation.isPos(context)) {
            return _posNotifications(state.data!);
          }
          return ListView(
            children: [
              Padding(
                padding: TrexvenSpacing.cardPadding,
                child: Text(
                  'Updates for your business. Tap a notification to view its details.',
                ),
              ),
              if (error != null)
                Padding(
                  padding: TrexvenSpacing.cardPadding,
                  child: Text(error!),
                ),
              if (busy) LinearProgressIndicator(),
              if (state.data!.isEmpty)
                TrexvenPresentation.isPos(context)
                    ? const TrexvenEmptyState(title: 'No notifications', message: 'New operational updates will appear here.', icon: Icons.notifications_none_rounded)
                    : ListTile(title: Text('No current notifications.')),
              for (final row in state.data!)
                ListTile(
                  title: Text(row['title'] as String),
                  subtitle: Text(
                    '${row['message']}\n${row['read_at'] == null ? 'Unread' : 'Read'}',
                  ),
                  onTap: busy
                      ? null
                      : () {
                          if (current) {
                            widget.open(
                              context,
                              row['route'] as String,
                              row['reference_id'] as String?,
                            );
                          }
                        },
                  trailing: IconButton(
                    tooltip: row['read_at'] == null
                        ? 'Mark read'
                        : 'Mark unread',
                    onPressed: busy ? null : () => mark(row),
                    icon: Icon(
                      row['read_at'] == null
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
