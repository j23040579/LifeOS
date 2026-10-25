import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/ai_gateway.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

import '../../support/credentials.dart';

void main() {
  testWidgets(
    'AI suggestion stays unapplied until explicit review and applies once',
    (tester) async {
      final db = WorkspaceDatabase(NativeDatabase.memory());
      final store = Workspace(db);
      final gateway = AiGateway(
        Uri.parse('https://gateway.example'),
        'synthetic-access-token',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'text': 'Review this synthetic practice task.',
              'provider': 'mock',
              'model': 'test',
              'live': false,
              'proposal': {
                'type': 'create_task',
                'title': 'Review a queue',
                'minutes': 30,
                'deadline': '2030-01-01T12:00:00Z',
              },
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: WorkspaceShell(
            workspace: store,
            themeMode: ThemeMode.dark,
            onThemeChanged: (_) {},
            initialGateway: gateway,
            credentialStore: MemoryCredentials(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ask AI'));
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Help me practise a queue',
      );
      await tester.ensureVisible(find.text('Send question'));
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();
      expect(store.tasks, isEmpty);
      expect(find.text('DEMO RESPONSE — NOT LIVE AI'), findsOneWidget);
      await tester.ensureVisible(find.text('Review proposed task change'));
      await tester.tap(find.text('Review proposed task change'));
      await tester.pumpAndSettle();
      expect(store.tasks, isEmpty);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(store.tasks.single.title, 'Review a queue');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Proposal applied'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await db.close();
    },
  );
}
