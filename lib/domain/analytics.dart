/// Deterministic summaries of recorded data. Missing observations stay missing.
class ExerciseSummary {
  const ExerciseSummary(
    this.provider,
    this.exercise,
    this.sets,
    this.sessions,
    this.volumeKgReps,
    this.latestLoadKg,
    this.previousLoadKg,
  );
  final String provider, exercise;
  final int sets, sessions;
  final double? volumeKgReps, latestLoadKg, previousLoadKg;
  String get interpretation {
    if (latestLoadKg == null || previousLoadKg == null) {
      return 'Not enough comparable load observations. Keep logging in Hevy.';
    }
    final difference = latestLoadKg! - previousLoadKg!;
    if (difference > 0)
      return 'Latest recorded maximum load is higher. Load alone does not establish better performance; compare reps and technique.';
    if (difference < 0)
      return 'Latest recorded maximum load is lower. This can reflect different reps, equipment, or recovery; review the log before changing the plan.';
    return 'Maximum load is unchanged across the latest two sessions. Compare repetitions before considering a progression.';
  }
}

List<ExerciseSummary> trainingSummary(
  List<Map<String, dynamic>> records, {
  bool includeWarmups = false,
}) {
  final groups = <String, List<Map<String, dynamic>>>{};
  final aliases = {
    for (final alias in records.where((r) => r['kind'] == 'exercise_alias'))
      '${alias['provider']}\u0000${alias['exercise']}':
          alias['canonical'] as String,
  };
  for (final row in records.where((r) => r['kind'] == 'workout')) {
    if (!includeWarmups && row['setType'] == 'warmup') continue;
    final provider = row['source'] ?? 'Imported';
    final canonical =
        aliases['$provider\u0000${row['exercise']}'] ?? row['exercise'];
    final key = '$provider\u0000$canonical';
    groups.putIfAbsent(key, () => []).add({
      ...row,
      'source': provider,
      'exercise': canonical,
    });
  }
  return [for (final rows in groups.values) _exerciseSummary(rows)]..sort(
    (a, b) =>
        '${a.provider}/${a.exercise}'.compareTo('${b.provider}/${b.exercise}'),
  );
}

ExerciseSummary _exerciseSummary(List<Map<String, dynamic>> rows) {
  final sessions = <String, List<Map<String, dynamic>>>{};
  var volume = 0.0, known = 0;
  for (final row in rows) {
    sessions.putIfAbsent(row['session'], () => []).add(row);
    final weight = row['weightKg'], reps = row['reps'];
    if (weight is num && reps is num) {
      volume += weight * reps;
      known++;
    }
  }
  final ordered = sessions.values.toList()
    ..sort(
      (a, b) =>
          DateTime.parse(a.first['start'])
              .compareTo(DateTime.parse(b.first['start'])),
    );
  double? maxLoad(List<Map<String, dynamic>> session) {
    final loads = session.map((r) => r['weightKg']).whereType<num>().toList();
    return loads.isEmpty
        ? null
        : loads.reduce((a, b) => a > b ? a : b).toDouble();
  }

  return ExerciseSummary(
    rows.first['source'] ?? 'Imported',
    rows.first['exercise'],
    rows.length,
    sessions.length,
    known == rows.length ? volume : null,
    maxLoad(ordered.last),
    ordered.length < 2 ? null : maxLoad(ordered[ordered.length - 2]),
  );
}

class NutritionSummary {
  const NutritionSummary(
    this.date,
    this.calories,
    this.carbs,
    this.fat,
    this.protein,
    this.partial,
  );
  final String date;
  final num calories;
  final num? carbs, fat, protein;
  final bool partial;
}

List<NutritionSummary> nutritionSummary(List<Map<String, dynamic>> records) {
  final confirmations = {
    for (final row in records.where((r) => r['kind'] == 'nutrition_day'))
      row['date']: row['complete'] == true,
  };
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in records.where((r) => r['kind'] == 'nutrition')) {
    groups.putIfAbsent(row['date'], () => []).add(row);
  }
  num? sum(List<Map<String, dynamic>> rows, String key) =>
      rows.any((r) => r[key] is! num)
      ? null
      : rows.fold<num>(0, (n, r) => n + (r[key] as num));
  return [
    for (final entry in groups.entries)
      NutritionSummary(
        entry.key,
        sum(entry.value, 'calories')!,
        sum(entry.value, 'carbs'),
        sum(entry.value, 'fat'),
        sum(entry.value, 'protein'),
        confirmations.containsKey(entry.key)
            ? !confirmations[entry.key]!
            : entry.value.any((r) => r['partial'] != false),
      ),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// Periods are calendar dates, not elapsed DST hours. Missing days stay unknown.
class NutritionPeriod {
  const NutritionPeriod(this.days, this.missingDays);
  final List<NutritionSummary> days;
  final int missingDays;
  int get completeDays => days.where((d) => !d.partial).length;
  num? get recordedCalories =>
      days.isEmpty ? null : days.fold<num>(0, (n, d) => n + d.calories);
  double? get recordedDayAverage =>
      days.isEmpty ? null : recordedCalories! / days.length;
  num? macro(String name) {
    if (days.isEmpty) return null;
    final values = days
        .map(
          (d) => switch (name) {
            'protein' => d.protein,
            'carbs' => d.carbs,
            'fat' => d.fat,
            _ => null,
          },
        )
        .toList();
    return values.any((v) => v == null)
        ? null
        : values.fold<num>(0, (n, v) => n + v!);
  }
}

NutritionPeriod nutritionPeriod(
  List<NutritionSummary> days,
  DateTime from,
  DateTime until,
) {
  String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final first = DateTime.utc(from.year, from.month, from.day),
      last = DateTime.utc(until.year, until.month, until.day);
  if (!last.isAfter(first)) throw ArgumentError('Period end must follow start');
  final included = days
      .where(
        (d) =>
            d.date.compareTo(key(first)) >= 0 &&
            d.date.compareTo(key(last)) < 0,
      )
      .toList();
  return NutritionPeriod(
    included,
    (last.difference(first).inDays - included.length).clamp(0, 10000000),
  );
}
