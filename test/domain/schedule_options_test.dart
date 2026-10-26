import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/planning.dart';
import 'package:lifeos/domain/schedule_options.dart';

void main() {
  final clock = ZoneClock('UTC');
  final base = DateTime.utc(2026, 10, 26);
  DateTime at(int hour) => base.add(Duration(hours: hour));
  PlanTask task(String id, int minutes, int deadline, {int priority = 2}) =>
      PlanTask(
        id: id,
        title: id,
        minutes: minutes,
        deadline: at(deadline),
        priority: priority,
      );
  test(
    'ranking exposes a feasible deadline policy when importance ordering fails',
    () {
      final tasks = [
        task('urgent', 60, 11),
        task('important', 90, 18, priority: 5),
      ];
      final options = scheduleOptions(
        revision: 8,
        tasks: tasks,
        existing: [],
        windows: [TimeWindow(at(9), at(12))],
        clock: clock,
      );
      expect(options.length, 3);
      expect(options.first.proposal.feasible, true);
      expect(options.first.name, 'Deadline first');
      expect(options.first.proposal.revision, 8);
      final priority = options.firstWhere((o) => o.name == 'Importance first');
      expect(priority.proposal.unscheduled, ['urgent']);
      expect(tasks.first.deadline, at(11));
      for (final option in options) {
        for (final block in option.proposal.blocks) {
          expect(
            block.end.isAfter(
              tasks.firstWhere((t) => t.id == block.taskId).deadline,
            ),
            false,
          );
        }
      }
    },
  );
  test('spread policy reduces peak flexible time without changing hard commitments', () {
    final fixed = PlanBlock(
      id: 'fixed',
      title: 'Appointment',
      start: at(13),
      end: at(14),
      fixed: true,
      colorId: 'ocean',
    );
    final options = scheduleOptions(
      revision: 1,
      tasks: [task('a', 90, 48), task('b', 90, 48)],
      existing: [fixed],
      windows: [TimeWindow(at(8), at(12)), TimeWindow(at(32), at(36))],
      clock: clock,
    );
    final spread = options.firstWhere((o) => o.name == 'Spread the work');
    final deadline = options.firstWhere((o) => o.name == 'Deadline first');
    expect(spread.proposal.feasible, true);
    expect(spread.peakFlexibleMinutes, 90);
    expect(deadline.peakFlexibleMinutes, 180);
    expect(options.first.name, 'Spread the work');
    for (final option in options) {
      expect(option.proposal.blocks, contains(fixed));
      expect(
        option.proposal.blocks
            .where((b) => b != fixed)
            .any((b) => b.overlaps(fixed)),
        false,
      );
    }
  });
  test('invalid windows are not repaired silently by alternative policies', () {
    final options = scheduleOptions(
      revision: 1,
      tasks: [task('a', 60, 18)],
      existing: [],
      windows: [TimeWindow(at(8), at(12)), TimeWindow(at(10), at(14))],
      clock: clock,
    );
    expect(options.every((o) => !o.proposal.feasible), true);
    expect(
      options.every(
        (o) => o.proposal.conflicts.contains('Availability windows overlap'),
      ),
      true,
    );
  });
  test(
    'empty availability produces explicit unplanned work for all policies',
    () {
      final options = scheduleOptions(
        revision: 1,
        tasks: [task('a', 60, 18)],
        existing: [],
        windows: [],
        clock: clock,
      );
      expect(options.every((o) => o.proposal.unscheduled.contains('a')), true);
    },
  );
  test('spread metrics follow actual DST day boundaries across midnight', () {
    final zone = ZoneClock('America/New_York');
    final start = zone.parse('2027-11-07 00:00'),
        end = zone.parse('2027-11-08 02:00');
    final options = scheduleOptions(
      revision: 1,
      tasks: [
        PlanTask(
          id: 'long',
          title: 'Long',
          minutes: 1560,
          deadline: end,
          minimumBlock: 1,
        ),
      ],
      existing: [],
      windows: [TimeWindow(start, end)],
      clock: zone,
    );
    final earliest = options.firstWhere((o) => o.name == 'Deadline first');
    expect(earliest.proposal.feasible, true);
    expect(
      earliest.peakFlexibleMinutes,
      1500,
    ); // The fall-back date is 25 hours.
  });
}
