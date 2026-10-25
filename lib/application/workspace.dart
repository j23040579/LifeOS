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
    void Function(Map<String, Map<String, dynamic>>) edit,
  ) async {
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

  Future<bool> put(Map<String, dynamic> record, String description) =>
      change(description, (records) {
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
      });
  Future<bool> remove(String id) => change('Delete local record', (records) {
    records.remove(id);
    records.updateAll(
      (_, value) =>
          value['sourceNoteId'] == id ? {...value, 'sourceStale': true} : value,
    );
  });
  Future<bool> deleteTask(String id) => change('Delete task', (records) {
    records.remove(id);
    final remove = <String>[];
    records.updateAll((key, value) {
      if (value['kind'] == 'task' && value['parentId'] == id)
        return {...value, 'parentId': null};
      if (value['kind'] == 'block' && value['taskId'] == id) {
        if (value['source'] == 'LifeOS' &&
            value['fixed'] != true &&
            value['pinned'] != true) {
          remove.add(key);
          return value;
        }
        return {...value, 'taskId': null};
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
    }, 'Change task completion');
  }

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
      records.removeWhere((_, r) => r['kind'] == 'block');
      for (final block in proposal.blocks) {
        records[block.id] = {...block.toJson(), 'kind': 'block'};
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
    });
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
    'expense',
    'measurement',
    'focus',
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
    case 'focus':
      if (!finite(record['minutes']))
        throw const FormatException('Invalid focus duration');
    default:
      break;
  }
}
