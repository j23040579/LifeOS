import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/design/app_theme.dart';
import '../../../lib/core/design/design_tokens.dart';

void main() {
  for (final brightness in Brightness.values) {
    final p = brightness == Brightness.dark ? Palette.dark : Palette.light;

    test(
      '${brightness.name}: semantic theme and accessible control defaults',
      () {
        final theme = AppTheme.build(brightness);
        final scheme = theme.colorScheme;
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor, p.canvas);
        expect(scheme.surface, p.surface);
        expect(scheme.onSurface, p.text);
        expect(scheme.onSurfaceVariant, p.secondary);
        expect(scheme.error, p.error);
        expect(scheme.errorContainer, p.errorSurface);
        expect(scheme.primary, DesignTokens.brand);
        expect(scheme.surfaceTint, Colors.transparent);
        expect(theme.extension<LifeFeedback>(), isNotNull);
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        expect(theme.textTheme.bodyLarge!.fontFamily, 'Inter');
        expect(theme.textTheme.bodyLarge!.fontSize, 16);
        expect(theme.textTheme.bodyLarge!.height, 1.5);

        final button = theme.filledButtonTheme.style!;
        expect(button.minimumSize!.resolve({}), const Size(48, 48));
        for (final states in <Set<WidgetState>>[
          {},
          {WidgetState.hovered},
          {WidgetState.focused},
          {WidgetState.pressed},
        ]) {
          expect(button.backgroundColor!.resolve(states), DesignTokens.brand);
          expect(button.foregroundColor!.resolve(states), DesignTokens.onBrand);
          expect(
            button.side!.resolve(states)!.color,
            states.contains(WidgetState.focused) ? p.text : p.outline,
          );
        }
        expect(button.side!.resolve({WidgetState.focused})!.width, 2);
        expect(
          button.backgroundColor!.resolve({WidgetState.disabled}),
          p.raised,
        );
        expect(
          button.foregroundColor!.resolve({WidgetState.disabled}),
          p.disabled,
        );
        expect(
          theme.textButtonTheme.style!.foregroundColor!.resolve({}),
          p.text,
        );

        final input = theme.inputDecorationTheme;
        expect(input.fillColor, p.surface);
        expect(input.errorStyle!.color, p.error);
        expect(
          (input.focusedBorder! as OutlineInputBorder).borderSide.width,
          2,
        );
      },
    );
  }

  test('feedback copies preserve other roles and interpolate all fields', () {
    const dark = LifeFeedback.dark;
    const light = LifeFeedback.light;
    final changed = dark.copyWith(warning: light.warning);
    expect(changed.warning, light.warning);
    expect(changed.success, dark.success);
    expect(changed.infoSurface, dark.infoSurface);
    expect(identical(dark.lerp(null, 0.5), dark), isTrue);

    for (final t in [0.0, 0.5, 1.0]) {
      final mixed = dark.lerp(light, t);
      for (final colors in [
        (mixed.warning, dark.warning, light.warning),
        (mixed.warningSurface, dark.warningSurface, light.warningSurface),
        (mixed.success, dark.success, light.success),
        (mixed.successSurface, dark.successSurface, light.successSurface),
        (mixed.info, dark.info, light.info),
        (mixed.infoSurface, dark.infoSurface, light.infoSurface),
      ]) {
        expect(colors.$1, Color.lerp(colors.$2, colors.$3, t));
      }
    }
  });
}
