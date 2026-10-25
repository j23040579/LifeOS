import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/imports.dart';

void main() {
  final importer = Importer(ZoneClock());
  const header =
      'title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe';
  const row =
      'Session,"Oct 13, 2026, 7:26 PM","Oct 13, 2026, 8:00 PM",,Squat,,,0,normal,,8,,,';
  test('Hevy preserves missing values, timezone, provenance and stable row identity', () {
    final preview = importer.hevy('$header\n$row');
    expect(preview.diagnostics, isEmpty);
    expect(preview.records, hasLength(1));
    final record = preview.records.single;
    expect(record['weightKg'], isNull);
    expect(record['rpe'], isNull);
    expect(record['reps'], 8);
    expect(record['start'], '2026-10-13T11:26:00.000Z');
    expect(record['id'], importer.hevy('$header\n$row').records.single['id']);
  });
  test('malformed rows are diagnosed, not silently coerced', () {
    final result = importer.hevy('$header\n$row\nwrong,column,count');
    expect(result.records, hasLength(1));
    expect(result.diagnostics.single, contains('Row 3'));
  });
  test(
    'nutrition excludes totals and preserves partial-day/missing semantics',
    () {
      final preview = importer.nutrition(
        'Jan 1, 2026\nFOODS\tCalories\tCarbs\tFat\tProtein\nBreakfast\nFood A\t100\t7g\t--\t2g\nTOTALS\t100\t7g\t0g\t2g',
      );
      expect(preview.records, hasLength(1));
      expect(preview.records.single['calories'], 100);
      expect(preview.records.single['fat'], isNull);
      expect(preview.records.single['partial'], isTrue);
    },
  );
  test('transaction dates and decimal precision are validated', () {
    final preview = importer.transactions(
      'date,description,amount,category\n2026-01-01,Groceries,12.30,Food\n2026-02-31,Wrong,2.00,Food',
    );
    expect(preview.records, hasLength(1));
    expect(preview.records.single['minor'], 1230);
    expect(preview.diagnostics, hasLength(1));
    expect(moneyMinor('-0.05'), -5);
    expect(() => moneyMinor('1.235'), throwsFormatException);
  });
  test('IANA clock rejects DST gaps and ambiguous local times', () {
    final clock = ZoneClock('America/New_York');
    expect(() => clock.parse('2026-03-08 02:30'), throwsFormatException);
    expect(() => clock.parse('2026-11-01 01:30'), throwsFormatException);
    expect(
      clock.parse('2026-11-01T01:30:00-04:00'),
      DateTime.utc(2026, 11, 1, 5, 30),
    );
  });
}
