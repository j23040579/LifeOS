import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/gateway_credentials.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

import '../../support/credentials.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      fail ? 'secure-storage failure leaves offline workspace usable' : 'remembered gateway is restored without network generation and can be forgotten',
      (tester) async {
        final db = WorkspaceDatabase(NativeDatabase.memory());
        final store = Workspace(db);
        final credentials = MemoryCredentials()
          ..value = const GatewayCredentials(
            'https://gateway.example',
            'synthetic-secret-token',
          )
          ..fail = fail;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: WorkspaceShell(
              workspace: store,
              themeMode: ThemeMode.dark,
              onThemeChanged: (_) {},
              credentialStore: credentials,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('New task'), findsOneWidget);
        await tester.tap(find.text('Coach'));
        await tester.pumpAndSettle();
        if (fail) {
          expect(
            find.textContaining('No AI provider connected'),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('not checked this session'),
            findsOneWidget,
          );
          expect(store.export(), isNot(contains('synthetic-secret-token')));
          await tester.ensureVisible(find.text('Disconnect & forget token'));
          await tester.tap(find.text('Disconnect & forget token'));
          await tester.pumpAndSettle();
          expect(credentials.value, isNull);
          expect(
            find.textContaining('No AI provider connected'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        await db.close();
      },
    );
  }
}
