import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trexvenpos/main.dart';
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/pos/employee_settings_screen.dart';
import 'employee_settings_test.dart' show NoNetwork;

class SignedOut extends AuthNotifier {
  SignedOut() : super(NoNetwork(), observeSession: false);
}

ThemeData previewTheme(ThemeData source) {
  ButtonStyle fontStyle(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
              .copyWith(fontFamily: 'TrexvenPreview'),
        ),
      );
  return source.copyWith(
    textTheme: source.textTheme.apply(fontFamily: 'TrexvenPreview'),
    appBarTheme: source.appBarTheme.copyWith(
      titleTextStyle: source.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'TrexvenPreview',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: fontStyle(source.elevatedButtonTheme.style),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: fontStyle(source.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: fontStyle(source.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: fontStyle(source.textButtonTheme.style),
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\arial.ttf');
    if (font.existsSync()) {
      for (final family in ['TrexvenPreview', 'Roboto', 'Ahem', 'monospace']) {
        final loader = FontLoader(family)
          ..addFont(font.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    final icons = File(
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final dark in [false, true]) {
    testWidgets('POS login visual ${dark ? 'dark' : 'light'}', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pos_theme': dark ? 'dark' : 'light',
      });
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [authStateProvider.overrideWith((ref) => SignedOut())],
      );
      addTearDown(container.dispose);
      await container
          .read(posThemeProvider.notifier)
          .select(dark ? ThemeMode.dark : ThemeMode.light);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: UncontrolledProviderScope(
            container: container,
            child: Builder(builder: (context) => const MyApp()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final actualApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: previewTheme(actualApp.theme!),
              darkTheme: previewTheme(actualApp.darkTheme!),
              themeMode: actualApp.themeMode,
              home: actualApp.home,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const folder = String.fromEnvironment('TREXVEN_CAPTURE_DIR');
      if (folder.isNotEmpty) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final picture = await render.toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory(folder).create(recursive: true);
          await File(
            '$folder/pos-login-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    });
  }
}
