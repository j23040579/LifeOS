import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/planning.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';
import 'package:lifeos/features/workspace/calendar_event_card.dart';

import '../../support/credentials.dart';

void main() {
  for (final mode in ['Day', 'Week', 'Agenda']) {
    testWidgets(
      '$mode: inline checkbox, color save/reload/undo and collapse preserve event times',
      (tester) async {
        final database = WorkspaceDatabase(NativeDatabase.memory()),
            now = DateTime.now().toUtc();
        final store = Workspace(database);
        await store.load();
        final task = PlanTask(
          id: 't',
          title: 'Explain the example',
          minutes: 30,
          deadline: now.add(const Duration(hours: 4)),
        );
        final event = PlanBlock(
          id: 'event',
          title: 'Read and recall',
          start: now,
          end: now.add(const Duration(hours: 1)),
          fixed: true,
          source: 'Imported ICS',
          relatedTaskIds: ['t'],
        );
        await store.change('Seed test', (records) {
          records[task.id] = {...task.toJson(), 'kind': 'task'};
          records[event.id] = {
            ...event.toJson(),
            'kind': 'block',
            'externalId': 'calendar-uid',
          };
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: WorkspaceShell(
              workspace: store,
              themeMode: ThemeMode.dark,
              onThemeChanged: (_) {},
              credentialStore: MemoryCredentials(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plan'));
        await tester.pumpAndSettle();
        if (mode != 'Day') {
          await tester.ensureVisible(find.text(mode));
          await tester.tap(find.text(mode));
          await tester.pumpAndSettle();
        }
        final tile = find.textContaining('Read and recall').first;
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Explain the example'), findsOneWidget);
        final checkbox = find.byWidgetPredicate(
          (w) =>
              w is Checkbox &&
              w.semanticLabel == 'Complete Explain the example',
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(store.tasks.single.state, TaskState.completed);
        await tester.ensureVisible(find.text('Color: Rose'));
        await tester.tap(find.text('Color: Rose'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lavender'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(store.blocks.single.colorId, 'lavender');
        expect(store.snapshot.records['event']!['externalId'], 'calendar-uid');
        final reopened = Workspace(database);
        await reopened.load();
        expect(reopened.blocks.single.colorId, 'lavender');
        reopened.dispose();
        await store.undo();
        await tester.pumpAndSettle();
        expect(store.blocks.single.colorId, 'rose');
        expect(store.blocks.single.start, event.start);
        expect(store.blocks.single.end, event.end);
        final header = find
            .descendant(
              of: find.byType(CalendarEventCard),
              matching: find.text('Read and recall'),
            )
            .first;
        await tester.ensureVisible(header);
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(find.text('Explain the example'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        await database.close();
      },
    );
  }
  testWidgets('color choice in event creation is saved with its local time', (
    tester,
  ) async {
    final database = WorkspaceDatabase(NativeDatabase.memory());
    final store = Workspace(database);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkspaceShell(
          workspace: store,
          themeMode: ThemeMode.light,
          onThemeChanged: (_) {},
          credentialStore: MemoryCredentials(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ocean event');
    await tester.ensureVisible(find.text('Ocean'));
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.blocks.single.colorId, 'ocean');
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    await database.close();
  });
  for (final dark in [false, true])
    testWidgets(
      'expanded event and color picker fit 360px at 200% text (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = Workspace(WorkspaceDatabase(NativeDatabase.memory()));
        await store.load();
        final now = DateTime.now().toUtc();
        final task = PlanTask(
          id: 't',
          title: 'Recall the important details',
          minutes: 30,
          deadline: now.add(const Duration(hours: 2)),
        );
        final event = PlanBlock(
          id: 'e',
          title: 'A longer event title',
          start: now,
          end: now.add(const Duration(hours: 1)),
          relatedTaskIds: ['t'],
          colorId: 'plum',
        );
        await store.change('Seed', (records) {
          records['t'] = {...task.toJson(), 'kind': 'task'};
          records['e'] = {...event.toJson(), 'kind': 'block'};
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: WorkspaceShell(
              workspace: store,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              onThemeChanged: (_) {},
              credentialStore: MemoryCredentials(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plan'));
        await tester.pumpAndSettle();
        final header = find.text('A longer event title').first;
        await tester.ensureVisible(header);
        await tester.tap(header);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Color: Plum'));
        await tester.tap(find.text('Color: Plum'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Teal'));
        await tester.tap(find.text('Teal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(store.blocks.single.colorId, 'teal');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        await store.database.close();
      },
    );
}
