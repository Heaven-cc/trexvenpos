import 'package:flutter/material.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

abstract final class PosSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20;
  static const page = EdgeInsets.all(lg);
}

abstract final class PosMotion {
  static const feedback = Duration(milliseconds: 150);
  static const component = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

abstract final class PosThemeData {
  static const blue = Color(0xFF326BF3);
  static const accent = Color(0xFF91B5FF);
  static const premiumGradient = LinearGradient(
    colors: [Color(0xF2284F99), Color(0xF5121F3E)],
    begin: Alignment.topLeft, end: Alignment.bottomRight);
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = TrexvenTheme.build(brightness);
    final background = dark ? const Color(0xFF0C1426) : const Color(0xFFF5F7FC);
    final surface = dark ? const Color(0xFF18243D) : Colors.white;
    final elevated = dark ? const Color(0xFF22314D) : const Color(0xFFEDF2FA);
    final ink = dark ? const Color(0xFFF8FAFC) : const Color(0xFF17233E);
    final muted = dark ? const Color(0xFF9EAECA) : const Color(0xFF64748B);
    final border = dark ? const Color(0xFF344460) : const Color(0xFFDCE3EF);
    final error = dark ? const Color(0xFFFFB4AB) : const Color(0xFFB42318);
    final scheme = base.colorScheme.copyWith(primary: blue, onPrimary: Colors.white,
      secondary: dark ? accent : blue, onSecondary: dark ? background : Colors.white,
      surface: surface, onSurface: ink, onSurfaceVariant: muted,
      surfaceContainerLowest: background, surfaceContainerLow: surface,
      surfaceContainer: elevated, surfaceContainerHigh: elevated,
      surfaceContainerHighest: elevated, outline: border, outlineVariant: border,
      error: error, onError: dark ? background : Colors.white);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final field = OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: border));
    final buttons = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      animationDuration: PosMotion.feedback,
      elevation: const WidgetStatePropertyAll(0));
    return base.copyWith(colorScheme: scheme, scaffoldBackgroundColor: background,
      extensions: [TrexvenColors(brandBlue: blue, brandDark: ink,
        success: dark ? const Color(0xFF82E0AA) : const Color(0xFF157347),
        warning: dark ? const Color(0xFFFFD580) : const Color(0xFF8A5700),
        error: error, border: border, muted: muted, cardBackground: surface)],
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.35, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: ink),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: background, foregroundColor: ink,
        titleTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        iconTheme: IconThemeData(color: ink, size: 22)),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(fillColor: elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: field, enabledBorder: field, disabledBorder: field,
        focusedBorder: field.copyWith(borderSide: const BorderSide(color: blue, width: 1.5)),
        errorBorder: field.copyWith(borderSide: BorderSide(color: error)),
        focusedErrorBorder: field.copyWith(borderSide: BorderSide(color: error, width: 1.5)),
        hintStyle: TextStyle(fontSize: 14, color: muted),
        labelStyle: TextStyle(fontSize: 14, color: muted)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttons.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? elevated : blue),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? muted : Colors.white))),
      filledButtonTheme: FilledButtonThemeData(style: buttons),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttons.copyWith(
        foregroundColor: WidgetStatePropertyAll(dark ? accent : blue),
        side: WidgetStatePropertyAll(BorderSide(color: border)))),
      textButtonTheme: TextButtonThemeData(style: buttons.copyWith(
        foregroundColor: WidgetStatePropertyAll(dark ? accent : blue))),
      cardTheme: base.cardTheme.copyWith(color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
        titleTextStyle: TextStyle(
          color: ink, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(
          color: muted, fontSize: 14, height: 1.4),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: muted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(backgroundColor: surface,
        indicatorColor: blue.withValues(alpha: .16), height: 72,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 22,
          color: s.contains(WidgetState.selected) ? (dark ? accent : blue) : muted)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? (dark ? accent : blue) : muted))),
      chipTheme: base.chipTheme.copyWith(backgroundColor: elevated,
        selectedColor: blue.withValues(alpha: .15), labelStyle: TextStyle(fontSize: 13, color: ink)),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: base.snackBarTheme.copyWith(backgroundColor: ink,
        contentTextStyle: TextStyle(color: background, fontSize: 14)),
      datePickerTheme: base.datePickerTheme.copyWith(backgroundColor: surface),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border)),
        textStyle: TextStyle(color: ink, fontSize: 14),
      ),
      iconTheme: IconThemeData(color: muted, size: 22),
      listTileTheme: base.listTileTheme.copyWith(iconColor: muted, textColor: ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _PosPageTransition(), TargetPlatform.iOS: _PosPageTransition(),
        TargetPlatform.windows: _PosPageTransition(), TargetPlatform.linux: _PosPageTransition(),
        TargetPlatform.macOS: _PosPageTransition(), TargetPlatform.fuchsia: _PosPageTransition()}));
  }
}

class _PosPageTransition extends PageTransitionsBuilder {
  const _PosPageTransition();
  @override
  Duration get transitionDuration => PosMotion.page;
  @override
  Duration get reverseTransitionDuration => PosMotion.page;
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(opacity: animation.drive(CurveTween(curve: PosMotion.curve)), child: child);
  }
}
