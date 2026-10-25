import 'clock.dart';

/// Only summaries explicitly selected by the user are shared with the provider.
String aiContext(
  List<Map<String, dynamic>> records,
  String scope,
  ZoneClock clock,
) {
  if (scope == 'none') return '';
  final now = clock.now();
  if (scope == 'training') {
    final cutoff = now.subtract(const Duration(days: 28));
    final rows = records
        .where(
          (r) =>
              r['kind'] == 'workout' &&
              DateTime.parse(r['start']).isAfter(cutoff) &&
              !DateTime.parse(r['start']).isAfter(now),
        )
        .toList();
    rows.sort(
      (a, b) =>
          DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])),
    );
    final sessions = rows.map((r) => r['session']).toSet().length;
    final working = rows.where((r) => r['setType'] != 'warmup').toList();
    final sample = working.reversed
        .take(20)
        .map(
          (r) =>
              '${clock.stamp(DateTime.parse(r['start']))} · ${r['exercise']} · ${r['weightKg'] ?? 'missing'} kg × ${r['reps'] ?? 'missing'} reps · RPE ${r['rpe'] ?? 'missing'}',
        )
        .join('\n');
    return 'USER-SELECTED TRAINING CONTEXT\nLast 28 days: $sessions recorded sessions, ${working.length} non-warmup set rows. Source: imported workout rows; absence is not evidence of no training.\nUp to 20 most recent recorded non-warmup set rows (not a complete log):\n$sample\nDo not infer missing RPE or give medical diagnoses.';
  }
  if (scope == 'budget') {
    final monday = DateTime.utc(now.year, now.month, now.day - now.weekday + 1);
    final first = clock.day(monday),
        end = clock.day(monday.add(const Duration(days: 7)));
    final expenses = records.where(
      (r) =>
          r['kind'] == 'expense' &&
          (r['date'] as String).compareTo(first) >= 0 &&
          (r['date'] as String).compareTo(end) < 0,
    );
    final paid = expenses
        .where((r) => r['paid'] == true)
        .fold<int>(0, (sum, r) => sum + r['minor'] as int);
    final committed = expenses
        .where((r) => r['paid'] != true)
        .fold<int>(0, (sum, r) => sum + r['minor'] as int);
    final settings = records.where((r) => r['id'] == 'settings').firstOrNull;
    final budget = settings?['weeklyMinor'] as int? ?? 0;
    return 'USER-SELECTED BUDGET CONTEXT\nWeek beginning $first; currency MYR, amounts below in integer sen. Budget $budget, paid $paid, projected commitments $committed, remaining after commitments ${budget - paid - committed}. Source: user-entered/imported records only. Unknown expenses are not included. No transaction descriptions or unrelated records were shared. Do not initiate payments.';
  }
  return '';
}
