import 'dart:convert';

import 'clock.dart';
import 'planning.dart';

/// A planning check-in, never a health, personality or lifetime-progress rating.
class DayEvidence {
  const DayEvidence(
    this.day,
    this.at,
    this.dueCount,
    this.doneCount,
    this.dueEffort,
    this.doneEffort,
    this.todoIds,
    this.scheduledCount,
  );
  final String day;
  final DateTime at;
  final int dueCount, doneCount, dueEffort, doneEffort, scheduledCount;
  final List<String> todoIds;
  int? get localScore => dueEffort == 0
      ? null
      : (100 * doneEffort / dueEffort).round().clamp(0, 100);
  Map<String, Object> get sharedSummary => {
    'localDate': day,
    'asOf': at.toUtc().toIso8601String(),
    'tasksDueByNow': dueCount,
    'completedOfThose': doneCount,
    'estimatedEffortDueMinutes': dueEffort,
    'completedEffortMinutes': doneEffort,
    'remainingTodayCount': todoIds.length,
    'todayScheduledBlocks': scheduledCount,
    'localPlanningScore': localScore ?? 'insufficient evidence',
  };
}

DayEvidence dayEvidence(
  List<PlanTask> tasks,
  List<PlanBlock> blocks,
  List<Map<String, dynamic>> records,
  ZoneClock clock,
  DateTime now,
) {
  final day = clock.day(clock.local(now));
  bool overlapsDay(PlanBlock b) =>
      clock.day(clock.local(b.start)).compareTo(day) <= 0 &&
      clock
              .day(clock.local(b.end.subtract(const Duration(microseconds: 1))))
              .compareTo(day) >=
          0;
  final todayBlocks = blocks.where(overlapsDay).toList();
  final ended = todayBlocks
      .where((b) => !b.end.isAfter(now))
      .map((b) => b.taskId)
      .whereType<String>()
      .toSet();
  final scheduled = todayBlocks
      .expand((b) => [if (b.taskId != null) b.taskId!, ...b.relatedTaskIds])
      .toSet();
  final leaves = resolveHierarchy(tasks).leaves;
  bool scheduledToday(PlanTask task) {
    var id = task.id;
    final visited = <String>{};
    while (visited.add(id)) {
      if (scheduled.contains(id)) return true;
      final parent = tasks.where((t) => t.id == id).firstOrNull?.parentId;
      if (parent == null) return false;
      id = parent;
    }
    return false;
  }

  final todayTodos =
      leaves
          .where(
            (t) =>
                (t.state == TaskState.pending || t.state == TaskState.active) &&
                (!t.deadline.isAfter(now) ||
                    clock.day(clock.local(t.deadline)) == day ||
                    scheduledToday(t)),
          )
          .toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
  final eligible = leaves.where((t) {
    if (t.state == TaskState.paused) return false;
    final dueDay = clock.day(clock.local(t.deadline));
    final record = records.where((r) => r['id'] == t.id).firstOrNull;
    final completion = DateTime.tryParse(
      record?['completedAt']?.toString() ?? '',
    );
    final completedToday =
        completion != null && clock.day(clock.local(completion)) == day;
    // Historical completed tasks without a timestamp are not today's evidence.
    if (t.state == TaskState.completed &&
        dueDay != day &&
        !ended.contains(t.id) &&
        !completedToday)
      return false;
    return !t.deadline.isAfter(now) || ended.contains(t.id) || completedToday;
  }).toList();
  final done = eligible.where((t) => t.state == TaskState.completed).toList();
  return DayEvidence(
    day,
    now.toUtc(),
    eligible.length,
    done.length,
    eligible.fold(0, (n, t) => n + t.effortWeight),
    eligible.fold(
      0,
      (n, t) =>
          n +
          (t.state == TaskState.completed
              ? t.effortWeight
              : (t.effortWeight - t.minutes).clamp(0, t.effortWeight)),
    ),
    todayTodos.map((t) => t.id).toList(),
    todayBlocks.length,
  );
}

class DayAssessment {
  const DayAssessment(
    this.score,
    this.feedback,
    this.source,
    this.at, {
    this.model,
    this.confidence = 'limited',
  });
  final int? score;
  final String feedback, source, confidence;
  final DateTime at;
  final String? model;
  factory DayAssessment.local(DayEvidence evidence) => DayAssessment(
    evidence.localScore,
    evidence.localScore == null
        ? 'There is not enough recorded work due by now to rate your pace. Choose one small next step.'
        : '${evidence.doneCount} of ${evidence.dueCount} tasks due by now are recorded complete. ${evidence.localScore! >= 75 ? 'Your recorded plan is keeping pace.' : 'There is room to reset your plan; remaining work can be reviewed without changing its deadline.'}',
    'Local calculation',
    evidence.at,
  );
  factory DayAssessment.gemini(String text, String model, DateTime at) {
    final data = jsonDecode(text);
    if (data is! Map ||
        data['score'] is! int ||
        data['score'] < 0 ||
        data['score'] > 100 ||
        data['feedback'] is! String ||
        data['feedback'].trim().isEmpty ||
        data['feedback'].length > 1200 ||
        !const ['limited', 'moderate'].contains(data['confidence'])) {
      throw const FormatException('Invalid check-in response');
    }
    return DayAssessment(
      data['score'],
      data['feedback'],
      'Gemini assessment',
      at,
      model: model,
      confidence: data['confidence'],
    );
  }
}
