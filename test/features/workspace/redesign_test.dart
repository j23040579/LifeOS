import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/core/design/motion.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/ai_gateway.dart';
import 'package:lifeos/domain/planning.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';
import 'package:lifeos/features/workspace/calendar_timeline.dart';
import 'package:lifeos/features/workspace/calendar_event_card.dart';

import '../../support/credentials.dart';

void main() {
  late Workspace store;
  late WorkspaceDatabase db;
  setUp(() async {
    db = WorkspaceDatabase(NativeDatabase.memory());
    store = Workspace(db);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await db.close();
  });
  Future<void> mount(
    WidgetTester tester, {
    AiGateway? gateway,
    bool reduced = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: WorkspaceShell(
          workspace: store,
          themeMode: ThemeMode.dark,
          onThemeChanged: (_) {},
          credentialStore: MemoryCredentials(),
          initialGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first tap expands tasks inside the calendar and saves a new subtask atomically',
    (tester) async {
      final now = DateTime.now().toUtc();
      final parent = PlanTask(
        id: 'root',
        title: 'Read chapter',
        minutes: 60,
        deadline: now.add(const Duration(hours: 4)),
      );
      final child = PlanTask(
        id: 'child',
        title: 'Recall definitions',
        minutes: 30,
        deadline: parent.deadline,
        parentId: 'root',
      );
      final event = PlanBlock(
        id: 'event',
        title: 'Study session',
        start: now,
        end: now.add(const Duration(hours: 2)),
        fixed: true,
        relatedTaskIds: ['root', 'child'],
      );
      await store.change('Seed event', (records) {
        for (final task in [parent, child])
          records[task.id] = {...task.toJson(), 'kind': 'task'};
        records[event.id] = {...event.toJson(), 'kind': 'block'};
      });
      await mount(tester);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      final tile = find.textContaining('Study session').first;
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CalendarTimeline),
          matching: find.text('Read chapter'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CalendarEventCard), findsOneWidget);
      expect(find.text('Read chapter'), findsOneWidget);
      expect(find.text('Recall definitions'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Task actions: Read chapter'));
      await tester.tap(find.byTooltip('Task actions: Read chapter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add subtask'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Explain the example',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        store.tasks
            .singleWhere((t) => t.title == 'Explain the example')
            .parentId,
        'root',
      );
      expect(store.blocks.single.relatedTaskIds, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final online in [true, false])
    testWidgets(
      online
          ? 'Gemini check-in is labelled and shares aggregates only'
          : 'provider failure displays a local check-in without a paid retry',
      (tester) async {
        final now = DateTime.now().toUtc();
        final task = PlanTask(
          id: 'private',
          title: 'Private task title',
          minutes: 60,
          deadline: now.subtract(const Duration(minutes: 5)),
        );
        await store.put({...task.toJson(), 'kind': 'task'}, 'Seed');
        var calls = 0;
        final gateway = AiGateway(
          Uri.parse('https://gateway.example'),
          'synthetic-access-token',
          client: MockClient((request) async {
            calls++;
            expect(request.body, isNot(contains('Private task title')));
            return online
                ? http.Response(
                    jsonEncode({
                      'text': jsonEncode({
                        'score': 70,
                        'feedback': 'Try one small next step.',
                        'confidence': 'limited',
                      }),
                      'provider': 'gemini',
                      'model': 'synthetic-gemini',
                      'live': true,
                    }),
                    200,
                  )
                : http.Response(
                    jsonEncode({
                      'code': 'gemini_model',
                      'upstreamStatus': 404,
                      'error': 'Untrusted PRIVATE provider error',
                    }),
                    502,
                  );
          }),
        );
        await mount(tester, gateway: gateway);
        await tester.ensureVisible(find.text('Refresh check-in'));
        await tester.tap(find.text('Refresh check-in'));
        await tester.pumpAndSettle();
        expect(find.text('Share this summary with Gemini?'), findsOneWidget);
        expect(calls, 0);
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        if (!online) {
          expect(find.textContaining('Gemini HTTP 404'), findsOneWidget);
          expect(find.textContaining('Untrusted PRIVATE'), findsNothing);
        }
        expect(
          find.textContaining(
            online ? 'Gemini assessment' : 'Local fallback · Gemini',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  testWidgets('reduced motion disables destination and score transitions', (
    tester,
  ) async {
    await mount(tester, reduced: true);
    final motionContext = tester.element(find.byType(DestinationMotion));
    expect(motionDuration(motionContext), Duration.zero);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
