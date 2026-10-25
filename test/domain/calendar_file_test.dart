import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/calendar_file.dart';
import 'package:lifeos/domain/clock.dart';

void main() {
  final clock = ZoneClock('Asia/Kuala_Lumpur');
  String calendar(String event) =>
      'BEGIN:VCALENDAR\r\n$event\r\nEND:VCALENDAR\r\n';
  test('calendar preserves timezone, ownership, midnight boundary and folded titles', () {
    final result = importCalendar(
      calendar(
        'BEGIN:VEVENT\r\nUID:night\r\nDTSTART;TZID=Asia/Kuala_Lumpur:20261030T220000\r\nDTEND;TZID=Asia/Kuala_Lumpur:20261031T020000\r\nSUMMARY:Badminton and\r\n  supper\r\nEND:VEVENT',
      ),
      clock,
    );
    expect(result.diagnostics, isEmpty);
    final block = result.records.single;
    expect(block['title'], 'Badminton and supper');
    expect(block['fixed'], true);
    expect(
      DateTime.parse(block['end'])
          .difference(DateTime.parse(block['start']))
          .inHours,
      4,
    );
    expect(
      importCalendar(
        calendar(
          'BEGIN:VEVENT\r\nUID:night\r\nDTSTART:20261030T140000Z\r\nDTEND:20261030T180000Z\r\nEND:VEVENT',
        ),
        clock,
      ).records.single['id'],
      block['id'],
    );
  });
  test('recurrence, cancellation and invalid clock times are rejected with diagnostics', () {
    final result = importCalendar(
      calendar(
        'BEGIN:VEVENT\nUID:r\nRRULE:FREQ=DAILY\nDTSTART:20261030T140000Z\nDTEND:20261030T150000Z\nEND:VEVENT\nBEGIN:VEVENT\nUID:c\nSTATUS:CANCELLED\nEND:VEVENT\nBEGIN:VEVENT\nUID:gap\nDTSTART;TZID=America/New_York:20260308T023000\nDTEND;TZID=America/New_York:20260308T033000\nEND:VEVENT',
      ),
      clock,
    );
    expect(result.records, isEmpty);
    expect(result.diagnostics, hasLength(3));
  });
  test(
    'export includes only LifeOS-owned blocks and round-trips escaped text',
    () {
      final text = exportCalendar([
        {
          'id': 'local',
          'kind': 'block',
          'source': 'LifeOS',
          'title': 'Study, review;\nnext',
          'start': '2026-10-26T01:00:00.000Z',
          'end': '2026-10-26T02:00:00.000Z',
        },
        {
          'id': 'outside',
          'kind': 'block',
          'source': 'Imported ICS',
          'title': 'Private',
          'start': '2026-10-26T01:00:00.000Z',
          'end': '2026-10-26T02:00:00.000Z',
        },
      ]);
      expect(text, isNot(contains('Private')));
      final result = importCalendar(text, clock);
      expect(result.diagnostics, isEmpty);
      expect(result.records.single['title'], 'Study, review;\nnext');
    },
  );
}
