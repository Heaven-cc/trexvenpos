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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My settings',
              style: TextStyle(
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Account, security & application preferences',
              style: TextStyle(
                fontSize: TrexvenFontSize.caption,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: TrexvenSpacing.cardPadding,
        children: [
          _SectionTitle(title: 'PROFILE INFORMATION'),
          const SizedBox(height: 8),
          _CardContainer(
            children: [
              _SettingRow(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: employee?.name ?? 'Signed out',
              ),
              _SettingRow(
                icon: Icons.badge_outlined,
                title: 'Employee ID',
                subtitle: employee?.employeeCode ?? 'Unavailable',
              ),
              _SettingRow(
                icon: Icons.store_outlined,
                title: 'Business',
                subtitle: auth.activeBusiness?.name ?? 'Unavailable',
              ),
              _SettingRow(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Role',
                subtitle: employee?.role.name ?? 'Unavailable',
              ),
              _SettingRow(
                icon: Icons.contact_mail_outlined,
                title: 'Contact',
                subtitle: employee?.email ??
                    employee?.phone ??
                    'Contact the owner to update your employee details.',
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionTitle(title: 'PREFERENCES & SECURITY'),
          const SizedBox(height: 8),
          _CardContainer(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Change password',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Update your terminal account password'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: auth.offlineCashOnly || employee == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _ChangePassword(),
                        ),
                      ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('System, Light or Dark mode'),
                trailing: PopupMenuButton<ThemeMode>(
                  tooltip: 'Appearance: ${ref.watch(posThemeProvider).name}',
                  icon: const Icon(Icons.palette_outlined),
                  initialValue: ref.watch(posThemeProvider),
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  itemBuilder: (_) => [
                    for (final mode in ThemeMode.values)
                      PopupMenuItem<ThemeMode>(
                        value: mode,
                        child: Text(
                          mode.name[0].toUpperCase() + mode.name.substring(1),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                  onSelected: (mode) async {
                    try {
                      await ref.read(posThemeProvider.notifier).select(mode);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Appearance could not be saved.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Notifications & recovery',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Device sales requiring synchronization or confirmation',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: employee == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _DeviceAlerts(),
                        ),
                      ),
              ),
            ],
          ),
        ],
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
      if (auth.offlineCashOnly || actor == null) {
        throw StateError('Online verification is required.');
      }
      final verified = await client.auth.getUser();
      final email = verified.user?.email;
      if (verified.user?.id != actor || email == null) {
        throw StateError('Original employee identity required.');
      }
      final signedIn = await client.auth.signInWithPassword(
        email: email,
        password: current.text,
      );
      if (signedIn.user?.id != actor ||
          ref.read(authStateProvider).employee?.userId != actor) {
        throw StateError('Account changed during verification.');
      }
      await client.auth.updateUser(UserAttributes(password: next.text));
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
              'Password change was not confirmed. Verify your current password and connection before retrying.',
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
