import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/design/design_tokens.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
    final feedback = brightness == Brightness.dark
        ? LifeFeedback.dark
        : LifeFeedback.light;

    group(brightness.name, () {
      for (final background in [p.canvas, p.surface, p.raised]) {
        test('essential text and control contrast on $background', () {
          expect(contrast(p.text, background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.secondary, background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.outline, background), greaterThanOrEqualTo(3));
        });
      }

      test('feedback text has AA contrast on its designated surface', () {
        for (final pair in [
          (p.error, p.errorSurface),
          (feedback.warning, feedback.warningSurface),
          (feedback.success, feedback.successSurface),
          (feedback.info, feedback.infoSurface),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
      });
    });
  }

  test('primary button labels have AA contrast', () {
    expect(
      contrast(DesignTokens.onBrand, DesignTokens.brand),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('crimson cannot serve as dark-theme body text or a lone boundary', () {
    expect(contrast(DesignTokens.brand, Palette.dark.canvas), lessThan(4.5));
    expect(contrast(DesignTokens.brand, Palette.dark.surface), lessThan(3));
    expect(contrast(DesignTokens.brand, Palette.dark.raised), lessThan(3));
  });
}
