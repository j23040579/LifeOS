import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

import '../../support/credentials.dart';

void main() {
  testWidgets('create a real task and reload the local workspace', (
    tester,
  ) async {
    final database = WorkspaceDatabase(NativeDatabase.memory());
    final store = Workspace(database);
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
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'A persistent priority',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('A persistent priority'), findsOneWidget);
    final reloaded = Workspace(database);
    await reloaded.load();
    expect(reloaded.tasks.single.title, 'A persistent priority');
    await tester.pumpWidget(const SizedBox.shrink());
    reloaded.dispose();
    store.dispose();
    await database.close();
  });
}
