import 'package:timezone/timezone.dart' as tz;

import 'clock.dart';
import 'planning.dart';

class CalendarDay {
  CalendarDay(ZoneClock clock, DateTime date)
    : start = tz.TZDateTime(
        clock.location,
        date.year,
        date.month,
        date.day,
      ).toUtc(),
      end = tz.TZDateTime(
        clock.location,
        date.year,
        date.month,
        date.day + 1,
      ).toUtc();
  final DateTime start, end;
  int get minutes => end.difference(start).inMinutes;
}

class CalendarPlacement {
  const CalendarPlacement(
    this.block,
    this.startMinute,
    this.minutes,
    this.column,
    this.columns,
  );
  final PlanBlock block;
  final double startMinute, minutes;
  final int column, columns;
}

List<CalendarPlacement> calendarPlacements(
  List<PlanBlock> blocks,
  CalendarDay day,
) {
  final sorted =
      blocks
          .where((b) => b.start.isBefore(day.end) && b.end.isAfter(day.start))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final result = <CalendarPlacement>[],
      group = <({PlanBlock block, double start, double length, int lane})>[];
  final ends = <double>[];
  var groupEnd = 0.0;
  void flush() {
    for (final item in group)
      result.add(
        CalendarPlacement(
          item.block,
          item.start,
          item.length,
          item.lane,
          ends.length,
        ),
      );
    group.clear();
    ends.clear();
    groupEnd = 0;
  }

  for (final block in sorted) {
    final start = block.start.isBefore(day.start)
        ? 0.0
        : block.start.difference(day.start).inSeconds / 60;
    final end = block.end.isAfter(day.end)
        ? day.minutes.toDouble()
        : block.end.difference(day.start).inSeconds / 60;
    // Keep short events tappable without hiding adjacent visual cards.
    final remaining = day.minutes - start;
    final length = remaining < 48
        ? remaining
        : (end - start).clamp(48.0, remaining);
    if (group.isNotEmpty && start >= groupEnd) flush();
    var lane = ends.indexWhere((end) => end <= start);
    if (lane < 0) {
      lane = ends.length;
      ends.add(start + length);
    } else {
      ends[lane] = start + length;
    }
    if (start + length > groupEnd) groupEnd = start + length;
    group.add((block: block, start: start, length: length, lane: lane));
  }
  flush();
  return result;
}

/// A repeated wall-clock hour needs an explicit instant to remain unambiguous.
String calendarCreateTime(ZoneClock clock, CalendarDay day, DateTime instant) =>
    day.minutes == 1440
    ? clock.stamp(instant)
    : instant.toUtc().toIso8601String();
String calendarHourLabel(ZoneClock clock, CalendarDay day, DateTime instant) {
  final wall = clock.stamp(instant).substring(11);
  if (day.minutes == 1440) return wall;
  final minutes = clock.local(instant).timeZoneOffset.inMinutes;
  return '$wall\n${minutes < 0 ? '-' : '+'}${clock.two(minutes.abs() ~/ 60)}:${clock.two(minutes.abs() % 60)}';
}
