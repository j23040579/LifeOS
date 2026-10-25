import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/planning.dart';

void main() {
  final day = DateTime.utc(2026, 10, 26);
  DateTime at(int hour, [int minute = 0]) =>
      day.add(Duration(hours: hour, minutes: minute));
  PlanTask task(
    String id,
    int minutes, {
    int due = 18,
    List<String> dependencies = const [],
    bool split = true,
  }) => PlanTask(
    id: id,
    title: id,
    minutes: minutes,
    deadline: at(due),
    dependencies: dependencies,
    splittable: split,
  );
  ScheduleProposal plan(
    List<PlanTask> tasks, {
    List<PlanBlock> blocks = const [],
    List<TimeWindow>? windows,
  }) => Scheduler().propose(
    revision: 7,
    tasks: tasks,
    existing: blocks,
    windows: windows ?? [TimeWindow(at(8), at(18))],
  );
  test('fixed dinner survives flexible replanning; deadlines never change', () {
    final tasks = [task('assignment', 180), task('gym', 60)];
    final dinner = PlanBlock(
      id: 'dinner',
      title: 'Dinner',
      start: at(17),
      end: at(19),
      fixed: true,
    );
    final result = plan(tasks, blocks: [dinner]);
    expect(result.feasible, isTrue);
    expect(result.blocks.contains(dinner), isTrue);
    expect(tasks.first.deadline, at(18));
    for (final block in result.blocks.where((b) => b.taskId != null)) {
      expect(block.end.isAfter(at(18)), isFalse);
      expect(block.overlaps(dinner), isFalse);
    }
  });
  test('cross-midnight commitments are excluded from availability', () {
    final event = PlanBlock(
      id: 'night',
      title: 'Night out',
      start: at(22),
      end: at(26),
      fixed: true,
    );
    final result = plan(
      [task('study', 120, due: 30)],
      blocks: [event],
      windows: [TimeWindow(at(21), at(29))],
    );
    expect(result.feasible, isTrue);
    expect(
      result.blocks
          .where((b) => b.taskId == 'study')
          .every((b) => !b.overlaps(event)),
      isTrue,
    );
  });
  test('genuine hard overlaps are reported without moving commitments', () {
    final blocks = [
      PlanBlock(id: 'a', title: 'Exam', start: at(9), end: at(11), fixed: true),
      PlanBlock(
        id: 'b',
        title: 'Appointment',
        start: at(10),
        end: at(12),
        fixed: true,
      ),
    ];
    final result = plan([task('study', 60)], blocks: blocks);
    expect(result.feasible, isFalse);
    expect(result.conflicts.single, contains('overlaps'));
    expect(result.blocks, blocks);
  });
  test(
    'dependencies are scheduled first even with earlier dependent deadline',
    () {
      final result = plan([
        task('dependent', 60, due: 12, dependencies: ['first']),
        task('first', 60, due: 18),
      ]);
      final first = result.blocks.firstWhere((b) => b.taskId == 'first');
      final next = result.blocks.firstWhere((b) => b.taskId == 'dependent');
      expect(next.start.isBefore(first.end), isFalse);
      expect(result.feasible, isTrue);
    },
  );
  test('cycles and missing prerequisites report unscheduled work', () {
    expect(
      plan([
        task('a', 60, dependencies: ['b']),
        task('b', 60, dependencies: ['a']),
      ]).unscheduled,
      hasLength(2),
    );
    expect(
      plan([
        task('a', 60, dependencies: ['missing']),
      ]).unscheduled,
      ['a'],
    );
  });
  test('overload rolls back tentative pieces rather than claiming success', () {
    final result = plan(
      [task('large', 180)],
      windows: [TimeWindow(at(8), at(9))],
    );
    expect(result.unscheduled, ['large']);
    expect(result.blocks, isEmpty);
    expect(result.feasible, isFalse);
  });
  test('manually pinned work is honored without duplication', () {
    final pinned = PlanBlock(
      id: 'pin',
      title: 'Study',
      taskId: 'study',
      start: at(15),
      end: at(16),
      pinned: true,
    );
    final result = plan([task('study', 60)], blocks: [pinned]);
    expect(result.blocks, [pinned]);
    expect(result.feasible, isTrue);
  });
  test('unsplittable work does not fit fragmented gaps', () {
    final fixed = PlanBlock(
      id: 'break',
      title: 'Break',
      start: at(9),
      end: at(10),
      fixed: true,
    );
    expect(
      plan(
        [task('study', 120, split: false)],
        blocks: [fixed],
        windows: [TimeWindow(at(8), at(11))],
      ).feasible,
      isFalse,
    );
  });
  test('overlapping availability cannot produce double bookings', () {
    expect(
      plan(
        [task('study', 60)],
        windows: [TimeWindow(at(8), at(10)), TimeWindow(at(9), at(11))],
      ).conflicts,
      isNotEmpty,
    );
  });
  test('completed work is not rescheduled', () {
    final done = PlanTask(
      id: 'done',
      title: 'Done',
      minutes: 60,
      deadline: at(12),
      state: TaskState.completed,
    );
    expect(plan([done]).blocks, isEmpty);
  });
  test('extension releases deadline pressure; procrastination preserves original due date', () {
    final original = task('work', 120, due: 9);
    expect(plan([original]).feasible, isFalse);
    final extended = task('work', 120, due: 14);
    expect(plan([extended]).feasible, isTrue);
    expect(original.deadline, at(9));
  });
  test('nested leaf work inherits deadline and effort weighting without parent duplication', () {
    final parent = task('assignment', 300, due: 12);
    final a = PlanTask(
      id: 'a',
      title: 'A',
      minutes: 60,
      estimatedMinutes: 60,
      deadline: at(18),
      parentId: parent.id,
      state: TaskState.completed,
    );
    final b = PlanTask(
      id: 'b',
      title: 'B',
      minutes: 180,
      estimatedMinutes: 180,
      deadline: at(18),
      parentId: parent.id,
    );
    expect(weightedTaskProgress(parent.id, [parent, a, b]), .25);
    final hierarchy = resolveHierarchy([parent, a, b]);
    expect(hierarchy.leaves.map((t) => t.deadline), everyElement(at(12)));
    final result = plan([parent, a, b]);
    expect(result.feasible, isTrue);
    expect(result.blocks.map((b) => b.taskId).toSet(), {'b'});
  });
  test('paused parent preserves completed child and blocks pending child scheduling', () {
    final parent = PlanTask(
      id: 'p',
      title: 'P',
      minutes: 120,
      deadline: at(18),
      state: TaskState.paused,
    );
    final done = PlanTask(
      id: 'd',
      title: 'D',
      minutes: 60,
      deadline: at(18),
      parentId: 'p',
      state: TaskState.completed,
    );
    final todo = PlanTask(
      id: 't',
      title: 'T',
      minutes: 60,
      deadline: at(18),
      parentId: 'p',
    );
    final hierarchy = resolveHierarchy([parent, done, todo]);
    expect(hierarchy.leaves.first.state, TaskState.completed);
    expect(hierarchy.leaves.last.state, TaskState.paused);
    expect(plan([parent, done, todo]).blocks, isEmpty);
  });
  test('free-time reserve uses only time left after immutable commitments', () {
    final fixed = PlanBlock(
      id: 'f',
      title: 'Class',
      start: at(9),
      end: at(10),
      fixed: true,
    );
    final windows = reserveFreeTime([TimeWindow(at(8), at(13))], [fixed], 25);
    expect(
      windows.fold<int>(0, (n, w) => n + w.end.difference(w.start).inMinutes),
      180,
    );
    final result = plan(
      [task('study', 180)],
      blocks: [fixed],
      windows: windows,
    );
    expect(result.feasible, isTrue);
    expect(
      result.blocks
          .where((b) => b.taskId == 'study')
          .every((b) => !b.overlaps(fixed)),
      isTrue,
    );
  });
}
