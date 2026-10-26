import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/analytics.dart';

void main() {
  Map<String, dynamic> row(
    String provider,
    String session,
    int day,
    num? weight, {
    String type = 'normal',
  }) => {
    'kind': 'workout',
    'source': provider,
    'session': session,
    'exercise': 'Press',
    'start': DateTime.utc(2026, 10, day).toIso8601String(),
    'weightKg': weight,
    'reps': 10,
    'setType': type,
  };
  test('training isolates providers, excludes warmups, and reports incomplete volume', () {
    final summaries = trainingSummary([
      row('Hevy', 'a', 1, 20),
      row('Hevy', 'b', 2, 22),
      row('Hevy', 'b', 2, 10, type: 'warmup'),
      row('Other', 'a', 1, null),
    ]);
    expect(summaries.length, 2);
    expect(summaries.first.sets, 2);
    expect(summaries.first.sessions, 2);
    expect(summaries.first.volumeKgReps, 420);
    expect(summaries.first.latestLoadKg, 22);
    expect(summaries.last.volumeKgReps, isNull);
  });
  test('nutrition never invents absent nutrients or missing days', () {
    final days = nutritionSummary([
      {
        'kind': 'nutrition',
        'date': '2026-10-01',
        'calories': 100,
        'carbs': 5,
        'protein': null,
        'fat': 2,
        'partial': true,
      },
      {
        'kind': 'nutrition',
        'date': '2026-10-01',
        'calories': 200,
        'carbs': 10,
        'protein': 20,
        'fat': 3,
        'partial': false,
      },
    ]);
    expect(days.length, 1);
    expect(days.single.calories, 300);
    expect(days.single.carbs, 15);
    expect(days.single.protein, isNull);
    expect(days.single.partial, isTrue);
  });
  test(
    'approved aliases combine only one provider and preserve source rows',
    () {
      final original = row('Hevy', 'a', 1, 20);
      final renamed = {...row('Hevy', 'b', 2, 22), 'exercise': 'Bench Press'};
      final summaries = trainingSummary([
        original,
        renamed,
        row('Other', 'a', 1, 30),
        {
          'kind': 'exercise_alias',
          'provider': 'Hevy',
          'exercise': 'Press',
          'canonical': 'Bench Press',
        },
      ]);
      expect(summaries.length, 2);
      expect(summaries.first.exercise, 'Bench Press');
      expect(summaries.first.sessions, 2);
      expect(summaries.first.volumeKgReps, 420);
      expect(summaries.last.provider, 'Other');
      expect(summaries.last.exercise, 'Press');
      expect(original['exercise'], 'Press');
      expect(renamed['exercise'], 'Bench Press');
    },
  );
  test('legacy provider fallback can be mapped explicitly', () {
    final legacy = row('Hevy', 'a', 1, 20)..remove('source');
    final summary = trainingSummary([
      legacy,
      {
        'kind': 'exercise_alias',
        'provider': 'Imported',
        'exercise': 'Press',
        'canonical': 'Chest press',
      },
    ]).single;
    expect(summary.provider, 'Imported');
    expect(summary.exercise, 'Chest press');
    expect(legacy.containsKey('source'), false);
  });
  test(
    'food completeness overrides can mark a source-complete day partial',
    () {
      final food = {
        'kind': 'nutrition',
        'date': '2026-10-01',
        'calories': 120,
        'partial': false,
      };
      expect(nutritionSummary([food]).single.partial, false);
      expect(
        nutritionSummary([
          food,
          {'kind': 'nutrition_day', 'date': '2026-10-01', 'complete': false},
        ]).single.partial,
        true,
      );
      final confirmed = nutritionSummary([
        {...food, 'partial': true},
        {'kind': 'nutrition_day', 'date': '2026-10-01', 'complete': true},
      ]).single;
      expect(confirmed.partial, false);
      expect(confirmed.protein, isNull);
    },
  );
  test('period averages exclude missing dates and retain unknown macros', () {
    final period = nutritionPeriod(
      [
        const NutritionSummary('2026-10-01', 1000, 100, 20, 60, true),
        const NutritionSummary('2026-10-03', 2000, 200, null, 100, false),
        const NutritionSummary('2026-11-01', 4000, 400, 80, 120, false),
      ],
      DateTime.utc(2026, 10),
      DateTime.utc(2026, 11),
    );
    expect(period.days.length, 2);
    expect(period.missingDays, 29);
    expect(period.completeDays, 1);
    expect(period.recordedCalories, 3000);
    expect(period.recordedDayAverage, 1500);
    expect(period.macro('protein'), 160);
    expect(period.macro('fat'), isNull);
    final empty = nutritionPeriod(
      [],
      DateTime.utc(2026),
      DateTime.utc(2026, 1, 8),
    );
    expect(empty.recordedCalories, isNull);
    expect(empty.recordedDayAverage, isNull);
    expect(empty.missingDays, 7);
    expect(
      () => nutritionPeriod([], DateTime.utc(2026), DateTime.utc(2025)),
      throwsArgumentError,
    );
  });
}
