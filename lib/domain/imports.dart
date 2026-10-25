import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import 'clock.dart';

String shaForBytes(List<int> bytes) => sha256.convert(bytes).toString();

String fingerprint(String text) => sha256.convert(utf8.encode(text)).toString();

class ImportPreview {
  const ImportPreview(
    this.source,
    this.checksum,
    this.records,
    this.diagnostics,
  );
  final String source, checksum;
  final List<Map<String, dynamic>> records;
  final List<String> diagnostics;
}

class Importer {
  Importer(this.clock);
  final ZoneClock clock;
  ImportPreview hevy(String text) {
    final rows = csv.decode(text.replaceFirst('\ufeff', ''));
    if (rows.isEmpty) throw const FormatException('The CSV is empty.');
    final header = rows.first.map((v) => v.toString().trim()).toList();
    for (final column in [
      'title',
      'start_time',
      'end_time',
      'exercise_title',
      'set_index',
      'set_type',
      'weight_kg',
      'reps',
    ]) {
      if (!header.contains(column))
        throw FormatException('Missing Hevy column: $column');
    }
    final records = <Map<String, dynamic>>[];
    final diagnostics = <String>[];
    final occurrences = <String, int>{};
    final checksum = fingerprint(text);
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].every((v) => v.toString().trim().isEmpty)) continue;
      if (rows[i].length != header.length) {
        diagnostics.add('Row ${i + 1}: column count does not match header.');
        continue;
      }
      final raw = {
        for (var c = 0; c < header.length; c++)
          header[c]: rows[i][c].toString().trim(),
      };
      try {
        final start = _hevyDate(raw['start_time']!);
        final end = _hevyDate(raw['end_time']!);
        if (end.isBefore(start))
          throw const FormatException('Session end precedes its start');
        final session = fingerprint(
          '${raw['title']}|${start.toIso8601String()}',
        );
        final identity =
            '$session|${raw['exercise_title']}|${raw['set_index']}';
        final occurrence = occurrences.update(
          identity,
          (v) => v + 1,
          ifAbsent: () => 0,
        );
        num? numeric(String key) {
          final value = raw[key] ?? '';
          if (value.isEmpty) return null;
          final parsed = num.tryParse(value);
          if (parsed == null || !parsed.isFinite || parsed < 0)
            throw FormatException('Invalid $key');
          return parsed;
        }

        final record = <String, dynamic>{
          'id': 'hevy-${fingerprint('$identity|$occurrence')}',
          'kind': 'workout',
          'source': 'Hevy CSV',
          'sourceTimezone': clock.name,
          'batch': checksum,
          'session': session,
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'title': raw['title'],
          'exercise': raw['exercise_title'],
          'setType': raw['set_type'],
          'setIndex': numeric('set_index'),
          'weightKg': numeric('weight_kg'),
          'reps': numeric('reps'),
          'rpe': numeric('rpe'),
          'distanceKm': numeric('distance_km'),
          'durationSeconds': numeric('duration_seconds'),
          'raw': raw,
        };
        if (record['rpe'] != null && record['rpe'] > 10)
          throw const FormatException('RPE exceeds 10');
        records.add(record);
      } catch (e) {
        diagnostics.add(
          'Row ${i + 1}: ${e is FormatException ? e.message : 'Invalid row'}',
        );
      }
    }
    return ImportPreview('Hevy CSV', checksum, records, diagnostics);
  }

  DateTime _hevyDate(String text) {
    final match = RegExp(
      r'^(\w{3}) (\d{1,2}), (\d{4}), (\d{1,2}):(\d{2}) (AM|PM)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null)
      throw const FormatException(
        'Unsupported date format; expected Oct 13, 2026, 7:26 PM',
      );
    final month =
        [
          'jan',
          'feb',
          'mar',
          'apr',
          'may',
          'jun',
          'jul',
          'aug',
          'sep',
          'oct',
          'nov',
          'dec',
        ].indexOf(match[1]!.toLowerCase()) +
        1;
    final hour = int.parse(match[4]!);
    if (month == 0 || hour < 1 || hour > 12)
      throw const FormatException('Invalid date');
    final hour24 = hour % 12 + (match[6]!.toUpperCase() == 'PM' ? 12 : 0);
    return clock.parse(
      '${match[3]}-${clock.two(month)}-${clock.two(int.parse(match[2]!))} ${clock.two(hour24)}:${match[5]}',
    );
  }

  ImportPreview nutrition(String text) {
    final records = <Map<String, dynamic>>[], diagnostics = <String>[];
    String? date, meal;
    List<String>? header;
    final checksum = fingerprint(text);
    final occurrences = <String, int>{};
    final lines = text.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final dateMatch = RegExp(r'^(\w{3}) (\d{1,2}), (\d{4})$')
          .firstMatch(line);
      if (dateMatch != null) {
        final month =
            [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ].indexOf(dateMatch[1]!) +
            1;
        if (month == 0) {
          diagnostics.add('Line ${i + 1}: invalid date');
          date = null;
          continue;
        }
        date =
            '${dateMatch[3]}-${clock.two(month)}-${clock.two(int.parse(dateMatch[2]!))}';
        meal = null;
        continue;
      }
      final cells = line.split('\t');
      if (cells.first == 'FOODS') {
        header = cells;
        continue;
      }
      if (cells.first == 'TOTALS')
        continue; // Item rows are authoritative; never add both.
      if (cells.length == 1) {
        meal = cells.first;
        continue;
      }
      if (date == null || header == null || meal == null) {
        diagnostics.add('Line ${i + 1}: missing date, header, or meal');
        continue;
      }
      if (cells.length != header.length) {
        diagnostics.add('Line ${i + 1}: wrong column count');
        continue;
      }
      final raw = {for (var j = 0; j < header.length; j++) header[j]: cells[j]};
      num? amount(String key) {
        final value = raw[key];
        if (value == null || value == '--' || value.isEmpty) return null;
        final parsed = num.tryParse(value.replaceAll(RegExp(r'(mg|g)$'), ''));
        return parsed != null && parsed.isFinite && parsed >= 0
            ? parsed
            : double.nan;
      }

      final calories = amount('Calories');
      final nutrients = {
        for (final key in [
          'Carbs',
          'Fat',
          'Protein',
          'Cholest',
          'Sodium',
          'Sugar',
          'Fiber',
        ])
          key: amount(key),
      };
      if (calories == null ||
          !calories.isFinite ||
          calories < 0 ||
          nutrients.values.any((v) => v != null && !v.isFinite)) {
        diagnostics.add('Line ${i + 1}: invalid calories or nutrient value');
        continue;
      }
      final identity = '$date|$meal|${cells.first}';
      final occurrence = occurrences.update(
        identity,
        (v) => v + 1,
        ifAbsent: () => 0,
      );
      records.add({
        'id': 'nutrition-${fingerprint('$identity|$occurrence')}',
        'kind': 'nutrition',
        'source': 'MyFitnessPal TXT',
        'batch': checksum,
        'date': date,
        'meal': meal,
        'title': cells.first,
        'calories': calories,
        'carbs': nutrients['Carbs'],
        'fat': nutrients['Fat'],
        'protein': nutrients['Protein'],
        'partial': true,
        'raw': raw,
      });
    }
    if (records.isEmpty && diagnostics.isEmpty)
      throw const FormatException('No supported MyFitnessPal item rows found.');
    return ImportPreview('MyFitnessPal TXT', checksum, records, diagnostics);
  }

  ImportPreview transactions(String text) {
    final rows = csv.decode(text.replaceFirst('\ufeff', ''));
    if (rows.isEmpty ||
        rows.first.map((v) => v.toString().toLowerCase()).join(',') !=
            'date,description,amount,category') {
      throw const FormatException(
        'Map/export CSV as date,description,amount,category. Dates: YYYY-MM-DD; expenses positive, credits negative.',
      );
    }
    final records = <Map<String, dynamic>>[], diagnostics = <String>[];
    final checksum = fingerprint(text);
    final occurrences = <String, int>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i].map((v) => v.toString()).toList();
      if (row.length != 4) {
        diagnostics.add('Row ${i + 1}: expected four columns');
        continue;
      }
      try {
        final minor = moneyMinor(row[2]);
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(row[0]))
          throw const FormatException('Date must be YYYY-MM-DD');
        clock.parse('${row[0]} 12:00');
        final identity = jsonEncode(row);
        final occurrence = occurrences.update(
          identity,
          (v) => v + 1,
          ifAbsent: () => 0,
        );
        records.add({
          'id': 'expense-${fingerprint('$identity|$occurrence')}',
          'kind': 'expense',
          'title': row[1],
          'minor': minor,
          'category': row[3],
          'date': row[0],
          'paid': true,
          'source': 'Mapped transaction CSV',
          'batch': checksum,
        });
      } catch (e) {
        diagnostics.add('Row ${i + 1}: invalid date or amount');
      }
    }
    return ImportPreview(
      'Mapped transaction CSV',
      checksum,
      records,
      diagnostics,
    );
  }
}

int moneyMinor(String input) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(input.trim());
  if (match == null)
    throw const FormatException(
      'Use an amount with at most two decimal places.',
    );
  if (match[2]!.length > 8)
    throw const FormatException('Amount is outside the supported range.');
  return (int.parse(match[2]!) * 100 +
          int.parse((match[3] ?? '').padRight(2, '0'))) *
      (match[1] == '-' ? -1 : 1);
}
