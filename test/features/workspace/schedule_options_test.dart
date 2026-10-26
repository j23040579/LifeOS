import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/planning.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

import '../../support/credentials.dart';

void main() {
  testWidgets(
    'schedule alternatives remain previews until the chosen one is approved',
    (tester) async {
      final database = WorkspaceDatabase(NativeDatabase.memory());
      final store = Workspace(database);
      await store.load();
      await store.put({
        ...PlanTask(
          id: 't',
          title: 'A practice session',
          minutes: 30,
          deadline: DateTime.now().toUtc().add(const Duration(days: 8)),
        ).toJson(),
        'kind': 'task',
      }, 'Test task');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: WorkspaceShell(
            workspace: store,
            credentialStore: MemoryCredentials(),
            themeMode: ThemeMode.dark,
            onThemeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Plan'));
      await tester.pumpAndSettle();
      Future<void> preview() async {
        await tester.ensureVisible(find.text('Propose a schedule'));
        await tester.tap(find.text('Propose a schedule'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await preview();
      expect(find.textContaining('Deadline first ·'), findsOneWidget);
      expect(find.textContaining('Importance first ·'), findsOneWidget);
      expect(find.textContaining('Spread the work ·'), findsOneWidget);
      expect(store.blocks, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.blocks, isEmpty);
      await preview();
      final choice = find.textContaining('Importance first ·');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(store.blocks, isEmpty);
      await tester.tap(find.text('Approve changes'));
      await tester.pumpAndSettle();
      expect(store.blocks.single.taskId, 't');
      await store.undo();
      expect(store.blocks, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await database.close();
    },
  );
}
