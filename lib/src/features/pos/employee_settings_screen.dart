import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../auth/auth_provider.dart';
import 'offline_cash_screen.dart';
import 'pending_sale_provider.dart';

final posThemeProvider = StateNotifierProvider<PosTheme, ThemeMode>(
  (ref) => PosTheme(),
);

class PosTheme extends StateNotifier<ThemeMode> {
  PosTheme() : super(ThemeMode.system) {
    load();
  }
  int _generation = 0;
  Future<void> load() async {
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && generation == _generation) {
        state = ThemeMode.values.firstWhere(
          (mode) => mode.name == prefs.getString('pos_theme'),
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {
      // The system appearance remains usable if local preferences are unavailable.
    }
  }

  Future<void> select(ThemeMode mode) async {
    final generation = ++_generation;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('pos_theme', mode.name)) {
      throw StateError('Appearance was not saved.');
    }
    if (mounted && generation == _generation) state = mode;
  }
}

class EmployeeSettingsScreen extends ConsumerWidget {
  const EmployeeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final employee = auth.employee;
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(posThemeProvider);
    final role = employee?.role.name ?? 'Unavailable';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Profile', style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 19)),
            Text('TREXVEN POS - Employee account',
              style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.person_outline, size: 29,
                      color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee?.name ?? 'Signed out',
                        style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('Employee ID: ${employee?.employeeCode ?? 'Unavailable'}',
                        style: TextStyle(fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.verified_user_outlined,
                          color: scheme.primary, size: 15),
                        const SizedBox(width: 5),
                        Flexible(child: Text(role,
                          style: TextStyle(color: scheme.primary,
                            fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                    ],
                  )),
                ]),
                const SizedBox(height: 12),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.store_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACTIVE BUSINESS', style: TextStyle(
                        fontSize: 10, letterSpacing: .7,
                        color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 3),
                      Text(auth.activeBusiness?.name ?? 'Unavailable',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  )),
                  Icon(Icons.check_circle_outline,
                    color: scheme.primary, size: 20),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const TabBar(
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(text: 'Profile'),
                  Tab(text: 'Preferences'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 188,
              child: TabBarView(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionTitle(title: 'ACCOUNT DETAILS'),
                  const SizedBox(height: 8),
                  _CardContainer(children: [
                    _SettingRow(icon: Icons.badge_outlined,
                      title: 'Employee ID',
                      subtitle: employee?.employeeCode ?? 'Unavailable'),
                    _SettingRow(icon: Icons.contact_mail_outlined,
                      title: 'Contact',
                      subtitle: employee?.email ?? employee?.phone ??
                        'Contact the owner to update your details.'),
                  ]),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionTitle(title: 'APPEARANCE'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Theme preference',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: ThemeMode.system,
                                label: Text('System')),
                              ButtonSegment(value: ThemeMode.light,
                                label: Text('Light')),
                              ButtonSegment(value: ThemeMode.dark,
                                label: Text('Dark')),
                            ],
                            selected: {mode},
                            onSelectionChanged: (selected) async {
                              try {
                                await ref.read(posThemeProvider.notifier)
                                  .select(selected.first);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content:
                                      Text('Appearance could not be saved.')));
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(title: 'SECURITY & DEVICE'),
            const SizedBox(height: 8),
            _CardContainer(children: [
              ListTile(
                leading: Icon(Icons.lock_outline, color: scheme.primary),
                title: const Text('Change Password'),
                subtitle: const Text('Protect your employee account'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: auth.offlineCashOnly || employee == null ? null :
                  () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _ChangePassword())),
              ),
              ListTile(
                leading: Icon(Icons.notifications_outlined,
                  color: scheme.primary),
                title: const Text('Notifications & Recovery'),
                subtitle: const Text('Device sales, sync and recovery'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: employee == null ? null :
                  () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DeviceAlerts())),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Employee details and permissions are managed by the business owner.',
              style: TextStyle(fontSize: 12,
                color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: TrexvenFontSize.caption,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final List<Widget> children;
  const _CardContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: TrexvenFontSize.input,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: TrexvenFontSize.body,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();
  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? message;
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (next.text.length < 8 ||
        next.text != confirmation.text ||
        current.text.isEmpty) {
      setState(
        () => message =
            'Enter your current password and matching new passwords of at least eight characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final client = ref.read(supabaseProvider),
          auth = ref.read(authStateProvider);
      final actor = auth.employee?.userId;
      final business = auth.activeBusiness;
      final membership = auth.employee?.membershipId;
      if (auth.offlineCashOnly || actor == null || business == null ||
          auth.employee?.isActive != true) {
        throw StateError('Online verification is required.');
      }
      final response = await client.functions.invoke('change-employee-password',
        body: {
          'business_id': business.id,
          'current_password': current.text,
          'new_password': next.text,
        }).timeout(const Duration(seconds: 45));
      if (!mounted) return;
      final latest = ref.read(authStateProvider);
      if (client.auth.currentUser?.id != actor ||
          latest.employee?.userId != actor ||
          latest.employee?.membershipId != membership ||
          latest.activeBusiness?.id != business.id) {
        throw StateError('Account changed during verification.');
      }
      if (response.status != 200 || response.data is! Map ||
          (response.data as Map)['success'] != true ||
          (response.data as Map)['user_id'] != actor) {
        throw StateError('Password update could not be verified.');
      }
      current.clear();
      next.clear();
      confirmation.clear();
      if (mounted) {
        setState(
          () => message =
              'Password changed. Pending sales and encrypted queues have been retained.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Password change was not confirmed. If the connection was interrupted, the new password may already be active. Do not retry automatically. Re-enter your credentials, or sign in again if secure reauthentication is required.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Change password'),
      elevation: 0,
    ),
    body: ListView(
      padding: TrexvenSpacing.cardPadding,
      children: [
        TrexvenTextField(
          controller: current,
          enabled: !busy,
          obscureText: _obscureCurrent,
          autocorrect: false,
          enableSuggestions: false,
          decoration: TrexvenInputDecoration(
            labelText: 'Current password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscureCurrent ? 'Show current password' : 'Hide current password',
              icon: Icon(
                _obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
          ),
        ),
        TrexvenTextField(
          controller: next,
          enabled: !busy,
          obscureText: _obscureNext,
          autocorrect: false,
          enableSuggestions: false,
          decoration: TrexvenInputDecoration(
            labelText: 'New password (min 8 chars)',
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              tooltip: _obscureNext ? 'Show new password' : 'Hide new password',
              icon: Icon(
                _obscureNext ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscureNext = !_obscureNext),
            ),
          ),
        ),
        TrexvenTextField(
          controller: confirmation,
          gap: 0,
          enabled: !busy,
          obscureText: _obscureConfirm,
          autocorrect: false,
          enableSuggestions: false,
          decoration: TrexvenInputDecoration(
            labelText: 'Confirm new password',
            prefixIcon: const Icon(Icons.check_circle_outline),
            suffixIcon: IconButton(
              tooltip: _obscureConfirm ? 'Show password confirmation' : 'Hide password confirmation',
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (message != null)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: message!.contains('changed')
                  ? Theme.of(context).trexvenColors.success!.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
              border: Border.all(
                color: message!.contains('changed')
                    ? Theme.of(context).trexvenColors.success!
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  message!.contains('changed')
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: message!.contains('changed')
                      ? Theme.of(context).trexvenColors.success!
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      fontSize: TrexvenFontSize.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: TrexvenSpacing.buttonHeight),
          child: ElevatedButton(
            onPressed: busy ? null : save,
            style: Theme.of(context).elevatedButtonTheme.style,
            child: busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    ),
  );
}

class _DeviceAlerts extends ConsumerStatefulWidget {
  const _DeviceAlerts();
  @override
  ConsumerState<_DeviceAlerts> createState() => _DeviceAlertsState();
}

class _DeviceAlertsState extends ConsumerState<_DeviceAlerts> {
  late Future<List<({String id, String label})>> alerts;
  final Set<String> read = {};
  late final String? originalScope;
  String? scope(AuthState auth) {
    final employee = auth.employee, business = auth.activeBusiness;
    return employee == null || business == null
        ? null
        : '${employee.userId}:${business.id}:${employee.membershipId}';
  }

  @override
  void initState() {
    super.initState();
    originalScope = scope(ref.read(authStateProvider));
    alerts = load();
  }

  Future<List<({String id, String label})>> load() async {
    final auth = ref.read(authStateProvider),
        employee = auth.employee,
        business = auth.activeBusiness;
    if (employee == null || business == null) {
      throw StateError('Sign in with the original employee.');
    }
    final actorScope = scope(auth);
    if (actorScope == null || actorScope != originalScope) {
      throw StateError('Original account and business required.');
    }
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('pos_alert_read:$actorScope') ?? [];
    final entries = await (await ref.read(
      offlineCashQueueProvider.future,
    )).entries();
    final pending = await (await ref.read(
      pendingSaleStoreProvider.future,
    )).read();
    if (!mounted || scope(ref.read(authStateProvider)) != originalScope) {
      throw StateError('Account changed during device alert refresh.');
    }
    read
      ..clear()
      ..addAll(readIds);
    return [
      if (pending != null &&
          pending.belongsTo(
            employee.userId,
            business.id,
            employee.membershipId,
          ))
        (
          id: pending.sale.id,
          label:
              'Sale awaiting confirmation. Recover the original request before collecting another payment.',
        ),
      for (final entry in entries)
        if (entry.belongsTo(
              employee.userId,
              business.id,
              employee.membershipId,
            ) &&
            entry.receipt == null)
          (
            id: entry.requestId,
            label:
                'Cash sale pending synchronization. Keep this device and its encrypted queue.',
          ),
    ];
  }

  Future<void> markRead(String id) async {
    final auth = ref.read(authStateProvider),
        e = auth.employee,
        b = auth.activeBusiness;
    if (e == null || b == null || scope(auth) != originalScope) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || scope(ref.read(authStateProvider)) != originalScope) return;
    final next = {...read, id};
    if (await prefs.setStringList(
      'pos_alert_read:${e.userId}:${b.id}:${e.membershipId}',
      next.toList(),
    )) {
      if (mounted && scope(ref.read(authStateProvider)) == originalScope) {
        setState(() {
          read.clear();
          read.addAll(next);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (scope(ref.watch(authStateProvider)) != originalScope) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: TrexvenSpacing.pagePadding,
            child: const Text(
              'Reopen notifications with the original account and business.',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications & recovery'),
        actions: [
          IconButton(
            tooltip: 'Refresh device alerts',
            onPressed: () => setState(() => alerts = load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<({String id, String label})>>(
        future: alerts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: TrexvenSpacing.pagePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Device alerts unavailable',
                      style: TextStyle(
                        fontSize: TrexvenFontSize.section,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pending transactions remain retained. Check this device and retry.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => alerts = load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) return Center(child: TrexvenLoading());
          final data = snapshot.data!;
          return ListView(
            padding: TrexvenSpacing.cardPadding,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'These alerts come from this device’s retained transactions. Marking an alert read does not clear a sale or payment.',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (data.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: Theme.of(context).trexvenColors.success,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All Transactions Clear',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.section,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No pending sales for this employee and business on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final alert in data)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      alert.label,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        read.contains(alert.id) ? 'Status: Read' : 'Status: Unread',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: read.contains(alert.id)
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    onTap: () => markRead(alert.id),
                    trailing: Icon(
                      read.contains(alert.id)
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Open recovery & synchronization'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OfflineCashScreen(),
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
