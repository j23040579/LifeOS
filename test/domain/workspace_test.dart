import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/workspace_database.dart';
import 'package:lifeos/application/workspace.dart';
import 'package:lifeos/domain/planning.dart';

void main() {
  late Workspace store;
  late WorkspaceDatabase db;
  setUp(() async {
    db = WorkspaceDatabase(NativeDatabase.memory());
    store = Workspace(db);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await db.close();
  });
  test('source edits invalidate linked actions and completion preserves provenance', () async {
    await store.put({
      'id': 'note',
      'kind': 'note',
      'title': 'Idea',
      'body': 'Original',
      'source': 'My notes',
    }, 'Add note');
    final task = PlanTask(
      id: 'task',
      title: 'Act',
      minutes: 30,
      deadline: DateTime.utc(2030),
    );
    await store.put({
      ...task.toJson(),
      'kind': 'task',
      'sourceNoteId': 'note',
    }, 'Create action');
    await store.put({
      'id': 'note',
      'kind': 'note',
      'title': 'Idea',
      'body': 'Changed',
      'source': 'My notes',
    }, 'Edit source');
    expect(store.snapshot.records['task']!['sourceStale'], isTrue);
    await store.complete(task);
    expect(store.snapshot.records['task']!['sourceNoteId'], 'note');
  });
  test('invalid restore does not replace existing data', () async {
    await store.put({
      'id': 'note',
      'kind': 'note',
      'title': 'Keep',
      'body': 'Keep',
      'source': 'Own',
    }, 'Add');
    await expectLater(
      store.restore(
        '{"schema":1,"records":[{"id":"bad","kind":"expense","minor":"wrong"}]}',
      ),
      throwsFormatException,
    );
    expect(store.snapshot.records, contains('note'));
  });
  test('a fixed block cannot be silently rewritten by a proposal', () async {
    final fixed = PlanBlock(
      id: 'fixed',
      title: 'Exam',
      start: DateTime.utc(2030, 1, 1, 9),
      end: DateTime.utc(2030, 1, 1, 10),
      fixed: true,
    );
    await store.put({...fixed.toJson(), 'kind': 'block'}, 'Add exam');
    final result = await store.apply(
      ScheduleProposal(
        revision: store.snapshot.revision,
        blocks: [],
        unscheduled: [],
        conflicts: [],
      ),
    );
    expect(result, isFalse);
    expect(store.blocks.single.id, 'fixed');
  });
  test(
    'deleting a task preserves pinned blocks and detaches surviving children',
    () async {
      final parent = PlanTask(
        id: 'p',
        title: 'P',
        minutes: 60,
        deadline: DateTime.utc(2030),
      );
      final child = PlanTask(
        id: 'c',
        title: 'C',
        minutes: 30,
        deadline: DateTime.utc(2030),
        parentId: 'p',
      );
      await store.put({...parent.toJson(), 'kind': 'task'}, 'Parent');
      await store.put({...child.toJson(), 'kind': 'task'}, 'Child');
      final block = PlanBlock(
        id: 'b',
        title: 'Pinned',
        start: DateTime.utc(2029, 1, 1, 9),
        end: DateTime.utc(2029, 1, 1, 10),
        pinned: true,
        taskId: 'p',
      );
      await store.put({...block.toJson(), 'kind': 'block'}, 'Pin');
      expect(await store.complete(parent), isFalse);
      await store.deleteTask('p');
      expect(store.blocks.single.taskId, isNull);
      expect(store.blocks.single.pinned, isTrue);
      expect(store.tasks.single.parentId, isNull);
    },
  );
  test('forged schedule cannot evade ancestor deadline', () async {
    final parent = PlanTask(
      id: 'p',
      title: 'P',
      minutes: 60,
      deadline: DateTime.utc(2030, 1, 1, 12),
    );
    final child = PlanTask(
      id: 'c',
      title: 'C',
      minutes: 60,
      deadline: DateTime.utc(2030, 1, 1, 18),
      parentId: 'p',
    );
    await store.put({...parent.toJson(), 'kind': 'task'}, 'Parent');
    await store.put({...child.toJson(), 'kind': 'task'}, 'Child');
    final block = PlanBlock(
      id: 'b',
      title: 'Late',
      taskId: 'c',
      start: DateTime.utc(2030, 1, 1, 15),
      end: DateTime.utc(2030, 1, 1, 16),
    );
    expect(
      await store.apply(
        ScheduleProposal(
          revision: store.snapshot.revision,
          blocks: [block],
          unscheduled: [],
          conflicts: [],
        ),
      ),
      isFalse,
    );
    expect(store.blocks, isEmpty);
  });
}
