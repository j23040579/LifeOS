import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Optimistic revision checks protect edits made in another browser tab.
class RevisionConflict implements Exception {
  const RevisionConflict();
  @override
  String toString() =>
      'Your data changed. Reload before applying this proposal.';
}

class WorkspaceSnapshot {
  const WorkspaceSnapshot(this.revision, this.records);
  final int revision;
  final Map<String, Map<String, dynamic>> records;
}

class WorkspaceDatabase extends GeneratedDatabase {
  WorkspaceDatabase(super.executor);
  WorkspaceDatabase.local({String name = 'lifeos'})
    : super(
        driftDatabase(
          name: name,
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) {
              if (result.chosenImplementation ==
                      WasmStorageImplementation.inMemory ||
                  result.chosenImplementation ==
                      WasmStorageImplementation.unsafeIndexedDb) {
                throw StateError(
                  'Reliable browser storage is unavailable. Use a current Chrome browser on localhost, or Windows desktop.',
                );
              }
            },
          ),
        ),
      );
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE revision (singleton INTEGER PRIMARY KEY CHECK(singleton=1), value INTEGER NOT NULL)',
      );
      await customStatement('INSERT INTO revision VALUES (1,0)');
      await customStatement(
        'CREATE TABLE records (id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL)',
      );
      await customStatement('CREATE INDEX record_kind ON records(kind)');
      await customStatement(
        'CREATE TABLE audit (revision INTEGER PRIMARY KEY, at TEXT NOT NULL, description TEXT NOT NULL, before_state TEXT NOT NULL, undone INTEGER NOT NULL DEFAULT 0)',
      );
    },
    onUpgrade: (_, from, to) async {
      if (from < 2)
        await customStatement(
          'ALTER TABLE audit ADD COLUMN undone INTEGER NOT NULL DEFAULT 0',
        );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA secure_delete=ON');
    },
  );
  Future<WorkspaceSnapshot> load() => transaction(() async {
    final revision = (await customSelect(
      'SELECT value FROM revision WHERE singleton=1',
    ).getSingle()).read<int>('value');
    final rows = await customSelect(
      'SELECT id,payload FROM records ORDER BY id',
    ).get();
    return WorkspaceSnapshot(revision, {
      for (final row in rows)
        row.read<String>('id'): Map<String, dynamic>.from(
          jsonDecode(row.read<String>('payload')),
        ),
    });
  });
  Future<WorkspaceSnapshot> save(
    WorkspaceSnapshot expected,
    Map<String, Map<String, dynamic>> records,
    String description,
  ) => transaction(() async {
    final current = await load();
    if (current.revision != expected.revision) throw const RevisionConflict();
    for (final entry in records.entries) {
      if (entry.key != entry.value['id'] || entry.value['kind'] is! String) {
        throw const FormatException('Invalid record identity');
      }
    }
    await customStatement(
      'INSERT INTO audit (revision,at,description,before_state) VALUES (?,?,?,?)',
      [
        current.revision + 1,
        DateTime.now().toUtc().toIso8601String(),
        description,
        jsonEncode(current.records),
      ],
    );
    await customStatement('DELETE FROM audit WHERE revision < ?', [
      current.revision - 48,
    ]);
    await customStatement('DELETE FROM records');
    for (final entry in records.entries) {
      await customStatement('INSERT INTO records VALUES (?,?,?)', [
        entry.key,
        entry.value['kind'],
        jsonEncode(entry.value),
      ]);
    }
    await customStatement(
      'UPDATE revision SET value=value+1 WHERE singleton=1',
    );
    return load();
  });
  Future<WorkspaceSnapshot> undo(WorkspaceSnapshot expected) => transaction(
    () async {
      final current = await load();
      if (current.revision != expected.revision) throw const RevisionConflict();
      final row = await customSelect(
        "SELECT revision,before_state FROM audit WHERE undone=0 AND description NOT LIKE 'Undo revision %' ORDER BY revision DESC LIMIT 1",
      ).getSingleOrNull();
      if (row == null) throw StateError('No retained change to undo');
      final revision = row.read<int>('revision');
      final records = Map<String, dynamic>.from(
        jsonDecode(row.read<String>('before_state')),
      ).map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
      final result = await save(expected, records, 'Undo revision $revision');
      await customStatement('UPDATE audit SET undone=1 WHERE revision=?', [
        revision,
      ]);
      return result;
    },
  );

  Future<WorkspaceSnapshot> erase(WorkspaceSnapshot expected) =>
      transaction(() async {
        if ((await load()).revision != expected.revision)
          throw const RevisionConflict();
        await customStatement('DELETE FROM records');
        await customStatement('DELETE FROM audit');
        await customStatement(
          'UPDATE revision SET value=value+1 WHERE singleton=1',
        );
        return load();
      });

  Future<List<Map<String, Object?>>> history() async => [
    for (final row in await customSelect(
      'SELECT revision,at,description FROM audit ORDER BY revision DESC LIMIT 50',
    ).get())
      row.data,
  ];
}
