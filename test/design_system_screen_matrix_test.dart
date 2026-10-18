import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trexvenpos/src/features/auth/login_screen.dart';
import 'package:trexvenpos/src/features/inventory/quick_add_screen.dart';
import 'package:trexvenpos/src/models/employee.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'access_boundaries_test.dart' show session;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 340.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('POS priority forms $width/$scale/$dark', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = session(EmployeeRole.owner);
          addTearDown(container.dispose);
          for (final screen in [const LoginScreen(), const QuickAddScreen()]) {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: dark
                      ? TrexvenTheme.darkTheme
                      : TrexvenTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      viewInsets: const EdgeInsets.only(bottom: 280),
                    ),
                    child: child!,
                  ),
                  home: screen,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType}',
            );
            final form = find.byType(Form);
            if (form.evaluate().isNotEmpty) {
              tester.state<FormState>(form).validate();
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }
  }
}
