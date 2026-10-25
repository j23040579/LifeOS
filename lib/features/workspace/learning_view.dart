part of 'workspace_shell.dart';

extension _LearningView on _WorkspaceShellState {
  Widget _learn() {
    final course = store.of('course').any((r) => r['id'] == _sourceCourse)
        ? _sourceCourse
        : '';
    final notes = store
        .of('note')
        .where((r) => course.isEmpty || r['courseId'] == course)
        .toList();
    final maxPage = notes.isEmpty ? 0 : (notes.length - 1) ~/ 10;
    final currentPage = _notePage.clamp(0, maxPage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Learn it.\nMake it yours.',
          'Local notes, retrieval practice, focus sessions, and sources you can inspect. No generated claims.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: _note,
              child: const Text('Add a source note'),
            ),
            OutlinedButton(
              onPressed: _course,
              child: const Text('Add a course'),
            ),
            OutlinedButton(
              onPressed: _import,
              child: const Text('Import a text file'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _focusCard(),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey(course),
          initialValue: course,
          decoration: const InputDecoration(labelText: 'Browse source notes'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All sources')),
            for (final item in store.of('course'))
              DropdownMenuItem(
                value: item['id'] as String,
                child: Text(item['title']),
              ),
          ],
          onChanged: (value) => refresh(() {
            _sourceCourse = value ?? '';
            _notePage = 0;
          }),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: currentPage > 0
                  ? () => refresh(() => _notePage = currentPage - 1)
                  : null,
              child: const Text('Previous sources'),
            ),
            TextButton(
              onPressed: (currentPage + 1) * 10 < notes.length
                  ? () => refresh(() => _notePage = currentPage + 1)
                  : null,
              child: const Text('Next sources'),
            ),
          ],
        ),
        panel(
          line(
            'Your learning evidence',
            '${store.of('recall').length} self-assessed retrieval attempts · ${notes.where((n) => (n['reviewDate'] as String? ?? '').compareTo(clock.day(clock.now())) <= 0).length} source notes due for review\n'
                '${store.of('focus').fold<num>(0, (sum, r) => sum + (r['minutes'] as num)).toStringAsFixed(0)} recorded focus minutes. Self-ratings are not verified correctness or mastery.',
          ),
        ),
        for (final attempt in store.of('recall').reversed.take(5))
          panel(
            line(
              'Recall · ${attempt['title']}',
              '${attempt['selfRating'] == 1 ? 'Self-rated confident' : 'Needs another review'} · ${attempt['at']}\n${attempt['mistake'] ?? ''}',
            ),
          ),
        for (final course in store.of('course'))
          panel(
            line(
              course['title'].toString(),
              course['body']?.toString() ?? '',
              action: TextButton(
                onPressed: () => _note(courseId: course['id']),
                child: const Text('Add a course concept'),
              ),
            ),
          ),
        for (final note in notes.skip(currentPage * 10).take(10))
          panel(
            line(
              note['title'].toString(),
              '${note['source']} · ${note['reference'] ?? 'User-provided note'}\n${_sourcePreview(note['body'].toString())}\nNext review: ${note['reviewDate'] ?? 'Not reviewed'}\nPrerequisites: ${(note['prerequisites'] as List? ?? []).map((id) => store.snapshot.records[id]?['title'] ?? 'Missing source').join(', ')}',
              action: Wrap(
                children: [
                  TextButton(
                    onPressed: () => _recall(note),
                    child: const Text('Practise recall'),
                  ),
                  if (_gateway != null)
                    TextButton(
                      onPressed: () => _askAi(selectedNote: note),
                      child: const Text('Tutor with this source'),
                    ),
                  TextButton(
                    onPressed: () => _readSource(note),
                    child: const Text('Read source'),
                  ),
                  TextButton(
                    onPressed: () => _note(note: note),
                    child: const Text('Edit source'),
                  ),
                  TextButton(
                    onPressed: () => _actionFromNote(note),
                    child: const Text('Turn into an action'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (await confirm(
                        'Delete source note?',
                        'This removes only the local note. Referencing records remain in your audit history.',
                      ))
                        await store.remove(note['id']);
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ),
        if (notes.isEmpty)
          panel(
            const Text(
              'Add notes in your own words, permitted highlights, or course material. Quotes and recommendations need an explicit source.',
            ),
          ),
      ],
    );
  }

  String _sourcePreview(String text) =>
      text.length > 320 ? '${text.substring(0, 320)}…' : text;
  Future<void> _readSource(Map<String, dynamic> note) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(note['title']),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: SelectableText(
            '${note['source']} · ${note['reference']}\n\n${note['body']}',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Future<void> _course() async {
    final fields = await entryForm(context, 'A course', [
      const EntryField('title', 'Course name'),
      const EntryField(
        'body',
        'Syllabus / objectives',
        lines: 4,
        optional: true,
      ),
    ]);
    if (fields != null)
      await store.put({
        'id': store.id('course'),
        'kind': 'course',
        ...fields,
      }, 'Create course');
  }

  Future<void> _note({Map<String, dynamic>? note, String? courseId}) async {
    final fields = await entryForm(context, 'A source worth keeping', [
      EntryField('title', 'Concept / note title', value: note?['title'] ?? ''),
      EntryField(
        'body',
        'Source text or your notes',
        value: note?['body'] ?? '',
        lines: 5,
      ),
      EntryField(
        'source',
        'Source title / author',
        value: note?['source'] ?? 'My own notes',
      ),
      EntryField(
        'reference',
        'Page, chapter, section, timestamp, or link',
        value: note?['reference'] ?? '',
        optional: true,
      ),
      EntryField(
        'prerequisites',
        'Prerequisite concepts',
        value: jsonEncode(note?['prerequisites'] ?? []),
        optional: true,
        multiple: true,
        choices: {
          for (final n in store.of('note').where((n) => n['id'] != note?['id']))
            n['id']: n['title'],
        },
      ),
      EntryField(
        'permission',
        'Source rights / permission',
        value: note?['permission'] ?? 'user-provided',
        choices: {
          'user-provided': 'User-provided; retain privately',
          'own': 'My own writing',
          'permitted': 'Permission / licence confirmed',
        },
      ),
      EntryField(
        'courseId',
        'Course',
        value: courseId ?? note?['courseId'] ?? '',
        optional: true,
        choices: {
          '': 'Personal library',
          for (final c in store.of('course')) c['id']: c['title'],
        },
      ),
    ]);
    if (fields != null)
      await store.put({
        ...?note,
        ...fields,
        'prerequisites': jsonDecode(fields['prerequisites']!),
        'updatedAt': clock.now().toUtc().toIso8601String(),
        'id': note?['id'] ?? store.id('note'),
        'kind': 'note',
        'reviewDate': clock.day(clock.now()),
      }, 'Save source note');
  }

  Future<void> _actionFromNote(Map<String, dynamic> note) async {
    final fields = await entryForm(
      context,
      'Put this idea into practice',
      [
        EntryField('title', 'Action in your own words', value: note['title']),
        const EntryField('minutes', 'Estimated minutes', value: '30'),
        EntryField(
          'deadline',
          'Deadline (${clock.name})',
          value: clock.stamp(clock.now().add(const Duration(days: 7))),
        ),
      ],
      validate: (v) {
        try {
          clock.parse(v['deadline']!);
        } catch (e) {
          return e.toString();
        }
        final minutes = int.tryParse(v['minutes']!);
        return minutes == null || minutes < 1
            ? 'Enter positive minutes.'
            : null;
      },
      confirm: 'Preview action',
    );
    if (fields == null) return;
    if (!await confirm(
      'Create this source-linked action?',
      '${fields['title']}\n${fields['minutes']} minutes · Due ${fields['deadline']}\n\nSource: ${note['source']} · ${note['reference']}\n\nThis is your interpretation, not an invented quotation or AI claim.',
    ))
      return;
    final id = store.id('task');
    await store.put({
      ...PlanTask(
        id: id,
        title: fields['title']!,
        minutes: int.parse(fields['minutes']!),
        deadline: clock.parse(fields['deadline']!),
      ).toJson(),
      'kind': 'task',
      'sourceNoteId': note['id'],
      'sourceHash': fingerprint(note['body']),
      'sourceTitle': note['source'],
      'sourceReference': note['reference'],
    }, 'Approve source-linked action');
  }

  Future<void> _recall(Map<String, dynamic> note) async {
    final fields = await entryForm(context, 'Recall: ${note['title']}', [
      const EntryField('answer', 'Explain the idea from memory', lines: 5),
      const EntryField(
        'mistake',
        'Mistake or uncertainty to revisit',
        optional: true,
        lines: 2,
      ),
    ], confirm: 'Compare with source');
    if (fields == null || !mounted) return;
    final rating = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compare, then self-assess'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(
              'YOUR ANSWER\n${fields['answer']}\n\nSOURCE\n${note['body']}\n\n${note['source']} · ${note['reference'] ?? ''}\n\nThis is self-assessment, not AI grading.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Again tomorrow'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 1),
            child: const Text('Recalled confidently'),
          ),
        ],
      ),
    );
    if (rating == null) return;
    final stage = rating == 0
        ? 0
        : ((note['stage'] as int? ?? 0) + 1).clamp(0, 4);
    final interval = [1, 3, 7, 14, 30][stage];
    await store.change('Record retrieval practice', (records) {
      records[note['id']] = {
        ...note,
        'stage': stage,
        'reviewDate': clock.day(clock.now().add(Duration(days: interval))),
      };
      final id = store.id('recall');
      records[id] = {
        'id': id,
        'kind': 'recall',
        'title': note['title'],
        'noteId': note['id'],
        'answer': fields['answer'],
        'selfRating': rating,
        'mistake': fields['mistake'],
        'at': clock.now().toUtc().toIso8601String(),
      };
    });
  }

  Widget _focusCard() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A little undivided attention',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(
          valueListenable: _focusSeconds,
          builder: (context, seconds, _) => Text(
            '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const Text(
          'Save before closing the app. Time alone does not mark a task complete.',
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: () => refresh(() {
                if (_focusWatch.isRunning) {
                  _focusWatch.stop();
                } else {
                  _focusId ??= store.id('focus');
                  _focusWatch.start();
                }
              }),
              child: Text(
                _focusWatch.isRunning ? 'Pause timer' : 'Start focus',
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                _focusWatch.stop();
                final seconds = _focusWatch.elapsed.inSeconds;
                if (seconds == 0) {
                  message('Start a focus session first.');
                  return;
                }
                final saved = await store.put({
                  'id': _focusId ?? store.id('focus'),
                  'kind': 'focus',
                  'title': 'Focus session',
                  'seconds': seconds,
                  'minutes': seconds / 60,
                  'at': clock.now().toUtc().toIso8601String(),
                  'source': 'Local timer',
                }, 'Save focus session');
                if (saved && mounted)
                  refresh(() {
                    _focusWatch.reset();
                    _focusSeconds.value = 0;
                    _focusId = null;
                  });
              },
              child: const Text('Save session'),
            ),
            TextButton(
              onPressed: _recordFocus,
              child: const Text('Record manually'),
            ),
          ],
        ),
      ],
    ),
  );
  Future<void> _recordFocus() async {
    final fields = await entryForm(
      context,
      'Record actual focus',
      [
        const EntryField('title', 'What did you work on?'),
        const EntryField('minutes', 'Actual focused minutes'),
        const EntryField(
          'reflection',
          'What helped or got in the way?',
          optional: true,
          lines: 3,
        ),
      ],
      validate: (v) {
        final value = int.tryParse(v['minutes']!);
        return value == null || value <= 0 || value > 1440
            ? 'Enter 1–1440 actual minutes.'
            : null;
      },
    );
    if (fields != null)
      await store.put({
        'id': store.id('focus'),
        'kind': 'focus',
        ...fields,
        'minutes': int.parse(fields['minutes']!),
        'at': clock.now().toUtc().toIso8601String(),
      }, 'Record actual focus');
  }
}
