import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/availability.dart';
import 'package:lifeos/domain/clock.dart';

void main() {
  test('a future DST transition cannot silently alter planning hours', () {
    final clock = ZoneClock('America/New_York');
    expect(
      () => availabilityWindows(
        clock: clock,
        now: DateTime.utc(2026, 3, 7, 17),
        days: 2,
        start: '02:30',
        end: '04:00',
      ),
      throwsFormatException,
    );
    expect(
      () => availabilityWindows(
        clock: clock,
        now: DateTime.utc(2026, 10, 31, 16),
        days: 2,
        start: '01:30',
        end: '03:00',
      ),
      throwsFormatException,
    );
  });
  test('windows preserve local dates and never propose elapsed time', () {
    final clock = ZoneClock('Asia/Kuala_Lumpur'),
        now = DateTime.utc(2026, 10, 26, 4);
    final windows = availabilityWindows(
      clock: clock,
      now: now,
      days: 2,
      start: '09:00',
      end: '18:00',
    );
    expect(windows.first.start, now);
    expect(clock.stamp(windows.last.start), '2026-10-27 09:00');
    expect(windows.every((w) => !w.start.isBefore(now)), true);
  });
}
