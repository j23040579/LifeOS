import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/workspace_database.dart';
import '../domain/planning.dart';
import '../domain/clock.dart';

class Workspace extends ChangeNotifier {
  Workspace(this.database);
  final WorkspaceDatabase database;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  WorkspaceSnapshot snapshot = const WorkspaceSnapshot(0, {});
  bool busy = false;
  String? error;
  String id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  List<Map<String, dynamic>> of(String kind) =>
      snapshot.records.values.where((r) => r['kind'] == kind).toList();
  List<PlanTask> get tasks => of('task').map(PlanTask.fromJson).toList();
  List<PlanBlock> get blocks => of('block').map(PlanBlock.fromJson).toList();
  Future<void> load() async {
    snapshot = await database.load();
    notifyListeners();
  }

  Future<bool> change(
    String description,
    void Function(Map<String, Map<String, dynamic>>) edit, {
    bool invalidateNutritionConfirmation = true,
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final records = {
        for (final e in snapshot.records.entries)
          e.key: Map<String, dynamic>.from(e.value),
      };
      edit(records);
      if (invalidateNutritionConfirmation)
        _invalidateChangedNutrition(snapshot.records, records);
      for (final record in records.values) {
        _validateRecord(record);
      }
      snapshot = await database.save(snapshot, records, description);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> put(Map<String, dynamic> record, String description) => change(
    description,
    (records) {
      if (record['kind'] == 'task') {
        final previous = records[record['id']];
        if (record['state'] == 'completed' && previous?['state'] != 'completed')
          record = {
            ...record,
            'completedAt': DateTime.now().toUtc().toIso8601String(),
          };
        if (record['state'] != 'completed')
          record = {...record, 'completedAt': null};
      }
      _validateRecord(record);
      if (record['kind'] == 'note' &&
          (records[record['id']]?['body'] != record['body'] ||
              records[record['id']]?['source'] != record['source'] ||
              records[record['id']]?['reference'] != record['reference'])) {
        records.updateAll(
          (_, value) => value['sourceNoteId'] == record['id']
              ? {...value, 'sourceStale': true}
              : value,
        );
      }
      records[record['id']] = record;
    },
  );
  Future<bool> remove(String id) => change('Delete local record', (records) {
    records.remove(id);
    records.updateAll(
      (_, value) =>
          value['sourceNoteId'] == id ? {...value, 'sourceStale': true} : value,
    );
  });

  Future<bool> reviewNutritionDay({
    required String date,
    required bool complete,
    required int expectedRevision,
  }) => change('Review nutrition day completeness', (records) {
    if (snapshot.revision != expectedRevision)
      throw const FormatException(
        'Records changed; review the food day again.',
      );
    if (!records.values.any(
      (r) => r['kind'] == 'nutrition' && r['date'] == date,
    ))
      throw const FormatException('No food entries remain for this date.');
    final id = 'nutrition-day-$date';
    records[id] = {
      'id': id,
      'kind': 'nutrition_day',
      'date': date,
      'complete': complete,
      'source': 'User confirmation',
      'at': DateTime.now().toUtc().toIso8601String(),
    };
  });
  Future<bool> deleteTask(String id) => change('Delete task', (records) {
    records.remove(id);
    final remove = <String>[];
    records.updateAll((key, value) {
      if (value['kind'] == 'task' && value['parentId'] == id)
        return {...value, 'parentId': null};
      if (value['kind'] == 'block' && value['taskId'] != id) {
        return {
          ...value,
          'relatedTaskIds': List<String>.from(value['relatedTaskIds'] ?? [])
            ..remove(id),
        };
      }
      if (value['kind'] == 'block' && value['taskId'] == id) {
        if (value['source'] == 'LifeOS' &&
            value['fixed'] != true &&
            value['pinned'] != true) {
          remove.add(key);
          return value;
        }
        return {
          ...value,
          'taskId': null,
          'relatedTaskIds': List<String>.from(value['relatedTaskIds'] ?? [])
            ..remove(id),
        };
      }
      return value;
    });
    for (final key in remove) {
      records.remove(key);
    }
  });
  Future<bool> complete(PlanTask task) async {
    if (task.state != TaskState.completed &&
        tasks.any(
          (child) =>
              child.parentId == task.id && child.state != TaskState.completed,
        )) {
      error = 'Complete the subtasks before marking their parent complete.';
      notifyListeners();
      return false;
    }
    return put({
      ...?snapshot.records[task.id],
      ...task.toJson(),
      'kind': 'task',
      'state': task.state == TaskState.completed ? 'pending' : 'completed',
      'completedAt': task.state == TaskState.completed
          ? null
          : DateTime.now().toUtc().toIso8601String(),
    }, 'Change task completion');
  }

  Future<bool> recordFocus(Map<String, dynamic> record) =>
      change('Record task-linked focus', (records) {
        final old = records[record['id']];
        final oldTask = old?['taskId'] as String?,
            newTask = record['taskId'] as String?;
        if (newTask != null && records[newTask]?['kind'] != 'task')
          throw StateError('Linked task is no longer available.');
        final affected = {
          if (oldTask != null) oldTask,
          if (newTask != null) newTask,
        };
        final before = <String, int>{
          for (final id in affected)
            id: records.values
                .where((r) => r['kind'] == 'focus' && r['taskId'] == id)
                .fold<num>(0, (n, r) => n + (r['minutes'] as num))
                .floor(),
        };
        records[record['id']] = record;
        for (final id in affected) {
          final task = records[id];
          if (task == null) continue;
          final after = records.values
              .where((r) => r['kind'] == 'focus' && r['taskId'] == id)
              .fold<num>(0, (n, r) => n + (r['minutes'] as num))
              .floor();
          records[id] = {
            ...task,
            'actualMinutes':
                ((task['actualMinutes'] as int? ?? 0) + after - before[id]!)
                    .clamp(0, 10000000),
          };
        }
      });

  Future<bool> saveEventTask(Map<String, dynamic> task, String eventId) =>
      change('Add event task', (records) {
        final event = records[eventId];
        if (event == null || event['kind'] != 'block')
          throw StateError('This event was removed.');
        records[task['id']] = task;
        records[eventId] = {
          ...event,
          'relatedTaskIds': {
            ...List<String>.from(event['relatedTaskIds'] ?? []),
            task['id'] as String,
          }.toList(),
        };
      });

  Future<bool> apply(ScheduleProposal proposal) async {
    if (proposal.revision != snapshot.revision) {
      error = const RevisionConflict().toString();
      notifyListeners();
      return false;
    }
    if (!proposal.feasible) {
      error = 'Resolve the conflicts and unscheduled work before applying.';
      notifyListeners();
      return false;
    }
    final effectiveTasks = resolveHierarchy(tasks).leaves;
    for (var i = 0; i < proposal.blocks.length; i++) {
      final block = proposal.blocks[i];
      if (!block.end.isAfter(block.start) ||
          proposal.blocks.skip(i + 1).any(block.overlaps)) {
        error = 'The proposal contains invalid or overlapping time blocks.';
        notifyListeners();
        return false;
      }
      if (block.taskId != null) {
        final task = effectiveTasks
            .where((t) => t.id == block.taskId)
            .firstOrNull;
        if (task == null || block.end.isAfter(task.deadline)) {
          error =
              'Proposed work has no valid task or exceeds its true deadline.';
          notifyListeners();
          return false;
        }
      }
    }
    final protected = blocks.where((b) => b.immovable);
    for (final block in protected) {
      if (!proposal.blocks.any(
        (candidate) =>
            jsonEncode(candidate.toJson()) == jsonEncode(block.toJson()),
      )) {
        error = 'A fixed or pinned block cannot be changed by the optimizer.';
        notifyListeners();
        return false;
      }
    }
    return change('Approve schedule proposal', (records) {
      final original = {
        for (final entry in records.entries.where(
          (e) => e.value['kind'] == 'block',
        ))
          entry.key: entry.value,
      };
      records.removeWhere((_, r) => r['kind'] == 'block');
      for (final block in proposal.blocks) {
        records[block.id] = {
          ...?original[block.id],
          ...block.toJson(),
          'kind': 'block',
        };
      }
    });
  }

  Future<void> undo() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await database.undo(snapshot);
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> erase() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await database.erase(snapshot);
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String export() =>
      const JsonEncoder.withIndent('  ')
          .convert({'schema': 1, 'records': snapshot.records.values.toList()});
  Future<bool> restore(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is! Map ||
        decoded['schema'] != 1 ||
        decoded['records'] is! List)
      throw const FormatException('Unsupported backup format');
    final records = <String, Map<String, dynamic>>{};
    for (final value in decoded['records']) {
      final record = Map<String, dynamic>.from(value);
      if (record['id'] is! String ||
          record['kind'] is! String ||
          records.containsKey(record['id']))
        throw const FormatException('Invalid or duplicated record');
      if (record['kind'] == 'task') PlanTask.fromJson(record);
      if (record['kind'] == 'block') PlanBlock.fromJson(record);
      _validateRecord(record);
      records[record['id']] = record;
    }
    return change('Restore backup', (current) {
      current.clear();
      current.addAll(records);
    }, invalidateNutritionConfirmation: false);
  }
}

void _validateRecord(Map<String, dynamic> record) {
  const kinds = {
    'task',
    'project',
    'goal',
    'block',
    'habit',
    'course',
    'note',
    'recall',
    'workout',
    'nutrition',
    'nutrition_day',
    'exercise_alias',
    'expense',
    'measurement',
    'focus',
    'reflection',
    'settings',
    'batch',
  };
  if (!kinds.contains(record['kind']))
    throw const FormatException('Unknown record kind');
  bool finite(Object? value) => value is num && value.isFinite && value >= 0;
  switch (record['kind']) {
    case 'task':
      final task = PlanTask.fromJson(record);
      if (task.minutes <= 0 || task.priority < 1 || task.priority > 5)
        throw const FormatException('Invalid task');
    case 'block':
      final block = PlanBlock.fromJson(record);
      if (!block.end.isAfter(block.start))
        throw const FormatException('Invalid time block');
    case 'expense':
      if (record['minor'] is! int ||
          record['paid'] is! bool ||
          record['category'] is! String)
        throw const FormatException('Invalid transaction');
      ZoneClock().parse('${record['date']} 12:00');
    case 'nutrition':
      if (!finite(record['calories']) || record['partial'] is! bool)
        throw const FormatException('Invalid nutrition record');
      ZoneClock().parse('${record['date']} 12:00');
    case 'nutrition_day':
      ZoneClock().parse('${record['date']} 12:00');
      if (record['complete'] is! bool)
        throw const FormatException('Invalid nutrition confirmation');
    case 'exercise_alias':
      for (final key in ['provider', 'exercise', 'canonical']) {
        if (record[key] is! String ||
            (record[key] as String).trim().isEmpty ||
            (record[key] as String).length > 300)
          throw const FormatException('Invalid exercise mapping');
      }
    case 'measurement':
      if (!finite(record['value']) || record['unit'] is! String)
        throw const FormatException('Invalid measurement');
      ZoneClock().parse('${record['date']} 12:00');
    case 'note':
      if (record['body'] is! String || record['source'] is! String)
        throw const FormatException('Invalid source note');
    case 'habit':
      if (record['days'] is! List ||
          (record['days'] as List).any((day) => day is! String))
        throw const FormatException('Invalid habit history');
    case 'workout':
      if (record['exercise'] is! String || record['session'] is! String)
        throw const FormatException('Invalid workout');
      DateTime.parse(record['start']);
      DateTime.parse(record['end']);
    case 'settings':
      ZoneClock(record['zone']);
      if (record['weeklyMinor'] is! int || record['weeklyMinor'] < 0)
        throw const FormatException('Invalid budget');
      if (record['nutritionTargets'] != null) {
        if (record['nutritionTargets'] is! Map)
          throw const FormatException('Invalid nutrition targets');
        for (final value in (record['nutritionTargets'] as Map).values) {
          if (value is! num || !value.isFinite || value <= 0)
            throw const FormatException('Invalid nutrition target');
        }
      }
    case 'reflection':
      ZoneClock().parse('${record['date']} 12:00');
      if (record['body'] is! String ||
          record['energy'] is! int ||
          record['energy'] < 1 ||
          record['energy'] > 5)
        throw const FormatException('Invalid reflection');
    case 'focus':
      if (!finite(record['minutes']))
        throw const FormatException('Invalid focus duration');
    default:
      break;
  }
}

void _invalidateChangedNutrition(
  Map<String, Map<String, dynamic>> before,
  Map<String, Map<String, dynamic>> after,
) {
  final old = {
    for (final row in before.values.where((r) => r['kind'] == 'nutrition'))
      row['id']: row,
  };
  final current = {
    for (final row in after.values.where((r) => r['kind'] == 'nutrition'))
      row['id']: row,
  };
  final changedDates = <String>{};
  for (final id in {...old.keys, ...current.keys}) {
    if (jsonEncode(old[id]) != jsonEncode(current[id])) {
      if (old[id]?['date'] is String) changedDates.add(old[id]!['date']);
      if (current[id]?['date'] is String)
        changedDates.add(current[id]!['date']);
    }
  }
  after.updateAll(
    (id, row) =>
        row['kind'] == 'nutrition_day' &&
            row['complete'] == true &&
            changedDates.contains(row['date'])
        ? {
            ...row,
            'complete': false,
            'reason': 'Food records changed; review this date again.',
          }
        : row,
  );
}
