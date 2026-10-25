part of 'workspace_shell.dart';

extension _ProgressView on _WorkspaceShellState {
  Widget _progress() {
    final workouts = store.of('workout');
    final sessions = workouts.map((r) => r['session']).toSet().length;
    final working = workouts.where((r) => r['setType'] != 'warmup').toList();
    final nutrition = <String, num>{};
    for (final row in store.of('nutrition')) {
      nutrition.update(
        row['date'],
        (value) => value + (row['calories'] as num),
        ifAbsent: () => row['calories'] as num,
      );
    }
    final budget =
        store.snapshot.records['settings']?['weeklyMinor'] as int? ?? 0;
    final now = clock.now();
    final start = DateTime.utc(now.year, now.month, now.day - now.weekday + 1);
    final first = clock.day(start),
        last = clock.day(start.add(const Duration(days: 7)));
    final expenses = store
        .of('expense')
        .where(
          (r) =>
              (r['date'] as String).compareTo(first) >= 0 &&
              (r['date'] as String).compareTo(last) < 0,
        )
        .toList();
    final paid = expenses
        .where((r) => r['paid'] == true)
        .fold<int>(0, (sum, r) => sum + (r['minor'] as int));
    final committed = expenses
        .where((r) => r['paid'] != true)
        .fold<int>(0, (sum, r) => sum + (r['minor'] as int));
    String rm(int minor) => 'RM ${(minor / 100).toStringAsFixed(2)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Progress,\nwith perspective.',
          'Measured, imported, estimated, and missing values stay distinct.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: _import,
              child: const Text('Import your data'),
            ),
            OutlinedButton(
              onPressed: _measurement,
              child: const Text('Add a measurement'),
            ),
            OutlinedButton(
              onPressed: _nutritionEntry,
              child: const Text('Add a food entry'),
            ),
            OutlinedButton(
              onPressed: _expense,
              child: const Text('Add an expense'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        panel(
          line(
            'This week · ${rm(budget - paid - committed)} remaining',
            'Budget ${rm(budget)} · Paid ${rm(paid)} · Committed ${rm(committed)}\nMonday–Sunday · MYR · Amounts calculated in integer sen.',
            action: TextButton(
              onPressed: () => _outing(budget - paid - committed),
              child: const Text('Can an outing fit?'),
            ),
          ),
          feature: true,
        ),
        panel(
          line(
            'Training · $sessions sessions',
            '${working.length} non-warmup set rows · ${workouts.length} total imported rows\nSources: ${workouts.map((r) => r['source'] ?? 'Imported').toSet().join(', ')}. Missing RPE is not inferred.',
          ),
        ),
        for (final summary in trainingSummary(workouts))
          panel(
            line(
              '${summary.exercise} · ${summary.provider}',
              '${summary.sessions} sessions · ${summary.sets} non-warmup set rows\n'
                  'Recorded volume (sum kg × reps): ${summary.volumeKgReps?.toStringAsFixed(0) ?? 'Incomplete — missing load or reps'}\n'
                  'Latest / previous session maximum load: ${summary.latestLoadKg ?? '—'} / ${summary.previousLoadKg ?? '—'} kg\n'
                  '${summary.interpretation}\nSource: imported rows; not a prescribed routine. Missing RPE is not inferred.',
            ),
          ),
        Text('Nutrition', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (nutrition.isNotEmpty)
          TrendChart(
            title: 'Recorded calories',
            unit: 'kcal',
            source: 'MyFitnessPal · Partial days',
            points: [
              for (final e in nutrition.entries)
                TrendPoint(DateTime.parse(e.key), e.value.toDouble()),
            ],
          ),
        if (nutrition.isEmpty)
          panel(
            const Text(
              'No nutrition records. Missing days are not zero-intake days.',
            ),
          ),
        for (final day in nutritionSummary(store.of('nutrition')))
          panel(
            line(
              '${day.date} · ${day.calories} kcal',
              '${day.partial ? 'Partial day' : 'User-confirmed complete'} · Carbs ${day.carbs ?? 'missing'} g · Fat ${day.fat ?? 'missing'} g · Protein ${day.protein ?? 'missing'} g\n'
                  'Item records only. Missing nutrients stay missing; meal TOTALS are excluded.',
            ),
          ),
        Text('Measurements', style: Theme.of(context).textTheme.headlineMedium),
        for (final metric
            in store.of('measurement').map((r) => r['title']).toSet())
          TrendChart(
            title: metric.toString(),
            unit: store
                .of('measurement')
                .firstWhere((r) => r['title'] == metric)['unit'],
            source: 'Manual observations',
            points: [
              for (final r
                  in store.of('measurement').where((r) => r['title'] == metric))
                TrendPoint(
                  DateTime.parse(r['date']),
                  (r['value'] as num).toDouble(),
                ),
            ],
          ),
        for (final r in store.of('measurement'))
          panel(
            line(
              '${r['title']} · ${r['value']} ${r['unit']}',
              '${r['date']} · Manual · Measured',
              action: TextButton(
                onPressed: () => store.remove(r['id']),
                child: const Text('Remove'),
              ),
            ),
          ),
        Text('Transactions', style: Theme.of(context).textTheme.headlineMedium),
        for (final r in store.of('expense'))
          panel(
            line(
              '${r['title']} · ${rm(r['minor'])}',
              '${r['date']} · ${r['category']} · ${r['paid'] == true ? 'Paid' : 'Projected, not paid'}',
              action: TextButton(
                onPressed: () => store.remove(r['id']),
                child: const Text('Remove'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _measurement() async {
    const units = {
      'Weight': 'kg',
      'Neck': 'cm',
      'Waist': 'cm',
      'Hip': 'cm',
      'Steps': 'steps',
      'Sleep': 'hours',
      'Energy': '1–5',
    };
    final fields = await entryForm(
      context,
      'A measurement',
      [
        EntryField(
          'title',
          'Measurement',
          value: 'Weight',
          choices: {for (final key in units.keys) key: key},
        ),
        const EntryField('value', 'Value'),
        EntryField(
          'date',
          'Local date (YYYY-MM-DD)',
          value: clock.day(clock.now()),
        ),
      ],
      validate: (v) {
        final value = num.tryParse(v['value']!);
        if (value == null || !value.isFinite || value < 0)
          return 'Enter a finite, non-negative number.';
        try {
          clock.parse('${v['date']} 12:00');
        } catch (e) {
          return e.toString();
        }
        if (v['title'] == 'Sleep' && value > 24)
          return 'Sleep duration cannot exceed 24 hours per day.';
        if (v['title'] == 'Energy' && (value < 1 || value > 5))
          return 'Energy uses a 1–5 scale.';
        return null;
      },
    );
    if (fields != null)
      await store.put({
        'id': store.id('measurement'),
        'kind': 'measurement',
        ...fields,
        'value': num.parse(fields['value']!),
        'unit': units[fields['title']],
      }, 'Record measurement');
  }

  Future<void> _nutritionEntry() async {
    final fields = await entryForm(
      context,
      'A food entry',
      [
        const EntryField('title', 'Food / meal description'),
        EntryField('date', 'Date', value: clock.day(clock.now())),
        const EntryField('meal', 'Meal', value: 'Other'),
        const EntryField('calories', 'Calories (kcal)'),
        const EntryField('carbs', 'Carbohydrate (g)', optional: true),
        const EntryField('fat', 'Fat (g)', optional: true),
        const EntryField('protein', 'Protein (g)', optional: true),
      ],
      notice: 'Record individual food or meal entries, not a day total that duplicates imported items. The day remains labelled partial.',
      validate: (v) {
        try {
          clock.parse('${v['date']} 12:00');
        } catch (_) {
          return 'Use a valid date.';
        }
        for (final key in ['calories', 'carbs', 'fat', 'protein']) {
          if (v[key]!.isEmpty && key != 'calories') continue;
          final value = num.tryParse(v[key]!);
          if (value == null || !value.isFinite || value < 0)
            return 'Use non-negative numbers; leave unknown macros blank.';
        }
        return null;
      },
    );
    if (fields == null) return;
    await store.put({
      ...fields,
      'id': store.id('nutrition'),
      'kind': 'nutrition',
      'source': 'Manual',
      'partial': true,
      for (final key in ['calories', 'carbs', 'fat', 'protein'])
        key: fields[key]!.isEmpty ? null : num.parse(fields[key]!),
    }, 'Record food entry');
  }

  Future<void> _expense() async {
    final fields = await entryForm(
      context,
      'An expense or credit',
      [
        const EntryField('title', 'Description'),
        const EntryField('amount', 'MYR amount (negative for credit)'),
        const EntryField('category', 'Category', value: 'Personal'),
        EntryField('date', 'Date', value: clock.day(clock.now())),
        const EntryField(
          'paid',
          'Status',
          value: 'paid',
          choices: {'paid': 'Paid', 'planned': 'Projected, not paid'},
        ),
      ],
      validate: (v) {
        try {
          moneyMinor(v['amount']!);
          clock.parse('${v['date']} 12:00');
        } catch (e) {
          return e.toString();
        }
        return null;
      },
    );
    if (fields != null)
      await store.put({
        'id': store.id('expense'),
        'kind': 'expense',
        ...fields,
        'minor': moneyMinor(fields['amount']!),
        'paid': fields['paid'] == 'paid',
        'source': 'Manual',
      }, 'Record expense');
  }

  Future<void> _outing(int remaining) async {
    final fields = await entryForm(
      context,
      'Try an outing scenario',
      [
        const EntryField('cost', 'Estimated outing cost (RM)', value: '70'),
        const EntryField(
          'reserve',
          'Keep aside for essentials (RM)',
          value: '0',
        ),
      ],
      validate: (v) {
        try {
          if (moneyMinor(v['cost']!) < 0 || moneyMinor(v['reserve']!) < 0)
            return 'Use non-negative estimates.';
        } catch (e) {
          return e.toString();
        }
        return null;
      },
      confirm: 'Calculate',
    );
    if (fields == null || !mounted) return;
    final left =
        remaining -
        moneyMinor(fields['cost']!) -
        moneyMinor(fields['reserve']!);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          left >= 0
              ? 'Within your entered budget'
              : 'Exceeds your entered budget',
        ),
        content: Text(
          'RM ${(left / 100).toStringAsFixed(2)} would remain after the outing and reserve.\n\nThis uses your entered weekly budget and current paid/committed records. It is an estimate, not a payment or a recorded transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
