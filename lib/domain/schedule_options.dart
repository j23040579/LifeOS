import 'clock.dart';
import 'calendar_geometry.dart';
import 'planning.dart';

/// Small, inspectable policies over the deterministic planner, not an optimality
/// claim. Every option retains the same hard constraints and revision checks.
class ScheduleOption {
  const ScheduleOption({
    required this.name,
    required this.explanation,
    required this.proposal,
    required this.peakFlexibleMinutes,
    required this.changedFlexibleBlocks,
  });
  final String name, explanation;
  final ScheduleProposal proposal;
  final int peakFlexibleMinutes, changedFlexibleBlocks;
}

List<ScheduleOption> scheduleOptions({
  required int revision,
  required List<PlanTask> tasks,
  required List<PlanBlock> existing,
  required List<TimeWindow> windows,
  required ZoneClock clock,
}) {
  final ordered = [...windows]..sort((a, b) => a.start.compareTo(b.start));
  final invalidWindows = ordered.indexed.any(
    (entry) =>
        !entry.$2.end.isAfter(entry.$2.start) ||
        (entry.$1 > 0 && entry.$2.start.isBefore(ordered[entry.$1 - 1].end)),
  );
  final dateCount = ordered
      .map((w) => clock.day(clock.local(w.start)))
      .toSet()
      .length;
  final remaining = resolveHierarchy(tasks).leaves
      .where((t) => t.state == TaskState.pending || t.state == TaskState.active)
      .fold<int>(0, (n, t) {
        final pinned = existing
            .where((b) => b.immovable && b.taskId == t.id)
            .fold<int>(0, (m, b) => m + b.end.difference(b.start).inMinutes);
        return n + (t.minutes - pinned).clamp(0, t.minutes);
      });
  final cap = dateCount == 0
      ? 25
      : ((remaining / dateCount / 25).ceil() * 25).clamp(25, 1440);
  final spent = <String, int>{};
  final spreadWindows = <TimeWindow>[];
  for (final window in ordered) {
    var cursor = window.start;
    while (cursor.isBefore(window.end)) {
      final local = clock.local(cursor), date = clock.day(clock.local(cursor));
      final nextDay = CalendarDay(clock, local).end;
      final end = nextDay.isBefore(window.end) ? nextDay : window.end;
      final take = (cap - (spent[date] ?? 0)).clamp(
        0,
        end.difference(cursor).inMinutes,
      );
      if (take > 0) {
        spreadWindows.add(
          TimeWindow(cursor, cursor.add(Duration(minutes: take))),
        );
        spent[date] = (spent[date] ?? 0) + take;
      }
      cursor = end;
    }
  }
  ScheduleOption option(
    String name,
    String explanation,
    List<TimeWindow> available, {
    bool priority = false,
  }) {
    final proposal = Scheduler().propose(
      revision: revision,
      tasks: tasks,
      existing: existing,
      windows: available,
      priorityFirst: priority,
    );
    final totals = <String, int>{};
    final flexible = proposal.blocks.where((b) => !b.immovable).toList();
    for (final block in flexible) {
      var cursor = block.start;
      while (cursor.isBefore(block.end)) {
        final local = clock.local(cursor),
            date = clock.day(clock.local(cursor));
        final nextDay = CalendarDay(clock, local).end;
        final end = nextDay.isBefore(block.end) ? nextDay : block.end;
        totals[date] = (totals[date] ?? 0) + end.difference(cursor).inMinutes;
        cursor = end;
      }
    }
    bool equivalent(PlanBlock a, PlanBlock b) =>
        a.taskId == b.taskId && a.start == b.start && a.end == b.end;
    final removedOrMoved = existing
        .where((b) => !b.immovable && !flexible.any((p) => equivalent(b, p)))
        .length;
    final added = flexible
        .where((b) => !existing.any((p) => !p.immovable && equivalent(b, p)))
        .length;
    return ScheduleOption(
      name: name,
      explanation: explanation,
      proposal: proposal,
      peakFlexibleMinutes: totals.values.fold<int>(
        0,
        (peak, value) => value > peak ? value : peak,
      ),
      changedFlexibleBlocks: removedOrMoved + added,
    );
  }

  final options = [
    option(
      'Deadline first',
      'Start with the nearest true deadlines. Importance breaks ties; work fills the earliest available gaps.',
      ordered,
    ),
    option(
      'Importance first',
      'Start with the most important ready tasks. Urgent work may not fit, so check the warnings before choosing.',
      ordered,
      priority: true,
    ),
    option(
      'Spread the work',
      'Spread new work across dates, with up to $cap minutes per date. This daily cap may leave work unplanned; try another option if needed.',
      invalidWindows ? ordered : spreadWindows,
    ),
  ];
  // Transparent lexicographic ranking: hard conflicts, unscheduled tasks, peak
  // new flexible minutes on one date, then changed/added/removed flexible blocks.
  options.sort((a, b) {
    for (final comparison in [
      a.proposal.conflicts.length.compareTo(b.proposal.conflicts.length),
      a.proposal.unscheduled.length.compareTo(b.proposal.unscheduled.length),
      a.peakFlexibleMinutes.compareTo(b.peakFlexibleMinutes),
      a.changedFlexibleBlocks.compareTo(b.changedFlexibleBlocks),
    ]) {
      if (comparison != 0) return comparison;
    }
    return a.name.compareTo(b.name);
  });
  return options;
}
