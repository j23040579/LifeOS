import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/domain/analytics.dart';

void main() {
  late Workspace store;
  late WorkspaceDatabase database;
  Map<String, dynamic> food(String id, String date) => {
    'id': id,
    'kind': 'nutrition',
    'title': 'A meal',
    'date': date,
    'calories': 400,
    'partial': true,
  };
  setUp(() async {
    database = WorkspaceDatabase(NativeDatabase.memory());
    store = Workspace(database);
    await store.load();
    await store.put(food('food', '2026-10-01'), 'Seed food');
  });
  tearDown(() async {
    store.dispose();
    await database.close();
  });
  Future<void> confirmDay(String date) async {
    expect(
      await store.reviewNutritionDay(
        date: date,
        complete: true,
        expectedRevision: store.snapshot.revision,
      ),
      true,
    );
  }

  for (final operation in ['add', 'edit', 'delete', 'move date']) {
    test(
      '$operation invalidates reviewed food day; undo restores confirmation',
      () async {
        await confirmDay('2026-10-01');
        expect(
          nutritionSummary(store.of('nutrition') + store.of('nutrition_day'))
              .single
              .partial,
          false,
        );
        switch (operation) {
          case 'add':
            await store.put(food('second', '2026-10-01'), 'Another meal');
          case 'edit':
            await store.put({
              ...food('food', '2026-10-01'),
              'calories': 500,
            }, 'Correct meal');
          case 'delete':
            await store.remove('food');
          case 'move date':
            await store.put(food('food', '2026-10-02'), 'Correct date');
        }
        expect(store.of('nutrition_day').single['complete'], false);
        await store.undo();
        expect(store.of('nutrition_day').single['complete'], true);
        expect(store.of('nutrition').single['calories'], 400);
        expect(store.of('nutrition').single['date'], '2026-10-01');
      },
    );
  }
  test(
    'stale review rejects without saving and restore preserves review',
    () async {
      final revision = store.snapshot.revision;
      await store.put(food('new', '2026-10-01'), 'Changed while reviewing');
      final current = store.snapshot.revision;
      expect(
        await store.reviewNutritionDay(
          date: '2026-10-01',
          complete: true,
          expectedRevision: revision,
        ),
        false,
      );
      expect(store.snapshot.revision, current);
      expect(store.of('nutrition_day'), isEmpty);
      await confirmDay('2026-10-01');
      final backup = store.export();
      await store.erase();
      expect(await store.restore(backup), true);
      expect(store.of('nutrition_day').single['complete'], true);
      expect(
        await store.reviewNutritionDay(
          date: '2026-10-02',
          complete: true,
          expectedRevision: store.snapshot.revision,
        ),
        false,
      );
    },
  );
  test(
    'personal targets persist and malformed values are rejected atomically',
    () async {
      final settings = {
        'id': 'settings',
        'kind': 'settings',
        'zone': 'Asia/Kuala_Lumpur',
        'weeklyMinor': 12000,
        'theme': 'dark',
        'nutritionTargets': {'calories': 2100, 'protein': 90.5},
      };
      expect(await store.put(settings, 'Set targets'), true);
      final revision = store.snapshot.revision;
      for (final value in [-1, 0, double.infinity, '2000']) {
        expect(
          await store.put({
            ...settings,
            'nutritionTargets': {'calories': value},
          }, 'Invalid target'),
          false,
        );
        expect(store.snapshot.revision, revision);
      }
      expect(store.snapshot.records['settings']!['weeklyMinor'], 12000);
      expect(store.snapshot.records['settings']!['nutritionTargets'], {
        'calories': 2100,
        'protein': 90.5,
      });
    },
  );
}
