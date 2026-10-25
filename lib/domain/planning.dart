/// Pure domain logic: no platform APIs, persistence, network, or UI imports.
enum TaskState { pending, active, completed, paused }

class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    required this.minutes,
    required this.deadline,
    this.priority = 2,
    this.dependencies = const [],
    this.minimumBlock = 25,
    this.splittable = true,
    this.state = TaskState.pending,
    this.parentId,
    this.actualMinutes = 0,
    this.estimatedMinutes,
  });
  final String id, title;
  final int minutes, priority, minimumBlock, actualMinutes;
  final int? estimatedMinutes;
  int get effortWeight => estimatedMinutes ?? minutes;
  final DateTime deadline;
  final List<String> dependencies;
  final bool splittable;
  final TaskState state;
  final String? parentId;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'estimatedMinutes': effortWeight,
    'deadline': deadline.toUtc().toIso8601String(),
    'priority': priority,
    'dependencies': dependencies,
    'minimumBlock': minimumBlock,
    'splittable': splittable,
    'state': state.name,
    'parentId': parentId,
    'actualMinutes': actualMinutes,
  };
  factory PlanTask.fromJson(Map<String, dynamic> j) => PlanTask(
    id: j['id'],
    title: j['title'],
    minutes: j['minutes'],
    deadline: DateTime.parse(j['deadline']),
    priority: j['priority'] ?? 2,
    dependencies: List<String>.from(j['dependencies'] ?? []),
    minimumBlock: j['minimumBlock'] ?? 25,
    splittable: j['splittable'] ?? true,
    state: TaskState.values.byName(j['state'] ?? 'pending'),
    parentId: j['parentId'],
    actualMinutes: j['actualMinutes'] ?? 0,
    estimatedMinutes: j['estimatedMinutes'],
  );
}

class PlanBlock {
  const PlanBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.taskId,
    this.fixed = false,
    this.pinned = false,
    this.source = 'LifeOS',
  });
  final String id, title, source;
  final String? taskId;
  final DateTime start, end;
  final bool fixed, pinned;
  bool get immovable => fixed || pinned || source != 'LifeOS';
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'taskId': taskId,
    'fixed': fixed,
    'pinned': pinned,
    'source': source,
  };
  factory PlanBlock.fromJson(Map<String, dynamic> j) => PlanBlock(
    id: j['id'],
    title: j['title'],
    start: DateTime.parse(j['start']),
    end: DateTime.parse(j['end']),
    taskId: j['taskId'],
    fixed: j['fixed'] ?? false,
    pinned: j['pinned'] ?? false,
    source: j['source'] ?? 'LifeOS',
  );
  bool overlaps(PlanBlock other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}

class TimeWindow {
  const TimeWindow(this.start, this.end);
  final DateTime start, end;
}

class ScheduleProposal {
  const ScheduleProposal({
    required this.revision,
    required this.blocks,
    required this.unscheduled,
    required this.conflicts,
  });
  final int revision;
  final List<PlanBlock> blocks;
  final List<String> unscheduled, conflicts;
  bool get feasible => unscheduled.isEmpty && conflicts.isEmpty;
}

class Scheduler {
  /// Replaces only unpinned LifeOS flexible blocks. Deadlines are input-only.
  /// Hard overlaps remain explicit conflicts, never silently resolved.
  ScheduleProposal propose({
    required int revision,
    required List<PlanTask> tasks,
    required List<PlanBlock> existing,
    required List<TimeWindow> windows,
  }) {
    final hierarchy = resolveHierarchy(tasks);
    tasks = hierarchy.leaves;
    final immutable = existing.where((b) => b.immovable).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final conflicts = [...hierarchy.issues];
    for (final block in immutable) {
      if (hierarchy.parents.contains(block.taskId))
        conflicts.add(
          'Pinned parent block ${block.title} needs mapping to leaf work before replanning.',
        );
    }
    for (var i = 0; i < immutable.length; i++) {
      if (!immutable[i].end.isAfter(immutable[i].start))
        conflicts.add('Invalid block: ${immutable[i].title}');
      for (var j = i + 1; j < immutable.length; j++) {
        if (immutable[i].overlaps(immutable[j]))
          conflicts.add('${immutable[i].title} overlaps ${immutable[j].title}');
      }
    }
    final planned = [...immutable];
    final unscheduled = <String>[];
    final completed = tasks
        .where((t) => t.state == TaskState.completed)
        .map((t) => t.id)
        .toSet();
    final finishes = <String, DateTime>{};
    final pending =
        tasks
            .where(
              (t) =>
                  t.state == TaskState.pending || t.state == TaskState.active,
            )
            .toList()
          ..sort((a, b) {
            final due = a.deadline.compareTo(b.deadline);
            return due != 0
                ? due
                : a.priority != b.priority
                ? b.priority.compareTo(a.priority)
                : a.id.compareTo(b.id);
          });
    final sortedWindows = [...windows]
      ..sort((a, b) => a.start.compareTo(b.start));
    // Reject overlapping availability, which otherwise could double-book free time.
    for (var i = 0; i < sortedWindows.length; i++) {
      if (!sortedWindows[i].end.isAfter(sortedWindows[i].start))
        conflicts.add('Invalid availability window');
      if (i > 0 && sortedWindows[i].start.isBefore(sortedWindows[i - 1].end))
        conflicts.add('Availability windows overlap');
    }
    if (conflicts.isNotEmpty)
      return ScheduleProposal(
        revision: revision,
        blocks: immutable,
        unscheduled: pending.map((t) => t.id).toList(),
        conflicts: conflicts,
      );
    while (pending.isNotEmpty) {
      final index = pending.indexWhere(
        (t) => t.dependencies.every(completed.contains),
      );
      if (index < 0) {
        unscheduled.addAll(pending.map((t) => t.id));
        break;
      }
      final task = pending.removeAt(index);
      if (task.minutes <= 0 || task.minimumBlock <= 0) {
        unscheduled.add(task.id);
        continue;
      }
      var remaining = task.minutes;
      final pieces = <PlanBlock>[];
      DateTime? dependencyEnd;
      for (final dependency in task.dependencies) {
        final finish = finishes[dependency];
        if (finish != null &&
            (dependencyEnd == null || finish.isAfter(dependencyEnd)))
          dependencyEnd = finish;
      }
      // Honor already pinned work for this task rather than duplicating it.
      for (final block in immutable.where((b) => b.taskId == task.id)) {
        if (dependencyEnd != null && block.start.isBefore(dependencyEnd)) {
          conflicts.add(
            'Pinned work for ${task.title} starts before its prerequisite finishes',
          );
        }
        if (block.end.isAfter(task.deadline)) {
          conflicts.add('Pinned work for ${task.title} exceeds its deadline');
        }
        remaining -= block.end.difference(block.start).inMinutes;
      }
      for (final window in sortedWindows) {
        if (remaining <= 0) break;
        var cursor = window.start;
        if (dependencyEnd != null && cursor.isBefore(dependencyEnd))
          cursor = dependencyEnd;
        final limit = window.end.isBefore(task.deadline)
            ? window.end
            : task.deadline;
        final occupied = [...planned, ...pieces]
          ..sort((a, b) => a.start.compareTo(b.start));
        final gaps = <TimeWindow>[];
        for (final busy in occupied) {
          if (!busy.end.isAfter(cursor) || !busy.start.isBefore(limit))
            continue;
          if (busy.start.isAfter(cursor))
            gaps.add(TimeWindow(cursor, busy.start));
          if (busy.end.isAfter(cursor)) cursor = busy.end;
        }
        if (cursor.isBefore(limit)) gaps.add(TimeWindow(cursor, limit));
        for (final gap in gaps) {
          if (remaining <= 0) break;
          final available = gap.end.difference(gap.start).inMinutes;
          if (!task.splittable && available < remaining) continue;
          final use = remaining < available ? remaining : available;
          if (use <= 0 || (use < task.minimumBlock && use < remaining))
            continue;
          // Avoid manufacturing an unusably short final fragment.
          var take = use;
          if (remaining > use && remaining - use < task.minimumBlock)
            take -= task.minimumBlock - (remaining - use);
          if (take <= 0 || (take < task.minimumBlock && take < remaining))
            continue;
          var pieceIndex = pieces.length;
          while ([
            ...planned,
            ...pieces,
          ].any((b) => b.id == 'proposal-${task.id}-$pieceIndex')) {
            pieceIndex++;
          }
          pieces.add(
            PlanBlock(
              id: 'proposal-${task.id}-$pieceIndex',
              title: task.title,
              taskId: task.id,
              start: gap.start,
              end: gap.start.add(Duration(minutes: take)),
            ),
          );
          remaining -= take;
        }
      }
      if (remaining > 0) {
        unscheduled.add(task.id);
        continue;
      }
      planned.addAll(pieces);
      completed.add(task.id);
      final ends =
          planned.where((b) => b.taskId == task.id).map((b) => b.end).toList()
            ..sort();
      if (ends.isNotEmpty) finishes[task.id] = ends.last;
    }
    planned.sort((a, b) => a.start.compareTo(b.start));
    return ScheduleProposal(
      revision: revision,
      blocks: planned,
      unscheduled: unscheduled,
      conflicts: conflicts,
    );
  }
}

/// Reserve an explicit percentage of truly free time, after fixed/pinned blocks.
/// Reserved gaps stay unallocated rather than becoming fictional commitments.
List<TimeWindow> reserveFreeTime(
  List<TimeWindow> windows,
  List<PlanBlock> commitments,
  int percent,
) {
  if (percent < 0 || percent > 90)
    throw ArgumentError.value(percent, 'percent', 'Use 0–90');
  final result = <TimeWindow>[];
  final busy = commitments.where((b) => b.immovable).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  for (final window in windows) {
    final gaps = <TimeWindow>[];
    var cursor = window.start;
    for (final block in busy) {
      if (!block.end.isAfter(cursor) || !block.start.isBefore(window.end))
        continue;
      if (block.start.isAfter(cursor))
        gaps.add(TimeWindow(cursor, block.start));
      if (block.end.isAfter(cursor)) cursor = block.end;
    }
    if (cursor.isBefore(window.end)) gaps.add(TimeWindow(cursor, window.end));
    final available = gaps.fold<int>(
      0,
      (sum, g) => sum + g.end.difference(g.start).inMinutes,
    );
    var reserve = (available * percent / 100).ceil();
    final retained = <TimeWindow>[];
    for (final gap in gaps.reversed) {
      final minutes = gap.end.difference(gap.start).inMinutes;
      final remove = reserve < minutes ? reserve : minutes;
      reserve -= remove;
      if (minutes > remove)
        retained.add(
          TimeWindow(gap.start, gap.end.subtract(Duration(minutes: remove))),
        );
    }
    result.addAll(retained.reversed);
  }
  return result;
}

class TaskHierarchy {
  const TaskHierarchy(this.leaves, this.parents, this.issues);
  final List<PlanTask> leaves;
  final Set<String> parents;
  final List<String> issues;
}

TaskHierarchy resolveHierarchy(List<PlanTask> tasks) {
  final byId = {for (final task in tasks) task.id: task};
  final children = <String, List<String>>{};
  final issues = <String>[];
  for (final task in tasks) {
    if (task.parentId != null) {
      if (!byId.containsKey(task.parentId))
        issues.add('Missing parent for ${task.title}');
      children.putIfAbsent(task.parentId!, () => []).add(task.id);
    }
  }
  List<String> leafIds(String id, Set<String> visiting) {
    if (!visiting.add(id)) {
      issues.add('Task hierarchy contains a cycle');
      return [];
    }
    final descendants = children[id];
    if (descendants == null) return [id];
    return [
      for (final child in descendants) ...leafIds(child, {...visiting}),
    ];
  }

  for (final parent in children.keys) {
    leafIds(parent, {});
  }
  final leaves = <PlanTask>[];
  for (final task in tasks.where((t) => !children.containsKey(t.id))) {
    var deadline = task.deadline, priority = task.priority, state = task.state;
    final dependencies = {...task.dependencies};
    var parent = task.parentId;
    final seen = <String>{task.id};
    while (parent != null && seen.add(parent)) {
      final ancestor = byId[parent];
      if (ancestor == null) break;
      if (ancestor.deadline.isBefore(deadline)) deadline = ancestor.deadline;
      if (ancestor.priority > priority) priority = ancestor.priority;
      dependencies.addAll(ancestor.dependencies);
      if (ancestor.state == TaskState.paused && state != TaskState.completed)
        state = TaskState.paused;
      if (ancestor.state == TaskState.completed &&
          task.state != TaskState.completed)
        issues.add(
          'Completed parent ${ancestor.title} has incomplete subtasks',
        );
      parent = ancestor.parentId;
    }
    final expanded = <String>{
      for (final dependency in dependencies) ...leafIds(dependency, {}),
    };
    leaves.add(
      PlanTask.fromJson({
        ...task.toJson(),
        'deadline': deadline.toUtc().toIso8601String(),
        'priority': priority,
        'state': state.name,
        'dependencies': expanded.toList(),
      }),
    );
  }
  return TaskHierarchy(leaves, children.keys.toSet(), issues.toSet().toList());
}

double weightedTaskProgress(String id, List<PlanTask> tasks) {
  final byId = {for (final task in tasks) task.id: task};
  final visited = <String>{};
  final leaves = <PlanTask>[];
  void collect(String key) {
    if (!visited.add(key)) return;
    final children = tasks.where((t) => t.parentId == key).toList();
    if (children.isEmpty) {
      if (byId[key] != null) leaves.add(byId[key]!);
    } else {
      for (final child in children) {
        collect(child.id);
      }
    }
  }

  collect(id);
  var total = 0, done = 0;
  for (final leaf in leaves) {
    final weight = leaf.effortWeight;
    total += weight;
    done += leaf.state == TaskState.completed
        ? weight
        : (weight - leaf.minutes).clamp(0, weight);
  }
  return total == 0 ? 0 : done / total;
}

List<String> planningWarnings(
  List<PlanTask> tasks,
  List<PlanBlock> blocks,
  DateTime now,
) {
  final hierarchy = resolveHierarchy(tasks);
  final warnings = [...hierarchy.issues];
  for (final task in hierarchy.leaves) {
    if (task.state != TaskState.pending && task.state != TaskState.active)
      continue;
    if (!task.deadline.isAfter(now)) {
      warnings.add(
        'Overdue: ${task.title}. The true deadline has not changed.',
      );
      continue;
    }
    final allocated = blocks
        .where(
          (b) =>
              b.taskId == task.id &&
              !b.end.isAfter(task.deadline) &&
              b.end.isAfter(now),
        )
        .fold<int>(0, (sum, b) {
          final start = b.start.isAfter(now) ? b.start : now;
          return sum + b.end.difference(start).inMinutes;
        });
    if (allocated < task.minutes)
      warnings.add(
        '${task.title}: ${task.minutes - allocated} minutes still need planning before the deadline.',
      );
  }
  final fixed = blocks.where((b) => b.immovable).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  for (var i = 0; i < fixed.length; i++) {
    for (var j = i + 1; j < fixed.length; j++) {
      if (!fixed[j].start.isBefore(fixed[i].end)) break;
      if (fixed[i].overlaps(fixed[j]))
        warnings.add('Conflict: ${fixed[i].title} overlaps ${fixed[j].title}.');
      if (warnings.length >= 50) return warnings;
    }
  }
  return warnings;
}
