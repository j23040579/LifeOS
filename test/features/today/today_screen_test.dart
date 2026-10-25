import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app.dart';

void main() {
  testWidgets('completion updates schedule and reset restores sample', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LifeApp());
    expect(find.textContaining('Fictional data'), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete-assignment')));
    await tester.pump();
    expect(find.text('1 of 3 sample priorities complete'), findsOneWidget);
    expect(find.text('✓ Complete'), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete-assignment')));
    await tester.pump();
    expect(find.text('0 of 3 sample priorities complete'), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete-assignment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-sample')));
    await tester.pump();
    expect(find.text('0 of 3 sample priorities complete'), findsOneWidget);
    expect(find.text('✓ Complete'), findsNothing);
  });

  for (final state in ['Loading state', 'Empty state', 'Error state']) {
    testWidgets('$state is available and recoverable', (tester) async {
      await tester.pumpWidget(const LifeApp());
      await tester.tap(find.text('Preview states'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(state));
      await tester.pumpAndSettle();
      expect(find.text('Your priorities'), findsNothing);
      if (state == 'Loading state') {
        expect(find.text('Loading sample day…'), findsOneWidget);
        await tester.tap(find.byKey(const Key('reset-sample')));
      } else {
        final button = find.text(
          state == 'Error state' ? 'Retry sample' : 'Load sample day',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
      }
      await tester.pumpAndSettle();
      expect(find.text('Your priorities'), findsOneWidget);
    });
  }

  for (final appearance in ['Light appearance', 'Dark appearance']) {
    testWidgets('$appearance works at narrow width and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const LifeApp());
      await tester.tap(find.byTooltip('Choose appearance'));
      await tester.pumpAndSettle();
      final menuItem = find.ancestor(
        of: find.text(appearance),
        matching: find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem<ThemeMode>,
        ),
      );
      await tester.ensureVisible(menuItem);
      await tester.tap(menuItem);
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<ThemeMode>), findsNothing);
      expect(
        Theme.of(tester.element(find.text('LifeOS'))).brightness,
        appearance == 'Dark appearance' ? Brightness.dark : Brightness.light,
      );
      final block = find.text('Strength session');
      await tester.scrollUntilVisible(block, 400);
      expect(block, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
