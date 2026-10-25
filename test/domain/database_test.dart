import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/workspace_database.dart';

void main() {
  late WorkspaceDatabase db;
  setUp(() => db = WorkspaceDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());
  test(
    'transactional save, load, undo and audit survive repository reload',
    () async {
      final empty = await db.load();
      final saved = await db.save(empty, {
        'task': {'id': 'task', 'kind': 'task', 'title': 'Private task'},
      }, 'Add task');
      expect(saved.revision, 1);
      expect((await db.load()).records['task']!['title'], 'Private task');
      final undone = await db.undo(saved);
      expect(undone.records, isEmpty);
      expect(undone.revision, 2);
      expect(await db.history(), hasLength(2));
    },
  );
  test(
    'stale revision rejects a save rather than overwriting newer work',
    () async {
      final stale = await db.load();
      await db.save(stale, {
        'a': {'id': 'a', 'kind': 'note'},
      }, 'First edit');
      await expectLater(
        db.save(stale, {}, 'Stale edit'),
        throwsA(isA<RevisionConflict>()),
      );
      expect((await db.load()).records, contains('a'));
    },
  );
  test('failed validation leaves data and revision unchanged', () async {
    final empty = await db.load();
    await expectLater(
      db.save(empty, {
        'a': {'id': 'wrong', 'kind': 'note'},
      }, 'Bad edit'),
      throwsFormatException,
    );
    expect((await db.load()).revision, 0);
    expect((await db.history()), isEmpty);
  });
  test(
    'successive undo steps back through distinct edits; erase removes audit',
    () async {
      var state = await db.load();
      state = await db.save(state, {
        'a': {'id': 'a', 'kind': 'note'},
      }, 'Add A');
      state = await db.save(state, {
        'a': {'id': 'a', 'kind': 'note'},
        'b': {'id': 'b', 'kind': 'note'},
      }, 'Add B');
      state = await db.undo(state);
      expect(state.records.keys, ['a']);
      state = await db.undo(state);
      expect(state.records, isEmpty);
      state = await db.erase(state);
      expect(state.records, isEmpty);
      expect(await db.history(), isEmpty);
    },
  );
  test(
    'version one audit schema migrates without discarding records',
    () async {
      await db.close();
      db = WorkspaceDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE revision (singleton INTEGER PRIMARY KEY, value INTEGER NOT NULL)',
            );
            raw.execute('INSERT INTO revision VALUES (1,1)');
            raw.execute(
              'CREATE TABLE records (id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL)',
            );
            raw.execute('INSERT INTO records VALUES (?,?,?)', [
              'a',
              'note',
              '{"id":"a","kind":"note"}',
            ]);
            raw.execute(
              'CREATE TABLE audit (revision INTEGER PRIMARY KEY, at TEXT NOT NULL, description TEXT NOT NULL, before_state TEXT NOT NULL)',
            );
            raw.execute('PRAGMA user_version=1');
          },
        ),
      );
      expect((await db.load()).records, contains('a'));
    },
  );
}
