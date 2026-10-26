import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/calendar_geometry.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/planning.dart';

void main() {
  test('overlapping events occupy distinct lanes; midnight clips preserve original events', () {
    final day = CalendarDay(ZoneClock(), DateTime.utc(2026, 10, 26));
    final a = PlanBlock(
      id: 'a',
      title: 'A',
      start: day.start.subtract(const Duration(hours: 1)),
      end: day.start.add(const Duration(hours: 2)),
    );
    final b = PlanBlock(
      id: 'b',
      title: 'B',
      start: day.start.add(const Duration(hours: 1)),
      end: day.start.add(const Duration(hours: 3)),
    );
    final result = calendarPlacements([a, b], day);
    expect(result.first.startMinute, 0);
    expect(result.map((p) => p.column).toSet(), {0, 1});
    expect(result.every((p) => p.columns == 2), true);
    expect(a.start.isBefore(day.start), true);
  });
  test('DST days contain real 23/25 hours without normalizing events', () {
    final clock = ZoneClock('America/New_York');
    expect(CalendarDay(clock, DateTime.utc(2026, 3, 8)).minutes, 23 * 60);
    expect(CalendarDay(clock, DateTime.utc(2026, 11, 1)).minutes, 25 * 60);
  });
  test(
    'late short event layout stays finite and preserves related-task metadata',
    () {
      final day = CalendarDay(ZoneClock(), DateTime.utc(2026, 10, 26));
      final b = PlanBlock(
        id: 'short',
        title: 'Short',
        start: day.end.subtract(const Duration(minutes: 5)),
        end: day.end,
        relatedTaskIds: ['root', 'child'],
      );
      expect(calendarPlacements([b], day).single.minutes, 5);
      expect(PlanBlock.fromJson(b.toJson()).relatedTaskIds, ['root', 'child']);
    },
  );
  test('repeated DST hours create distinct explicit instants', () {
    final clock = ZoneClock('America/New_York'),
        day = CalendarDay(
          ZoneClock('America/New_York'),
          DateTime.utc(2026, 11, 1),
        );
    final first = day.start.add(const Duration(hours: 1)),
        second = day.start.add(const Duration(hours: 2));
    expect(clock.stamp(first), clock.stamp(second));
    expect(
      calendarCreateTime(clock, day, first),
      isNot(calendarCreateTime(clock, day, second)),
    );
    expect(
      clock
          .parse(calendarCreateTime(clock, day, first))
          .isAtSameMomentAs(first),
      true,
    );
    expect(calendarHourLabel(clock, day, first), contains('-04:00'));
    expect(calendarHourLabel(clock, day, second), contains('-05:00'));
  });
}
