import 'clock.dart';
import 'planning.dart';

/// Build local-intent windows without normalizing DST gaps or ambiguous hours.
/// Failure leaves the proposal unapplied so the user can choose different hours.
List<TimeWindow> availabilityWindows({
  required ZoneClock clock,
  required DateTime now,
  required int days,
  required String start,
  required String end,
}) {
  if (days < 1 || days > 30)
    throw const FormatException('Choose a horizon of 1–30 days.');
  final date = clock.local(now), windows = <TimeWindow>[];
  for (var i = 0; i < days; i++) {
    final day = clock.day(DateTime.utc(date.year, date.month, date.day + i));
    var from = clock.parse('$day $start');
    final until = clock.parse('$day $end');
    if (!until.isAfter(from))
      throw const FormatException(
        'Daily availability must end after it starts.',
      );
    if (from.isBefore(now)) from = now.toUtc();
    if (until.isAfter(from)) windows.add(TimeWindow(from, until));
  }
  return windows;
}
