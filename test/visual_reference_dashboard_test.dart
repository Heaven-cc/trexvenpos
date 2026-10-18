import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexvenpos/src/features/auth/auth_provider.dart';
import 'package:trexvenpos/src/features/pos/dashboard_screen.dart';
import 'package:trexvenpos/src/features/pos/cart_provider.dart';
import 'package:trexvenpos/src/models/product.dart';
import 'checkout_flow_test.dart' show SignedIn, UnusedClient;
import 'design_system_visual_test.dart' show previewTheme;

void main() {
  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\arial.ttf');
    if (font.existsSync()) {
      for (final family in ['TrexvenPreview', 'Roboto', 'Ahem']) {
        await (FontLoader(
          family,
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    final icons = File(
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  for (final width in [320.0, 340.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('POS actions and cart $width/$scale/$dark fit', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = UnusedClient();
          final cart = CartNotifier();
          final container = ProviderContainer(
            overrides: [
              supabaseProvider.overrideWithValue(client),
              authStateProvider.overrideWith((ref) => SignedIn(client)),
              cartProvider.overrideWith((ref) => cart),
            ],
          );
          final key = GlobalKey();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: previewTheme(
                    dark ? TrexvenTheme.darkTheme : TrexvenTheme.lightTheme,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: const DashboardScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          const folder = String.fromEnvironment('TREXVEN_CAPTURE_DIR');
          if (folder.isNotEmpty && width == 390 && scale == 1) {
            await tester.runAsync(() async {
              final render =
                  key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final picture = await render.toImage();
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(folder).create(recursive: true);
              await File(
                '$folder/pos-dashboard-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
          cart.addProduct(
            const Product(id: 'p', name: 'Brake pad', businessId: 'b'),
            24000,
            'standard',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(container.read(cartProvider).single.quantity, 1);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        });
      }
    }
  }
}
