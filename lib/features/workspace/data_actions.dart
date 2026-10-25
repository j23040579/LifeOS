part of 'workspace_shell.dart';

extension _DataActions on _WorkspaceShellState {
  Future<void> _import() async {
    final selection = await entryForm(context, 'Import local data', [
      const EntryField(
        'type',
        'File format',
        value: 'hevy',
        choices: {
          'hevy': 'Hevy CSV',
          'nutrition': 'MyFitnessPal TXT',
          'calendar': 'iCalendar ICS (explicit occurrences)',
          'expense': 'Mapped transaction CSV',
          'note': 'Source TXT / Markdown',
          'document': 'PDF / EPUB text extraction',
          'backup': 'LifeOS JSON backup',
        },
      ),
    ], confirm: 'Choose file');
    if (selection == null) return;
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Local text data',
          extensions: ['csv', 'txt', 'md', 'json', 'pdf', 'epub', 'ics'],
        ),
      ],
    );
    if (file == null) return;
    try {
      if (await file.length() > 5 * 1024 * 1024)
        throw const FormatException('Choose a text file smaller than 5 MB.');
      final document = selection['type'] == 'document'
          ? await DocumentImporter().extract(
              file.name,
              await file.readAsBytes(),
            )
          : null;
      final text = document == null ? await file.readAsString() : '';
      if (selection['type'] == 'backup') {
        if (await confirm(
          'Replace the local workspace?',
          'Restore ${file.name}? Existing local records will be replaced. Export a backup first. The change can be undone locally.',
        ))
          await store.restore(text);
        return;
      }
      if (selection['type'] == 'note') {
        if (await confirm(
          'Keep this source locally?',
          '${file.name}\n\n${text.length > 1500 ? text.substring(0, 1500) : text}',
        ))
          await store.put({
            'id': store.id('note'),
            'kind': 'note',
            'title': file.name,
            'source': file.name,
            'reference': 'Imported local file',
            'body': text,
            'reviewDate': clock.day(clock.now()),
          }, 'Import source note');
        return;
      }
      final importer = Importer(clock);
      final preview =
          document ??
          switch (selection['type']) {
            'hevy' => importer.hevy(text),
            'calendar' => importCalendar(text, clock),
            'nutrition' => importer.nutrition(text),
            _ => importer.transactions(text),
          };
      if (store
          .of('batch')
          .any((batch) => batch['checksum'] == preview.checksum)) {
        message(
          'This exact file was already imported. Undo or remove its batch before reprocessing with different settings.',
        );
        return;
      }
      final additions = preview.records
          .where((r) => !store.snapshot.records.containsKey(r['id']))
          .toList();
      final existing = preview.records
          .where((r) => store.snapshot.records.containsKey(r['id']))
          .toList();
      String canonical(Map<String, dynamic> r) =>
          jsonEncode({...r}..remove('batch'));
      final conflicts = existing
          .where(
            (r) => canonical(r) != canonical(store.snapshot.records[r['id']]!),
          )
          .toList();
      if (!await confirm(
        'Review import before saving',
        '${file.name}\n${preview.source}\nDates interpreted in ${clock.name}; confirm this matches the export.\n${additions.length} new rows\n${existing.length - conflicts.length} duplicates skipped\n${conflicts.length} changed existing rows (will be skipped)\n${preview.diagnostics.length} rejected rows\n\n${preview.diagnostics.take(10).join('\n')}\n\nPreview: ${preview.records.take(3).map((r) => '${r['title']} · ${r['date'] ?? r['exercise'] ?? ''}').join('\n')}\n\nOnly the valid new rows will be imported. No file is uploaded.',
      ))
        return;
      if (additions.isEmpty) {
        message('No new rows to import. Existing records were preserved.');
        return;
      }
      await store.change('Import ${preview.source}', (records) {
        for (final record in additions) {
          records[record['id']] = record;
        }
        final id = 'batch-${preview.checksum}';
        records[id] = {
          'id': id,
          'kind': 'batch',
          'source': preview.source,
          'checksum': preview.checksum,
          'filename': file.name,
          'sourceTimezone': clock.name,
          'rejectedRows': preview.diagnostics.length,
          'rows': additions.length,
          'at': DateTime.now().toUtc().toIso8601String(),
        };
      });
      message(
        'Saved ${additions.length} new rows. Duplicate/changed existing rows were preserved.',
      );
    } catch (e) {
      message('Import not saved: $e');
    }
  }

  Future<void> _settings() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _localCommand,
                  child: const Text('Tell LifeOS what changed'),
                ),
                Text(
                  'Your workspace',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Local SQLite storage · ${clock.name}\nNo accounts or external integrations connected. Local data is not app-encrypted; protect your device and exported files.',
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _preferences();
                  },
                  child: const Text('Timezone & weekly budget'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkspaceShell(
                          demoMode: true,
                          themeMode: widget.themeMode,
                          onThemeChanged: widget.onThemeChanged,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open separate demo workspace'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _import();
                  },
                  child: const Text('Import a local file'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _export();
                  },
                  child: const Text('Export backup'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    store.undo();
                  },
                  child: const Text('Undo last saved change'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _history();
                  },
                  child: const Text('Change history'),
                ),
                const Text(
                  'Google Calendar/Tasks, Readwise, Hevy API, Wallet API, ReciMe, and Health Connect are not connected. Use local records and supported imports; no sync is implied.',
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _exportCalendar();
                  },
                  child: const Text('Export LifeOS calendar (ICS)'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (await confirm(
                      'Delete all local records?',
                      'Export a backup first. This clears the workspace and its current records. Audit history remains for undo in this version.',
                    ))
                      await store.change(
                        'Clear local records',
                        (records) => records.clear(),
                      );
                  },
                  child: const Text('Clear workspace records'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (await confirm(
                      'Erase local data and history?',
                      'This permanently clears records and audit history in this workspace. It cannot be undone. Your exported files are not deleted. Saved AI access is managed separately with Disconnect & forget token in Coach.',
                    ))
                      await store.erase();
                  },
                  child: const Text('Erase records and history'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _preferences() async {
    final settings = store.snapshot.records['settings'];
    final fields = await entryForm(
      context,
      'Local preferences',
      [
        EntryField(
          'zone',
          'IANA timezone',
          value: settings?['zone'] ?? 'Asia/Kuala_Lumpur',
        ),
        EntryField(
          'budget',
          'Weekly budget (RM)',
          value: ((settings?['weeklyMinor'] as int? ?? 0) / 100)
              .toStringAsFixed(2),
        ),
      ],
      validate: (v) {
        try {
          ZoneClock(v['zone']!);
          if (moneyMinor(v['budget']!) < 0) return 'Budget cannot be negative.';
        } catch (e) {
          return 'Use a valid IANA timezone and a non-negative amount.';
        }
        return null;
      },
    );
    if (fields != null)
      await store.put({
        ...?store.snapshot.records['settings'],
        'id': 'settings',
        'kind': 'settings',
        'zone': fields['zone'],
        'weeklyMinor': moneyMinor(fields['budget']!),
      }, 'Change local preferences');
  }

  Future<void> _export() async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'lifeos-backup.json',
      );
      if (location == null) return;
      final file = XFile.fromData(
        utf8.encode(store.export()),
        mimeType: 'application/json',
        name: 'lifeos-backup.json',
      );
      await file.saveTo(location.path);
      message('Local backup exported. It contains your private records.');
    } catch (e) {
      message('Export unavailable: $e');
    }
  }

  Future<void> _exportCalendar() async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'lifeos-calendar.ics',
      );
      if (location == null) return;
      await XFile.fromData(
        utf8.encode(exportCalendar(store.of('block'))),
        mimeType: 'text/calendar',
        name: 'lifeos-calendar.ics',
      ).saveTo(location.path);
      message(
        'Exported LifeOS-owned blocks. Imported calendar events were excluded.',
      );
    } catch (_) {
      message('Calendar export unavailable. Your records were preserved.');
    }
  }

  Future<void> _history() async {
    final history = await store.database.history();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local change history'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Text(
              history.isEmpty
                  ? 'No changes yet.'
                  : history
                        .map(
                          (r) =>
                              '${r['revision']} · ${r['at']}\n${r['description']}',
                        )
                        .join('\n\n'),
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
  }
}
