import 'package:flutter/material.dart';

/// Opt-in presentation only. Owner and other consumers retain existing defaults.
class TrexvenPresentation extends InheritedWidget {
  final bool compactPos;
  final Gradient? premiumGradient;
  const TrexvenPresentation.pos({super.key, required super.child, this.premiumGradient}) : compactPos = true;
  static Gradient? premiumGradientOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TrexvenPresentation>()?.premiumGradient;
  static bool isPos(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TrexvenPresentation>()?.compactPos ?? false;
  static AnimationStyle? motion(BuildContext context, {bool sheet = false}) =>
      !isPos(context) ? null : AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: sheet ? 250 : 200),
        reverseDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: sheet ? 250 : 200),
        curve: Curves.easeOutCubic);
  static double spacing(BuildContext context, double original) =>
      !isPos(context) || original < 3 ? original
          : ((original / 4).floor() * 4).clamp(4, double.infinity).toDouble();
  static double gap(BuildContext context, double original) =>
      isPos(context) && original == 16 ? 12 : original;
  static double fontSize(BuildContext context, double original) {
    if (!isPos(context)) return original;
    if (original < 12) return 12;
    return switch (original) { 13 => 14, 19 => 20, 21 => 20, 23 || 24 => 22, 30 => 28, _ => original };
  }
  static TextStyle typography(BuildContext context, TextStyle original) =>
      isPos(context) && original.fontSize != null
          ? original.copyWith(fontSize: fontSize(context, original.fontSize!)) : original;
  static Color color(BuildContext context, Color original, String role) {
    if (!isPos(context)) return original;
    final theme = Theme.of(context), c = theme.colorScheme;
    return switch (role) {
      'background' => theme.scaffoldBackgroundColor,
      'surface' => c.surface,
      'ink' => c.onSurface,
      'muted' => c.onSurfaceVariant,
      'brand' => theme.brightness == Brightness.dark ? c.secondary : c.primary,
      'border' => c.outlineVariant,
      'soft' => c.surfaceContainerHighest,
      'success' => theme.brightness == Brightness.dark ? const Color(0xFF82E0AA) : const Color(0xFF157347),
      'warning' => theme.brightness == Brightness.dark ? const Color(0xFFFFD580) : const Color(0xFF8A5700),
      'error' => c.error,
      'successSurface' => (theme.brightness == Brightness.dark ? const Color(0xFF82E0AA) : const Color(0xFF157347)).withValues(alpha: .1),
      'errorSurface' => c.error.withValues(alpha: .1),
      _ => original,
    };
  }
  @override
  bool updateShouldNotify(TrexvenPresentation oldWidget) => compactPos != oldWidget.compactPos || premiumGradient != oldWidget.premiumGradient;
}
