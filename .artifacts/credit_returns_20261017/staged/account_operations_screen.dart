
import 'package:flutter/material.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import 'customer_presentation.dart';
import 'operations_client.dart';

class AccountOperationsScreen extends StatefulWidget {
  final OperationsClient api;

  const AccountOperationsScreen({
    super.key,
    required this.api,
  });

  @override
  State<AccountOperationsScreen> createState() =>
      _AccountOperationsScreenState();
}

class _AccountOperationsScreenState
    extends State<AccountOperationsScreen> {
  late Future<Map<String, dynamic>> health;
  late Future<List<Map<String, dynamic>>> requests;

  bool busy = false;
  String? message;
  bool messageIsError = false;

  static const Color _background = Color(0xFFF5F7FC);
  static const Color _white = Colors.white;
  static const Color _navy = Color(0xFF14213D);
  static const Color _blue = Color(0xFF2864F0);
  static const Color _muted = Color(0xFF71809A);
  static const Color _softBlue = Color(0xFFE8EFFF);
  static const Color _border = Color(0xFFE6EAF2);
  static const Color _red = Color(0xFFD44B52);

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    health = widget.api.call(
      'get_trexven_operational_health',
      {
        'p_business_id': widget.api.businessId,
      },
    ).then(
          (value) => Map<String, dynamic>.from(value as Map),
    );

    requests = widget.api.list(
      'account_lifecycle_requests',
    );
  }

  void _refresh() {
    if (busy) return;
    setState(load);
  }

  Future<void> request(String kind) async {
    if (busy) return;

    final reason = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            kind == 'deletion'
                ? 'Request account deletion'
                : 'Request account recovery',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  kind == 'deletion'
                      ? 'Your deletion request will be reviewed. '
                      'Submitting this request does not immediately '
                      'delete your business or its records.'
                      : 'Your recovery request will be reviewed. '
                      'Your business records and pending sales '
                      'will be kept safe.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TrexvenTextField(
                  controller: reason,
                  decoration:
                  const TrexvenInputDecoration(
                    labelText: 'Reason',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Submit request'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final text = reason.text.trim();

      setState(() {
        busy = true;
        message = null;
      });

      try {
        await widget.api.call(
          'request_trexven_account_lifecycle',
          {
            'p_business_id': widget.api.businessId,
            'p_request_id': widget.api.requestId(),
            'p_kind': kind,
            'p_reason': text,
          },
        );

        if (!mounted) return;

        setState(() {
          message =
          'Owner request recorded. No records were deleted.';
          messageIsError = false;
          load();
        });
      } catch (error) {
        if (!mounted) return;

        setState(() {
          message = CustomerPresentation.error(
            error,
            fallback:
            'Request not confirmed. Please try again.',
          );
          messageIsError = true;
        });
      } finally {
        if (mounted) {
          setState(() => busy = false);
        }
      }
    } finally {
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Account and Recovery',
          style: TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _navy,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (busy) return;
          _refresh();
          try {
            await Future.wait([
              health,
              requests,
            ]);
          } catch (_) {
            // Errors are displayed by the relevant section.
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16, 18, 16, 32,
          ),
          children: [
            _buildHeader(),

            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: _blue,
              ),
            ],

            if (message != null) ...[
              const SizedBox(height: 14),
              _buildMessage(),
            ],

            const SizedBox(height: 20),

            _sectionTitle('Recovery status'),

            const SizedBox(height: 10),

            _buildHealthCard(),

            const SizedBox(height: 22),

            _sectionTitle('Account actions'),

            const SizedBox(height: 10),

            _buildActionCard(
              icon: Icons.restore_rounded,
              title: 'Account recovery',
              description:
              'Request assistance with recovering your business account.',
              actionText: 'Request recovery',
              destructive: false,
              onTap: busy
                  ? null
                  : () => request('recovery'),
            ),

            const SizedBox(height: 10),

            _buildActionCard(
              icon: Icons.delete_outline_rounded,
              title: 'Account deletion',
              description:
              'Submit a deletion request for review. Your data is not deleted immediately.',
              actionText: 'Request deletion',
              destructive: true,
              onTap: busy
                  ? null
                  : () => request('deletion'),
            ),

            const SizedBox(height: 22),

            _sectionTitle('Request history'),

            const SizedBox(height: 10),

            _buildRequestHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage account requests',
          style: TextStyle(
            color: _navy,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Review recovery information and manage account lifecycle requests securely.',
          style: TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _navy,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMessage() {
    final color = messageIsError
        ? _red
        : const Color(0xFF16845A);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            messageIsError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: health,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done &&
            !snapshot.hasData) {
          return _surfaceCard(
            child: const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 12,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: _blue,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _surfaceCard(
            child: const Text(
              'Operational status unavailable. Refresh to try again.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final backup = data['latest_backup'];

        if (backup is! Map) {
          return _surfaceCard(
            child: const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: _muted,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recovery information is not available yet. Contact support if you need help.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _surfaceCard(
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: _blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latest backup',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Status: ${CustomerPresentation.label(backup['status'])}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved: ${CustomerPresentation.date(backup['captured_at'], includeTime: true)}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required bool destructive,
    required VoidCallback? onTap,
  }) {
    final accent = destructive ? _red : _blue;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(
                  color: accent.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(11),
                ),
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHistory() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: requests,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState !=
                ConnectionState.done) {
          return _surfaceCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  color: _blue,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _surfaceCard(
            child: const Text(
              'Unable to load request history.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return _surfaceCard(
            child: const Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: _muted,
                  size: 28,
                ),
                SizedBox(height: 9),
                Text(
                  'No account requests yet',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your recovery and deletion requests will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }

        return _surfaceCard(
          child: Column(
            children: [
              for (var index = 0;
              index < items.length;
              index++) ...[
                _requestItem(items[index]),
                if (index != items.length - 1)
                  const Divider(
                    height: 22,
                    color: _border,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _requestItem(Map<String, dynamic> item) {
    final kind =
    CustomerPresentation.label(item['kind']);
    final status =
    CustomerPresentation.label(item['status']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.description_outlined,
          color: _blue,
          size: 21,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                '$kind · $status',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                CustomerPresentation.date(
                  item['created_at'],
                  includeTime: true,
                ),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                ),
              ),
              if (item['reason'] != null &&
                  item['reason'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  item['reason'].toString(),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _surfaceCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}
