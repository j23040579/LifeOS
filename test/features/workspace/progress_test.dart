import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/core/design/app_theme.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/features/workspace/workspace_shell.dart';

import '../../support/credentials.dart';

void main() {
  late Workspace store;
  late WorkspaceDatabase database;
  setUp(() async {
    database = WorkspaceDatabase(NativeDatabase.memory());
    store = Workspace(database);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await database.close();
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkspaceShell(
          workspace: store,
          credentialStore: MemoryCredentials(),
          themeMode: ThemeMode.light,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Progress'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String title) async {
    final finder = find.text(title);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'targets, completeness and week/month reviews persist without inventing nutrients',
    (tester) async {
      final clock = ZoneClock();
      await store.put({
        'id': 'settings',
        'kind': 'settings',
        'zone': clock.name,
        'weeklyMinor': 15000,
        'theme': 'light',
      }, 'Preferences');
      await store.put({
        'id': 'food',
        'kind': 'nutrition',
        'title': 'Lunch',
        'date': clock.day(clock.now()),
        'calories': 700,
        'partial': true,
      }, 'Food');
      await open(tester);
      await tap(tester, 'Nutrition targets');
      await tester.enterText(find.byType(TextFormField).at(0), '2200');
      await tester.enterText(find.byType(TextFormField).at(1), '100');
      await tap(tester, 'Save');
      expect(store.snapshot.records['settings']!['nutritionTargets'], {
        'calories': 2200,
        'protein': 100,
      });
      expect(store.snapshot.records['settings']!['weeklyMinor'], 15000);
      expect(store.snapshot.records['settings']!['theme'], 'light');
      expect(find.textContaining('Protein unknown g'), findsWidgets);
      await tap(tester, 'Review day completeness');
      await tap(tester, 'Confirm');
      expect(store.of('nutrition_day').single['complete'], true);
      expect(store.of('nutrition').single.containsKey('protein'), false);
      await tap(tester, 'Monthly food');
      expect(
        find.textContaining('Average per recorded day 700 kcal'),
        findsOneWidget,
      );
      await tap(tester, 'Mark as partial');
      await tap(tester, 'Confirm');
      expect(store.of('nutrition_day').single['complete'], false);
      final reopened = Workspace(database);
      await reopened.load();
      expect(reopened.of('nutrition_day').single['complete'], false);
      expect(
        reopened.snapshot.records['settings']!['nutritionTargets']['calories'],
        2200,
      );
      reopened.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'exercise mapping can be reviewed, edited and removed without changing raw sets',
    (tester) async {
      final row = {
        'id': 'set',
        'kind': 'workout',
        'source': 'Hevy',
        'session': 'a',
        'exercise': 'Bench (Barbell)',
        'start': '2026-10-01T08:00:00Z',
        'end': '2026-10-01T09:00:00Z',
        'weightKg': 40,
        'reps': 8,
        'setType': 'normal',
      };
      await store.put(row, 'Synthetic set');
      await open(tester);
      await tap(tester, 'Exercise name mappings');
      await tester.enterText(find.byType(TextFormField), 'Bench press');
      await tap(tester, 'Review mapping');
      expect(store.of('exercise_alias'), isEmpty);
      await tap(tester, 'Confirm');
      expect(store.of('exercise_alias').single['canonical'], 'Bench press');
      expect(find.text('Bench press · Hevy'), findsOneWidget);
      await tap(tester, 'Edit mapping');
      await tester.enterText(find.byType(TextFormField), 'Chest press');
      await tap(tester, 'Review mapping');
      await tap(tester, 'Confirm');
      expect(store.of('exercise_alias').single['canonical'], 'Chest press');
      await tap(tester, 'Remove mapping');
      await tap(tester, 'Confirm');
      expect(store.of('exercise_alias'), isEmpty);
      expect(store.of('workout').single, row);
      expect(find.text('Bench (Barbell) · Hevy'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
