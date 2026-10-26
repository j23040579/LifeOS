import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/core/design/event_colors.dart';
import 'package:lifeos/core/design/design_tokens.dart';

import 'contrast_test.dart' show contrast;

void main() {
  for (final brightness in Brightness.values) {
    test(
      '${brightness.name}: all event palettes have readable names and text',
      () {
        final normal = brightness == Brightness.dark
            ? Palette.dark.text
            : Palette.light.text;
        expect(EventColors.choices.map((c) => c.id).toSet(), hasLength(9));
        for (final colors in EventColors.choices) {
          expect(
            contrast(colors.foreground(brightness), colors.surface(brightness)),
            greaterThanOrEqualTo(4.5),
            reason: colors.name,
          );
          expect(
            contrast(normal, colors.surface(brightness)),
            greaterThanOrEqualTo(4.5),
            reason: 'global button labels on ${colors.name}',
          );
        }
      },
    );
    test(
      '${brightness.name}: buttons stay pill-shaped when pressed, focused, hovered and disabled',
      () {
        final theme = AppTheme.build(brightness);
        for (final state in <Set<WidgetState>>[
          {},
          {WidgetState.pressed},
          {WidgetState.focused},
          {WidgetState.hovered},
          {WidgetState.disabled},
        ]) {
          for (final style in [
            theme.filledButtonTheme.style!,
            theme.outlinedButtonTheme.style!,
            theme.textButtonTheme.style!,
            theme.elevatedButtonTheme.style!,
            theme.segmentedButtonTheme.style!,
          ]) {
            expect(style.shape!.resolve(state), isA<StadiumBorder>());
          }
          expect(
            theme.iconButtonTheme.style!.shape!.resolve(state),
            isA<CircleBorder>(),
          );
        }
        expect(theme.chipTheme.shape, isA<StadiumBorder>());
      },
    );
  }
}
