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
          if (state.hasError)
            return Center(
              child: Text(
                'Notifications unavailable. Current access must be verified online.',
              ),
            );
          if (!state.hasData) return Center(child: TrexvenLoading());
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
                ListTile(title: Text('No current notifications.')),
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
