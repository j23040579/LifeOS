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
}
