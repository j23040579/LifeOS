import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/event_tasks.dart';
import 'package:lifeos/domain/planning.dart';

void main() {
  final day = DateTime.utc(2030, 1, 1);
  PlanTask task(
    String id,
    int minutes, {
    String? parent,
    TaskState state = TaskState.pending,
    int? estimate,
  }) => PlanTask(
    id: id,
    title: id,
    minutes: minutes,
    deadline: day.add(const Duration(hours: 18)),
    parentId: parent,
    state: state,
    estimatedMinutes: estimate,
  );
  PlanBlock event(List<String> ids) => PlanBlock(
    id: 'e',
    title: 'E',
    start: day,
    end: day.add(const Duration(hours: 1)),
    relatedTaskIds: ids,
  );
  test('linked ancestors and descendants produce one leaf and effort-weighted progress', () {
    final tasks = [
      task('root', 100),
      task('middle', 90, parent: 'root'),
      task('a', 30, parent: 'middle', state: TaskState.completed),
      task('b', 90, parent: 'root'),
    ];
    final summary = eventTasks(event(['root', 'a', 'middle']), tasks);
    expect(summary.roots.map((t) => t.id), ['root']);
    expect(summary.leaves, hasLength(2));
    expect(summary.progress, .25);
    expect(summary.completed, 1);
  });
  test('missing links and cyclic hierarchies report issues without hanging or faking completion', () {
    final summary = eventTasks(event(['missing', 'a', 'b']), [
      task('a', 30, parent: 'b'),
      task('b', 30, parent: 'a'),
    ]);
    expect(summary.issues, isNotEmpty);
    expect(summary.progress, isNull);
    expect(summary.leaves, isEmpty);
  });
  test('explicit remaining-effort reductions contribute partial credit', () {
    expect(
      eventTasks(event(['a']), [task('a', 30, estimate: 60)]).progress,
      .5,
    );
  });
  test(
    'colors survive JSON round trips and rescheduling without new dependencies',
    () {
      final pending = task('work', 60);
      final original = PlanBlock(
        id: 'original',
        title: 'Study',
        start: day.add(const Duration(hours: 9)),
        end: day.add(const Duration(hours: 10)),
        taskId: 'work',
        colorId: 'lavender',
      );
      expect(PlanBlock.fromJson(original.toJson()).colorId, 'lavender');
      final result = Scheduler().propose(
        revision: 0,
        tasks: [pending],
        existing: [original],
        windows: [
          TimeWindow(
            day.add(const Duration(hours: 10)),
            day.add(const Duration(hours: 12)),
          ),
        ],
      );
      expect(result.feasible, true);
      expect(result.blocks.single.colorId, 'lavender');
      expect(result.blocks.single.start, day.add(const Duration(hours: 10)));
    },
  );
  test(
    'legacy and unknown future colors remain readable and preserve identity',
    () {
      final legacy = event([]).toJson()..remove('colorId');
      expect(PlanBlock.fromJson(legacy).colorId, 'rose');
      final future = {...legacy, 'colorId': 'future-color'};
      expect(PlanBlock.fromJson(future).toJson()['colorId'], 'future-color');
    },
  );
}
