import 'package:flutter/material.dart';

abstract final class DesignTokens {
  static const brand = Color(0xFFC8102E);
  static const onBrand = Color(0xFFF5F2EE);

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space48 = 48.0;

  static const radiusSmall = 8.0;
  static const radiusControl = 12.0;
  static const radiusPanel = 16.0;
  static const compactLimit = 600.0;
  static const expandedStart = 1024.0;
  static const readingWidth = 680.0;
  static const workspaceWidth = 1440.0;
  static const minTarget = 48.0;

  static const micro = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 300);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
}

@immutable
class Palette {
  const Palette({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.text,
    required this.secondary,
    required this.disabled,
    required this.divider,
    required this.outline,
    required this.error,
    required this.errorSurface,
  });

  final Color canvas, surface, raised;
  final Color text, secondary, disabled, divider, outline;
  final Color error, errorSurface;

  static const dark = Palette(
    canvas: Color(0xFF0E0E10),
    surface: Color(0xFF19191C),
    raised: Color(0xFF242428),
    text: Color(0xFFF0E4D5),
    secondary: Color(0xFFBBAEA3),
    disabled: Color(0xFF85817D),
    divider: Color(0xFF38383D),
    outline: Color(0xFF85817D),
    error: Color(0xFFF2BE70),
    errorSurface: Color(0xFF332510),
  );

  static const light = Palette(
    canvas: Color(0xFFF5F2EE),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEAE6E0),
    text: Color(0xFF29231F),
    secondary: Color(0xFF6A5F56),
    disabled: Color(0xFF85817D),
    divider: Color(0xFFD8D2CB),
    outline: Color(0xFF77716B),
    error: Color(0xFF754600),
    errorSurface: Color(0xFFFBE8C8),
  );
}

/// Feedback roles beyond Material's built-in error colors.
@immutable
class LifeFeedback extends ThemeExtension<LifeFeedback> {
  const LifeFeedback({
    required this.warning,
    required this.warningSurface,
    required this.success,
    required this.successSurface,
    required this.info,
    required this.infoSurface,
  });

  final Color warning, warningSurface;
  final Color success, successSurface;
  final Color info, infoSurface;

  static const dark = LifeFeedback(
    warning: Color(0xFFE0A030),
    warningSurface: Color(0xFF332510),
    success: Color(0xFFA8C5AF),
    successSurface: Color(0xFF1A2A21),
    info: Color(0xFFB8C8DA),
    infoSurface: Color(0xFF1C2733),
  );

  static const light = LifeFeedback(
    warning: Color(0xFF805500),
    warningSurface: Color(0xFFFBE8C8),
    success: Color(0xFF315C43),
    successSurface: Color(0xFFE3EEE5),
    info: Color(0xFF365775),
    infoSurface: Color(0xFFE5EDF4),
  );

  @override
  LifeFeedback copyWith({
    Color? warning,
    Color? warningSurface,
    Color? success,
    Color? successSurface,
    Color? info,
    Color? infoSurface,
  }) => LifeFeedback(
    warning: warning ?? this.warning,
    warningSurface: warningSurface ?? this.warningSurface,
    success: success ?? this.success,
    successSurface: successSurface ?? this.successSurface,
    info: info ?? this.info,
    infoSurface: infoSurface ?? this.infoSurface,
  );

  @override
  LifeFeedback lerp(covariant LifeFeedback? other, double t) {
    if (other == null) return this;
    return LifeFeedback(
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
    );
  }
}

/// Warm editorial surfaces and accessible brand-derived foregrounds.
@immutable
class EditorialPalette {
  const EditorialPalette(
    this.featureSurface,
    this.featureText,
    this.brandSurface,
    this.brandText,
  );
  final Color featureSurface, featureText, brandSurface, brandText;
  static const dark = EditorialPalette(
    Color(0xFF2B2220),
    Color(0xFFF0D7C1),
    Color(0xFF342027),
    Color(0xFFF0A6B5),
  );
  static const light = EditorialPalette(
    Color(0xFFEEE3D7),
    Color(0xFF493B30),
    Color(0xFFF6E1E6),
    Color(0xFF951735),
  );
  static EditorialPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
