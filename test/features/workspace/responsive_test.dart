import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/sample_workspace.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

import '../../support/credentials.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'all workspace tabs at narrow width and 200% text (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = WorkspaceDatabase(NativeDatabase.memory());
        final store = Workspace(db);
        await store.load();
        await store.change(
          'Seed synthetic test',
          (records) => records.addAll(sampleWorkspace(ZoneClock())),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
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
        for (final title in ['Today', 'Plan', 'Learn', 'Progress', 'Coach']) {
          await tester.tap(find.widgetWithText(NavigationDestination, title));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$title should fit enlarged text',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        await db.close();
      },
    );
  }
}
