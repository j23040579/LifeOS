import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/features/workspace/calendar_timeline.dart';

void main() {
  testWidgets(
    'empty timeline creates local-intent event time; month and week remain navigable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      String? start;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarTimeline(
                clock: ZoneClock(),
                blocks: [],
                initialDate: DateTime.utc(2030, 1, 1),
                onCreate: (value) => start = value,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.bySemanticsLabel('Create event 2030-01-01 09:00');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(start, '2030-01-01 09:00');
      await tester.ensureVisible(find.text('Month'));
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('2030 · Month 1'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('2030 · Month 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Week'));
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('Create event on this day'), findsNWidgets(7));
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
