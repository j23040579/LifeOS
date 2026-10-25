import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Approved theme foundation. Component states still need rendered validation.
/// Inter is bundled locally, without runtime font downloads.
abstract final class AppTheme {
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  static TextStyle _type(double size, double line, FontWeight weight) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: line / size,
      fontWeight: weight,
    );
  }

  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? Palette.dark : Palette.light;
    final feedback = isDark ? LifeFeedback.dark : LifeFeedback.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: DesignTokens.brand,
      onPrimary: DesignTokens.onBrand,
      primaryContainer: p.raised,
      onPrimaryContainer: p.text,
      secondary: p.secondary,
      onSecondary: p.canvas,
      secondaryContainer: p.raised,
      onSecondaryContainer: p.text,
      tertiary: feedback.info,
      onTertiary: feedback.infoSurface,
      tertiaryContainer: feedback.infoSurface,
      onTertiaryContainer: feedback.info,
      error: p.error,
      onError: p.errorSurface,
      errorContainer: p.errorSurface,
      onErrorContainer: p.error,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.secondary,
      surfaceContainerLowest: p.canvas,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.raised,
      surfaceContainerHighest: p.raised,
      outline: p.outline,
      outlineVariant: p.divider,
      inverseSurface: isDark ? Palette.light.surface : Palette.dark.surface,
      onInverseSurface: isDark ? Palette.light.text : Palette.dark.text,
      inversePrimary: DesignTokens.brand,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final text = TextTheme(
      displaySmall: _type(52, 58, FontWeight.w500),
      headlineMedium: _type(28, 36, FontWeight.w600),
      titleLarge: _type(20, 28, FontWeight.w600),
      bodyLarge: _type(16, 24, FontWeight.w400),
      bodyMedium: _type(16, 24, FontWeight.w400),
      labelLarge: _type(14, 20, FontWeight.w600),
      bodySmall: _type(12, 18, FontWeight.w400),
    ).apply(bodyColor: p.text, displayColor: p.text);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      fontFamily: 'Inter',
      textTheme: text,
      disabledColor: p.disabled,
      dividerColor: p.divider,
      focusColor: p.text,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [feedback],
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(shape),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? p.raised
                : DesignTokens.brand;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? p.disabled
                : DesignTokens.onBrand;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: states.contains(WidgetState.focused) ? p.text : p.outline,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            );
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          disabledForegroundColor: p.disabled,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          disabledForegroundColor: p.disabled,
          side: BorderSide(color: p.outline),
          minimumSize: const Size(48, 48),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(color: p.secondary),
        hintStyle: TextStyle(color: p.secondary),
        errorStyle: TextStyle(color: p.error),
        contentPadding: const EdgeInsets.all(16),
        border: inputBorder(p.outline),
        enabledBorder: inputBorder(p.outline),
        focusedBorder: inputBorder(p.text, 2),
        errorBorder: inputBorder(p.error),
        focusedErrorBorder: inputBorder(p.error, 2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.text,
        linearTrackColor: p.raised,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.text,
        selectionColor: p.raised,
        selectionHandleColor: p.text,
      ),
    );
  }
}
