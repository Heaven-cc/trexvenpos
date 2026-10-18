import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'operations_client.dart';

class NotificationCenterScreen extends StatefulWidget {
  final OperationsClient api;
  final void Function(BuildContext context, String route, String? referenceId)
  open;
  const NotificationCenterScreen({
    super.key,
    required this.api,
    required this.open,
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
  @override
  void initState() {
    super.initState();
    user = widget.api.client.auth.currentUser?.id;
    accountChanges = widget.api.client.auth.onAuthStateChange.listen((_) {
      if (mounted && widget.api.client.auth.currentUser?.id != user) {
        setState(() {
          rows = Future.value([]);
          error = null;
        });
      }
    });
    rows = load();
  }

  @override
  void dispose() {
    accountChanges?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (user == null || widget.api.client.auth.currentUser?.id != user) {
      throw StateError('Original authenticated account required.');
    }
    final result = <Map<String, dynamic>>[];
    // Bounded pages; no broad direct table access or Vision endpoint in POS.
    for (var offset = 0; offset < 1000; offset += 100) {
      final page =
          await widget.api.call('get_trexven_notifications', {
                'p_business_id': widget.api.businessId,
                'p_application': widget.api.application,
                'p_offset': offset,
              })
              as List;
      if (widget.api.client.auth.currentUser?.id != user) {
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
      if (widget.api.client.auth.currentUser?.id != user)
        throw StateError('Account changed.');
      await widget.api.call('mark_trexven_notification_read', {
        'p_business_id': widget.api.businessId,
        'p_alert_key': row['alert_key'],
        'p_read': row['read_at'] == null,
        'p_application': widget.api.application,
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

  bool _isPriority(Map<String, dynamic> row) {
    final priority = (row['priority'] ?? row['severity'])?.toString().toLowerCase();
    return priority == 'high' || priority == 'critical' ||
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
                onTap: busy ? null : () {
                  if (widget.api.client.auth.currentUser?.id == user) {
                    widget.open(context, row['route']?.toString() ?? '',
                      row['reference_id']?.toString());
                  }
                },
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.api.client.auth.currentUser?.id != user) {
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
                          if (widget.api.client.auth.currentUser?.id == user) {
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
