import 'package:flutter/material.dart';

abstract final class TrexvenFontSize {
  static const double caption = 12;
  static const double body = 14;
  static const double input = 16;
  static const double section = 18;
  static const double title = 24;
  static const double display = 30;
  static const double hero = 40;
}

abstract final class TrexvenSpacing {
  static const double labelGap = 8;
  static const double fieldGap = 16;
  static const double sectionGap = 24;
  static const double pageTitle = 24;
  static const double buttonHeight = 48;
  static const double quantityTarget = 56;
  static const pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
  static const cardPadding = EdgeInsets.all(16);
  static const fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
}

abstract final class TrexvenRadii {
  static const double field = 14;
  static const double card = 16;
  static const double dialog = 20;
  static const double status = 8;
  static const double progress = 6;
  static const double pill = 999;
}

abstract final class TrexvenTypography {
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const input = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
  static const body = TextStyle(fontSize: 14, height: 1.45);
  static const caption = TextStyle(fontSize: 12, height: 1.4);
  static const section = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const title = TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
  static const display = TextStyle(fontSize: 30, fontWeight: FontWeight.w700);
}

@immutable
class TrexvenColors extends ThemeExtension<TrexvenColors> {
  final Color? brandBlue,
      brandDark,
      success,
      warning,
      error,
      border,
      muted,
      cardBackground;
  const TrexvenColors({
    required this.brandBlue,
    required this.brandDark,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
    required this.muted,
    required this.cardBackground,
  });
  @override
  TrexvenColors copyWith({
    Color? brandBlue,
    Color? brandDark,
    Color? success,
    Color? warning,
    Color? error,
    Color? border,
    Color? muted,
    Color? cardBackground,
  }) => TrexvenColors(
    brandBlue: brandBlue ?? this.brandBlue,
    brandDark: brandDark ?? this.brandDark,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    border: border ?? this.border,
    muted: muted ?? this.muted,
    cardBackground: cardBackground ?? this.cardBackground,
  );
  @override
  TrexvenColors lerp(covariant TrexvenColors? other, double t) => other == null
      ? this
      : TrexvenColors(
          brandBlue: Color.lerp(brandBlue, other.brandBlue, t),
          brandDark: Color.lerp(brandDark, other.brandDark, t),
          success: Color.lerp(success, other.success, t),
          warning: Color.lerp(warning, other.warning, t),
          error: Color.lerp(error, other.error, t),
          border: Color.lerp(border, other.border, t),
          muted: Color.lerp(muted, other.muted, t),
          cardBackground: Color.lerp(cardBackground, other.cardBackground, t),
        );
}

extension TrexvenThemeData on ThemeData {
  TrexvenColors get trexvenColors =>
      extension<TrexvenColors>() ??
      TrexvenColors(
        brandBlue: colorScheme.primary,
        brandDark: colorScheme.onSurface,
        success: const Color(0xFF16834A),
        warning: const Color(0xFFB76A0A),
        error: colorScheme.error,
        border: colorScheme.outlineVariant,
        muted: colorScheme.onSurfaceVariant,
        cardBackground: colorScheme.surface,
      );
}

extension TrexvenContext on BuildContext {
  ThemeData get trexvenTheme => Theme.of(this);
}
