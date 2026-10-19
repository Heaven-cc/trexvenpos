import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/constants.dart';
import 'src/ui/trexven_ui.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/auth/login_screen.dart';
import 'src/features/auth/branch_context.dart';
import 'src/features/pos/pos_shell.dart';
import 'src/features/pos/employee_settings_screen.dart';
import 'src/features/pos/offline_cash_screen.dart';
import 'src/features/pos/pending_sale_provider.dart';
import 'src/services/offline_sync_coordinator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.url,
    publishableKey: SupabaseConstants.anonKey,
  );

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    Widget home;

    if (authState.isLoading && authState.employee == null) {
      home = const BusinessLoadingScreen();
    } else if (authState.employee == null && ref.watch(supabaseProvider).auth.currentSession != null) {
      home = const SessionAccessScreen();
    } else if (authState.employee == null) {
      home = LoginScreen();
    } else if (authState.activeBusiness == null) {
      home = BusinessLoadingScreen();
    } else if (authState.offlineCashOnly) {
      home = PendingSaleGate(child: OfflineCashScreen());
    } else {
      home = PendingSaleGate(child: BranchGate(child: PosShell()));
    }

    return MaterialApp(
      key: ValueKey('pos:${ref.watch(supabaseProvider).auth.currentUser?.id}:${authState.employee?.membershipId}:${authState.activeBusiness?.id}:${authState.offlineCashOnly}'),
      title: 'Trexven POS',
      debugShowCheckedModeBanner: false,

      themeMode: ref.watch(posThemeProvider),
      darkTheme: PosThemeData.dark,
      // POS-owned theme. Shared workflow presentation is opt-in below.
      theme: PosThemeData.light,
      builder: (context, child) => TrexvenPresentation.pos(premiumGradient: PosThemeData.premiumGradient, child: Stack(children: [
        child!,
        if (authState.isLoading) Positioned.fill(child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const Center(child: TrexvenLoading(message: 'Restoring secure session…')))),
      ])),

      home: OfflineSyncCoordinator(child: home),
    );
  }
}

class BusinessLoadingScreen extends StatelessWidget {
  const BusinessLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(child: TrexvenLoading(message: 'Loading your business…')),
    );
  }
}

class SessionAccessScreen extends ConsumerWidget {
  const SessionAccessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify POS access')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(auth.error ?? 'Select your authorized business.'),
        for (final row in auth.contexts) ListTile(
          title: Text((row['business'] as Map)['business_name']?.toString() ?? 'Business'),
          onTap: () => ref.read(authStateProvider.notifier).restoreSession(
            businessId: (row['business'] as Map)['id'] as String)),
        FilledButton(onPressed: () => ref.read(authStateProvider.notifier).restoreSession(),
          child: const Text('Retry access check')),
        TextButton(onPressed: () => ref.read(authStateProvider.notifier).logout(),
          child: const Text('Sign out')),
      ]),
    );
  }
}
