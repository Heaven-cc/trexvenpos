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

    if (authState.employee == null) {
      home = LoginScreen();
    } else if (authState.activeBusiness == null) {
      home = BusinessLoadingScreen();
    } else if (authState.offlineCashOnly) {
      home = PendingSaleGate(child: OfflineCashScreen());
    } else {
      home = PendingSaleGate(child: BranchGate(child: PosShell()));
    }

    return MaterialApp(
      title: 'Trexven POS',
      debugShowCheckedModeBanner: false,

      themeMode: ref.watch(posThemeProvider),
      darkTheme: PosThemeData.dark,
      // POS-owned theme. Shared workflow presentation is opt-in below.
      theme: PosThemeData.light,
      builder: (context, child) => TrexvenPresentation.pos(premiumGradient: PosThemeData.premiumGradient, child: child!),

      home: home,
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
