part of 'workspace_shell.dart';

extension _ProgressActions on _WorkspaceShellState {
  Widget _nutritionDashboard() {
    final all = store.snapshot.records.values.toList(),
        days = nutritionSummary(all),
        now = clock.now();
    final start = _nutritionMonth
        ? DateTime.utc(now.year, now.month + _nutritionPeriodOffset, 1)
        : DateTime.utc(
            now.year,
            now.month,
            now.day - now.weekday + 1 + _nutritionPeriodOffset * 7,
          );
    final end = _nutritionMonth
        ? DateTime.utc(start.year, start.month + 1, 1)
        : start.add(const Duration(days: 7));
    final period = nutritionPeriod(days, start, end);
    final targets = Map<String, dynamic>.from(
      store.snapshot.records['settings']?['nutritionTargets'] ?? {},
    );
    String value(num? v) => v?.toStringAsFixed(0) ?? 'unknown';
    String target(String key) => targets[key] == null
        ? 'no target set'
        : 'entered target ${targets[key]}${key == 'calories' ? ' kcal' : ' g'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nutrition', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Weekly food'),
              selected: !_nutritionMonth,
              onSelected: (_) => refresh(() {
                _nutritionMonth = false;
                _nutritionPeriodOffset = 0;
              }),
            ),
            ChoiceChip(
              label: const Text('Monthly food'),
              selected: _nutritionMonth,
              onSelected: (_) => refresh(() {
                _nutritionMonth = true;
                _nutritionPeriodOffset = 0;
              }),
            ),
            IconButton(
              tooltip: 'Previous food period',
              onPressed: () => refresh(() => _nutritionPeriodOffset--),
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(
              onPressed: () => refresh(() => _nutritionPeriodOffset = 0),
              child: const Text('Current period'),
            ),
            IconButton(
              tooltip: 'Next food period',
              onPressed: () => refresh(() => _nutritionPeriodOffset++),
              icon: const Icon(Icons.chevron_right),
            ),
            OutlinedButton(
              onPressed: store.busy ? null : _nutritionTargets,
              child: const Text('Nutrition targets'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        panel(
          line(
            '${clock.day(start)} → ${clock.day(end.subtract(const Duration(days: 1)))}',
            '${period.days.length} recorded days · ${period.completeDays} marked complete · ${period.missingDays} dates without entries\n'
                'Recorded intake ${value(period.recordedCalories)} kcal · Average per recorded day ${value(period.recordedDayAverage)} kcal\n'
                'Recorded protein ${value(period.macro('protein'))} g · Carbs ${value(period.macro('carbs'))} g · Fat ${value(period.macro('fat'))} g\n'
                'Partial days are included as recorded, not full-day estimates. Dates without entries (including future dates) are never zero intake.',
          ),
        ),
        panel(
          line(
            'Your daily targets',
            'Calories: ${target('calories')}\nProtein: ${target('protein')}\nCarbohydrate: ${target('carbs')}\nFat: ${target('fat')}\n'
                'Targets are your own entries, not medical or AI prescriptions. Partial-day intake cannot establish daily adherence.',
          ),
        ),
        if (period.days.isEmpty)
          panel(
            const Text(
              'No food entries in this period. Change the period, import a report, or add an individual food entry.',
            ),
          ),
        if (period.days.isNotEmpty)
          TrendChart(
            title: 'Recorded calories',
            unit: 'kcal',
            source: 'Local food records · completeness reviewed per date',
            points: [
              for (final day in period.days)
                TrendPoint(DateTime.parse(day.date), day.calories.toDouble()),
            ],
          ),
        for (final day in period.days.reversed)
          panel(
            line(
              '${day.date} · ${day.calories} kcal',
              '${day.partial ? 'Partial day' : 'Marked complete'}\n'
                  'Protein ${value(day.protein)} g · Carbs ${value(day.carbs)} g · Fat ${value(day.fat)} g\n'
                  'Calories: ${target('calories')}. Unknown nutrients stay unknown; imported TOTALS are excluded.',
              action: TextButton(
                onPressed: store.busy ? null : () => _reviewFoodDay(day),
                child: Text(
                  day.partial ? 'Review day completeness' : 'Mark as partial',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _nutritionTargets() async {
    final current = Map<String, dynamic>.from(
      store.snapshot.records['settings']?['nutritionTargets'] ?? {},
    );
    final fields = await entryForm(
      context,
      'Your daily nutrition targets',
      [
        for (final key in ['calories', 'protein', 'carbs', 'fat'])
          EntryField(
            key,
            '${key == 'calories'
                ? 'Calories (kcal)'
                : key == 'protein'
                ? 'Protein (g)'
                : key == 'carbs'
                ? 'Carbohydrate (g)'
                : 'Fat (g)'}',
            value: current[key]?.toString() ?? '',
            optional: true,
          ),
      ],
      notice: 'Use targets you chose yourself or received from a qualified professional. Leave a field blank to remove its target.',
      validate: (values) {
        for (final value in values.values) {
          if (value.isEmpty) continue;
          final number = num.tryParse(value);
          if (number == null || !number.isFinite || number <= 0)
            return 'Targets must be finite positive numbers, or blank.';
        }
        return null;
      },
    );
    if (fields == null) return;
    await store.put({
      ...?store.snapshot.records['settings'],
      'id': 'settings',
      'kind': 'settings',
      'zone': clock.name,
      'weeklyMinor': store.snapshot.records['settings']?['weeklyMinor'] ?? 0,
      'nutritionTargets': {
        for (final entry in fields.entries)
          if (entry.value.isNotEmpty) entry.key: num.parse(entry.value),
      },
    }, 'Set personal nutrition targets');
  }

  Future<void> _reviewFoodDay(NutritionSummary day) async {
    if (store.busy) return;
    final revision = store.snapshot.revision;
    if (!await confirm(
      day.partial
          ? 'Confirm this food day is complete?'
          : 'Mark this food day partial?',
      '${day.date}\n${day.calories} recorded kcal.\n\n${day.partial ? 'Confirm only if you recorded all food for this date. Missing nutrient values will still remain unknown.' : 'The entries will remain, but this date will no longer be treated as a complete day.'}\nNew, edited, or removed food records will invalidate this confirmation.',
    ))
      return;
    await store.reviewNutritionDay(
      date: day.date,
      complete: day.partial,
      expectedRevision: revision,
    );
  }

  Future<void> _exerciseAlias([Map<String, dynamic>? alias]) async {
    final choices = <String, String>{};
    for (final row in store.of('workout')) {
      final key = jsonEncode([row['source'] ?? 'Imported', row['exercise']]);
      choices[key] = '${row['source'] ?? 'Imported'} · ${row['exercise']}';
    }
    final originalKey = alias == null
        ? null
        : jsonEncode([alias['provider'], alias['exercise']]);
    if (originalKey != null)
      choices[originalKey] = '${alias!['provider']} · ${alias['exercise']}';
    if (choices.isEmpty) return;
    final fields = await entryForm(
      context,
      'Map an exercise name',
      [
        EntryField(
          'original',
          'Original provider and exercise',
          value: originalKey ?? choices.keys.first,
          choices: choices,
        ),
        EntryField(
          'canonical',
          'Group under this exercise name',
          value: alias?['canonical'] ?? '',
        ),
      ],
      notice: 'Use the same group name to combine known aliases from one provider. Original set rows remain unchanged. Different providers always stay separate.',
      validate: (values) => values['canonical']!.length > 300
          ? 'Use a name up to 300 characters.'
          : null,
      confirm: 'Review mapping',
    );
    if (fields == null) return;
    final original = List<String>.from(jsonDecode(fields['original']!));
    if (!await confirm(
      'Apply this exercise mapping?',
      '${original[0]}\n${original[1]} → ${fields['canonical']}\n\nThis changes analytics labels/grouping only. It does not modify Hevy or your imported set data.',
    ))
      return;
    await store.change('Apply exercise alias', (records) {
      if (alias != null) records.remove(alias['id']);
      final id = 'exercise-alias-${fingerprint(fields['original']!)}';
      records[id] = {
        'id': id,
        'kind': 'exercise_alias',
        'provider': original[0],
        'exercise': original[1],
        'canonical': fields['canonical'],
      };
    });
  }
}
