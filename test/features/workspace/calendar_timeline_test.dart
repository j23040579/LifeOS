import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/planning.dart';
import 'package:lifeos/features/workspace/calendar_timeline.dart';

void main() {
  testWidgets(
    'screen-reader activation expands and collapses an inline event',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final event = PlanBlock(
        id: 'e',
        title: 'A calendar event',
        start: DateTime.utc(2030, 1, 1, 9),
        end: DateTime.utc(2030, 1, 1, 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarTimeline(
                clock: ZoneClock('UTC'),
                blocks: [event],
                initialDate: DateTime.utc(2030, 1, 1),
                onCreate: (_) {},
                onOpen: (_) {},
                eventBodyBuilder: (_) => const Text('An inline checklist'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final collapsed = find.bySemanticsLabel(RegExp('^A calendar event,'));
      await tester.ensureVisible(collapsed);
      final node = tester.getSemantics(collapsed);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), true);
      final owner = tester
          .renderObject(find.byType(CalendarTimeline))
          .owner!
          .semanticsOwner!;
      owner.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('An inline checklist'), findsOneWidget);
      final expanded = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Collapse tasks for A calendar event')),
      );
      expect(expanded.getSemanticsData().hasAction(SemanticsAction.tap), true);
      owner.performAction(expanded.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('An inline checklist'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
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
      final dateCell = find.bySemanticsLabel(RegExp('2030-02-01, 0 events'));
      await tester.ensureVisible(dateCell);
      final dateNode = tester.getSemantics(dateCell);
      expect(dateNode.getSemanticsData().hasAction(SemanticsAction.tap), true);
      tester
          .renderObject(find.byType(CalendarTimeline))
          .owner!
          .semanticsOwner!
          .performAction(dateNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('2030 · Month 2'), findsNothing);
      await tester.ensureVisible(find.text('Week'));
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('Create event on this day'), findsNWidgets(7));
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
