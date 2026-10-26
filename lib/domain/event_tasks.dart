import 'planning.dart';

/// A linked group and one of its descendants must not count the leaf twice.
class EventTasks {
  const EventTasks(this.roots, this.leaves, this.issues);
  final List<PlanTask> roots, leaves;
  final List<String> issues;
  int get completed =>
      leaves.where((t) => t.state == TaskState.completed).length;
  double? get progress {
    final total = leaves.fold<int>(0, (n, t) => n + t.effortWeight);
    if (total <= 0) return null;
    final done = leaves.fold<int>(
      0,
      (n, t) =>
          n +
          (t.state == TaskState.completed
              ? t.effortWeight
              : (t.effortWeight - t.minutes).clamp(0, t.effortWeight)),
    );
    return (done / total).clamp(0, 1);
  }
}

EventTasks eventTasks(PlanBlock event, List<PlanTask> tasks) {
  final byId = {for (final task in tasks) task.id: task};
  final selected = {
    if (event.taskId != null) event.taskId!,
    ...event.relatedTaskIds,
  };
  final issues = <String>[];
  final roots = <PlanTask>[];
  for (final id in selected) {
    final task = byId[id];
    if (task == null) {
      issues.add('A linked task is no longer available.');
      continue;
    }
    var parent = task.parentId;
    final visited = {id};
    var covered = false;
    while (parent != null) {
      if (!visited.add(parent)) {
        issues.add('A task hierarchy cycle needs review.');
        covered = true;
        break;
      }
      if (selected.contains(parent)) covered = true;
      parent = byId[parent]?.parentId;
    }
    if (!covered) roots.add(task);
  }
  final leaves = <String, PlanTask>{};
  void collect(PlanTask task, Set<String> visited) {
    if (!visited.add(task.id)) {
      issues.add('A task hierarchy cycle needs review.');
      return;
    }
    final children = tasks.where((child) => child.parentId == task.id).toList();
    if (children.isEmpty) {
      leaves[task.id] = task;
      return;
    }
    for (final child in children) collect(child, {...visited});
  }

  for (final root in roots) collect(root, {});
  return EventTasks(roots, leaves.values.toList(), issues.toSet().toList());
}
