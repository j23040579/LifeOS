import 'clock.dart';
import 'imports.dart';

/// Conservative offline iCalendar adapter: explicit occurrences only. Recurrence
/// and cancellation updates require review, never guessed or silently expanded.
ImportPreview importCalendar(String text, ZoneClock clock) {
  if (!text.contains('BEGIN:VCALENDAR') || !text.contains('END:VCALENDAR')) {
    throw const FormatException('Expected a complete VCALENDAR file.');
  }
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n[ \t]'), '')
      .split('\n');
  final records = <Map<String, dynamic>>[], diagnostics = <String>[];
  final checksum = fingerprint(text);
  Map<String, String>? properties;
  var event = 0, depth = 0;
  String decode(String value) => value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');
  DateTime parse(String property, String value) {
    final day = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
    final stamp = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$')
        .firstMatch(value);
    if (day != null) return clock.parse('${day[1]}-${day[2]}-${day[3]} 00:00');
    if (stamp == null)
      throw const FormatException('Unsupported date/time format');
    final iso =
        '${stamp[1]}-${stamp[2]}-${stamp[3]}T${stamp[4]}:${stamp[5]}:${stamp[6]}';
    if (stamp[7] == 'Z') return strictInstant('${iso}Z');
    final zone = RegExp(r'(?:^|;)TZID=([^;:]+)')
        .firstMatch(property)
        ?.group(1)
        ?.replaceAll('"', '');
    final localClock = zone == null ? clock : ZoneClock(zone);
    // Calendar times with seconds must remain exact; validate minutes through
    // the zone parser so DST gaps/ambiguities cannot be normalized silently.
    final seconds = int.parse(stamp[6]!);
    if (seconds > 59) throw const FormatException('Invalid seconds');
    return localClock
        .parse(iso.substring(0, 16))
        .add(Duration(seconds: seconds));
  }

  for (final line in lines) {
    if (line == 'BEGIN:VEVENT') {
      properties = {};
      depth = 0;
      event++;
      continue;
    }
    if (properties != null && line.startsWith('BEGIN:')) {
      depth++;
      continue;
    }
    if (properties != null && line.startsWith('END:') && line != 'END:VEVENT') {
      if (depth > 0) depth--;
      continue;
    }
    if (depth > 0) continue;
    if (line == 'END:VEVENT') {
      final props = properties;
      properties = null;
      if (props == null) continue;
      try {
        if (props.keys.any(
          (k) => {
            'RRULE',
            'RDATE',
            'EXDATE',
            'RECURRENCE-ID',
          }.contains(k.split(';').first),
        )) {
          throw const FormatException(
            'Recurring event needs an expanded occurrence export; not imported',
          );
        }
        if (props['STATUS'] == 'CANCELLED')
          throw const FormatException(
            'Cancellation requires manual review of the existing event',
          );
        if (props['TRANSP'] == 'TRANSPARENT')
          throw const FormatException(
            'Transparent event does not reserve time; not imported',
          );
        final uid = props['UID'];
        if (uid == null || uid.isEmpty)
          throw const FormatException('Missing UID');
        final startKey = props.keys.firstWhere(
          (k) => k.split(';').first == 'DTSTART',
        );
        final endKey = props.keys.firstWhere(
          (k) => k.split(';').first == 'DTEND',
        );
        final start = parse(startKey, props[startKey]!),
            end = parse(endKey, props[endKey]!);
        if (!end.isAfter(start))
          throw const FormatException('End must be after start');
        records.add({
          'id': 'ics-${fingerprint(uid)}',
          'kind': 'block',
          'title': decode(props['SUMMARY'] ?? 'Calendar event'),
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'source': 'Imported ICS',
          'externalId': uid,
          'batch': checksum,
          'fixed': true,
          'pinned': false,
          'sourceTimezone':
              RegExp(r'TZID=([^;:]+)').firstMatch(startKey)?.group(1) ??
              clock.name,
          'sourceStatus': props['STATUS'] ?? 'CONFIRMED',
          'description': decode(props['DESCRIPTION'] ?? ''),
        });
      } catch (error) {
        diagnostics.add('Event $event: $error');
      }
      continue;
    }
    if (properties != null) {
      final separator = line.indexOf(':');
      if (separator > 0)
        properties[line.substring(0, separator)] = line.substring(
          separator + 1,
        );
    }
  }
  if (properties != null) diagnostics.add('Truncated event at end of file');
  return ImportPreview(
    'iCalendar explicit occurrences',
    checksum,
    records,
    diagnostics,
  );
}

String exportCalendar(List<Map<String, dynamic>> blocks) {
  String escape(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('\r', '')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
  String stamp(String value) =>
      strictInstant(value)
          .toIso8601String()
          .replaceAll(RegExp('[-:]'), '')
          .split('.')
          .first +
      'Z';
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//LifeOS//Local planner//EN',
    'CALSCALE:GREGORIAN',
  ];
  final now = stamp(DateTime.now().toUtc().toIso8601String());
  for (final block in blocks.where(
    (b) => b['kind'] == 'block' && b['source'] == 'LifeOS',
  )) {
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${escape(block['id'])}@lifeos.local',
      'DTSTAMP:$now',
      'DTSTART:${stamp(block['start'])}',
      'DTEND:${stamp(block['end'])}',
      'SUMMARY:${escape(block['title'])}',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  // Fold on Unicode code points conservatively (<=~72 UTF-8 octets).
  final folded = <String>[];
  for (final line in lines) {
    var part = '', bytes = 0;
    for (final rune in line.runes) {
      final count = rune <= 0x7f
          ? 1
          : rune <= 0x7ff
          ? 2
          : rune <= 0xffff
          ? 3
          : 4;
      if (bytes + count > 72) {
        folded.add(part);
        part = ' ';
        bytes = 1;
      }
      part += String.fromCharCode(rune);
      bytes += count;
    }
    folded.add(part);
  }
  return '${folded.join('\r\n')}\r\n';
}
