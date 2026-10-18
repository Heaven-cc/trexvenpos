import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/pos/employee_settings_screen.dart';
import 'package:trexvenpos/src/models/business.dart';
import 'package:trexvenpos/src/models/employee.dart';

class NoNetwork implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Settings must not make an unrequested network call.');
}

class StaffSession extends AuthNotifier {
  StaffSession({bool offline = false})
    : super(NoNetwork(), observeSession: false) {
    state = AuthState(
      offlineCashOnly: offline,
      activeBusiness: const Business(
        id: 'business',
        ownerId: 'owner',
        name: 'Synthetic shop',
      ),
      employee: const Employee(
        id: 'employee',
        userId: 'user',
        membershipId: 'member',
        employeeCode: 'STAFF',
        name: 'Synthetic staff',
        businessId: 'business',
        role: EmployeeRole.cashier,
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'employee settings show their identity without business ownership or billing controls',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authStateProvider.overrideWith((ref) => StaffSession())],
          child: const MaterialApp(home: EmployeeSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic staff'), findsOneWidget);
      expect(find.text('STAFF'), findsOneWidget);
      expect(find.textContaining('Subscription'), findsNothing);
      expect(find.textContaining('Vision'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
    },
  );
  testWidgets('offline authorization disables password administration', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => StaffSession(offline: true)),
        ],
        child: const MaterialApp(home: EmployeeSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Change password'),
    );
    expect(tile.onTap, isNull);
  });
  test(
    'appearance survives a new controller without storing an identity or touching a journal',
    () async {
      final first = ProviderContainer();
      await first.read(posThemeProvider.notifier).select(ThemeMode.dark);
      first.dispose();
      final second = ProviderContainer();
      await second.read(posThemeProvider.notifier).load();
      expect(second.read(posThemeProvider), ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'pos_theme'});
      second.dispose();
    },
  );
}
