import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/gateway_credentials.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

class _SessionOnlyCredentials implements GatewayCredentialStore {
  @override
  bool get supported => false;
  @override
  Future<GatewayCredentials?> read() async => null;
  @override
  Future<void> write(GatewayCredentials credentials) async =>
      throw UnsupportedError('Session only');
  @override
  Future<void> clear() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'create, approve a schedule, undo, and reopen an isolated native database',
    (tester) async {
      final name =
          'lifeos_integration_${DateTime.now().microsecondsSinceEpoch}';
      final database = WorkspaceDatabase.local(name: name);
      final store = Workspace(database);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: WorkspaceShell(
            workspace: store,
            themeMode: ThemeMode.dark,
            onThemeChanged: (_) {},
            credentialStore: _SessionOnlyCredentials(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Integration study task',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.tasks.single.title, 'Integration study task');
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Rebuild my schedule'));
      await tester.tap(find.text('Rebuild my schedule'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        store.blocks,
        isEmpty,
        reason: 'A proposal is not an applied schedule',
      );
      await tester.tap(find.text('Approve changes'));
      await tester.pumpAndSettle();
      expect(store.blocks, isNotEmpty);
      await tester.tap(find.byTooltip('Workspace settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Undo last saved change'));
      await tester.tap(find.text('Undo last saved change'));
      await tester.pumpAndSettle();
      expect(store.blocks, isEmpty);
      expect(store.tasks.single.title, 'Integration study task');
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await database.close();
      final reopened = WorkspaceDatabase.local(name: name);
      final restored = Workspace(reopened);
      await restored.load();
      expect(restored.tasks.single.title, 'Integration study task');
      expect(restored.blocks, isEmpty);
      await restored.erase();
      restored.dispose();
      await reopened.close();
    },
  );
}
