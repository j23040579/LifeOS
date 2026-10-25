import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class ZoneClock {
  ZoneClock([this.name = 'Asia/Kuala_Lumpur']) {
    if (!_initialized) {
      data.initializeTimeZones();
      _initialized = true;
    }
    location = tz.getLocation(name);
  }
  static bool _initialized = false;
  final String name;
  late final tz.Location location;
  tz.TZDateTime local(DateTime instant) =>
      tz.TZDateTime.from(instant, location);
  tz.TZDateTime now() => tz.TZDateTime.now(location);
  DateTime parse(String text) {
    text = text.trim();
    if (RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text))
      return strictInstant(text);
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})$')
        .firstMatch(text);
    if (match == null)
      throw const FormatException(
        'Use YYYY-MM-DD HH:MM, or ISO time with UTC offset.',
      );
    final parts = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
    final result = tz.TZDateTime(
      location,
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
    );
    bool same(tz.TZDateTime date) =>
        date.year == parts[0] &&
        date.month == parts[1] &&
        date.day == parts[2] &&
        date.hour == parts[3] &&
        date.minute == parts[4];
    if (!same(result))
      throw const FormatException(
        'Invalid date or nonexistent local time during a clock change.',
      );
    for (var shift = -120; shift <= 120; shift += 15) {
      if (shift != 0 && same(local(result.add(Duration(minutes: shift)))))
        throw const FormatException(
          'Ambiguous clock-change time. Include an explicit UTC offset.',
        );
    }
    return DateTime.fromMillisecondsSinceEpoch(
      result.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  String stamp(DateTime instant) {
    final date = local(instant);
    return '${day(date)} ${two(date.hour)}:${two(date.minute)}';
  }

  String day(DateTime date) =>
      '${date.year}-${two(date.month)}-${two(date.day)}';
  String two(int n) => n.toString().padLeft(2, '0');
}

DateTime strictInstant(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null)
    throw const FormatException(
      'Use an ISO date/time with explicit UTC offset.',
    );
  final year = int.parse(match[1]!),
      month = int.parse(match[2]!),
      day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year ||
      date.month != month ||
      date.day != day ||
      int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6] ?? '0') > 59)
    throw const FormatException('Invalid calendar date or time.');
  final offset = match[7]!;
  if (offset != 'Z' &&
      (int.parse(offset.substring(1, 3)) > 14 ||
          int.parse(offset.substring(4)) > 59 ||
          int.parse(offset.substring(1, 3)) == 14 &&
              int.parse(offset.substring(4)) != 0))
    throw const FormatException('Invalid UTC offset.');
  return DateTime.parse(value).toUtc();
}
