part of 'workspace_shell.dart';

extension _CoachView on _WorkspaceShellState {
  Widget _coach() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Think it through.\nThen choose.',
        'Local planning tools, with optional live AI through your own gateway.',
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _gateway == null
                  ? 'No AI provider connected. Offline tools remain available.'
                  : 'Gateway configured: $_gatewayLabel. Provider answers are generated only when you send a question.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _connectAi,
                  child: const Text('Configure AI gateway'),
                ),
                TextButton(
                  onPressed: _aiBusy
                      ? null
                      : () {
                          _gateway?.close();
                          refresh(() {
                            _gateway = AiGateway.demo();
                            _gatewayLabel = 'Offline demo — not live AI';
                          });
                        },
                  child: const Text('Try chat demo (offline)'),
                ),
                if (_answers.isNotEmpty)
                  TextButton(
                    onPressed: _aiBusy
                        ? null
                        : () => refresh(() {
                            _answers.clear();
                            _acceptedAiActions.clear();
                          }),
                    child: const Text('Clear this conversation'),
                  ),
                if (_gateway != null)
                  TextButton(
                    onPressed: _aiBusy ? null : _disconnectAi,
                    child: const Text('Disconnect & forget token'),
                  ),
                FilledButton(
                  onPressed: _gateway == null || _aiBusy ? null : _askAi,
                  child: const Text('Ask AI'),
                ),
              ],
            ),
            if (_aiBusy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Waiting for your selected AI provider… No local records are being changed.',
                ),
              ),
          ],
        ),
      ),
      for (final turn in _answers)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                turn.answer.live
                    ? 'MODEL RESPONSE · ${turn.answer.provider} · ${turn.answer.model}'
                    : 'DEMO RESPONSE — NOT LIVE AI',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Text(
                turn.question,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SelectableText(turn.answer.text),
              const SizedBox(height: 12),
              if (turn.answer.warning != null) Text(turn.answer.warning!),
              if (turn.answer.suggestion != null)
                FilledButton(
                  onPressed:
                      store.busy || _acceptedAiActions.contains(turn.answer)
                      ? null
                      : () => _reviewAiSuggestion(turn.answer, turn.revision),
                  child: Text(
                    _acceptedAiActions.contains(turn.answer)
                        ? 'Proposal applied'
                        : 'Review proposed task change',
                  ),
                ),
              const Text(
                'Suggestions only. Verify sources; use reviewed local tools to apply changes.',
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: _propose,
            child: const Text('Rebuild my schedule'),
          ),
          OutlinedButton(
            onPressed: _localCommand,
            child: const Text('Tell LifeOS what changed'),
          ),
          OutlinedButton(
            onPressed: () => refresh(() => page = 3),
            child: const Text('Review budget & progress'),
          ),
          OutlinedButton(
            onPressed: _searchSources,
            child: const Text('Search my sources'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      panel(
        line(
          'A change starts with a proposal',
          'LifeOS-owned flexible blocks can be proposed for rescheduling. Fixed commitments, deadlines, and external records are never silently rewritten.',
        ),
      ),
      panel(
        line(
          'Future live AI',
          'Gemini online is the selected live provider. Configure your own eligible free/no-billing project and secure gateway. No paid fallback or phone model installation is required.',
        ),
      ),
    ],
  );
  Future<void> _connectAi() async {
    final fields = await entryForm(
      context,
      'Connect your personal AI gateway',
      [
        EntryField(
          'url',
          'Gateway base URL (HTTPS, or local development)',
          value: _gateway?.endpoint.toString() ?? 'http://127.0.0.1:8787',
        ),
        const EntryField('token', 'Gateway access token', obscure: true),
        if (_credentials.supported)
          EntryField(
            'remember',
            'Remember token securely on this device',
            value: _rememberGateway ? 'yes' : 'no',
            choices: const {
              'no': 'This session only',
              'yes': 'Remember on this device',
            },
          ),
      ],
      notice: 'Only the gateway access token belongs here. Keep the Gemini API key on the server. Browser connections are session-only.',
      confirm: 'Check gateway',
    );
    if (fields == null) return;
    AiGateway? candidate;
    try {
      candidate = AiGateway(Uri.parse(fields['url']!), fields['token']!);
      final label = await candidate.check();
      if (!mounted) {
        candidate.close();
        return;
      }
      final remember = fields['remember'] == 'yes';
      try {
        if (remember) {
          await _credentials.write(
            GatewayCredentials(fields['url']!, fields['token']!),
          );
        } else {
          await _credentials.clear();
        }
      } catch (_) {
        candidate.close();
        message(
          'Gateway checked, but token storage failed. Your existing connection was preserved. Select session-only or retry secure storage.',
        );
        return;
      }
      if (!mounted) {
        candidate.close();
        return;
      }
      _gateway?.close();
      refresh(() {
        _rememberGateway = remember;
        _gateway = candidate;
        _gatewayLabel = label;
      });
      message('Gateway ready. This check did not generate a model response.');
    } catch (e) {
      candidate?.close();
      message('Gateway not connected: $e');
    }
  }

  Future<void> _disconnectAi() async {
    try {
      await _credentials.clear();
    } catch (_) {
      message(
        'Could not remove the saved token. Retry before closing the app.',
      );
      return;
    }
    if (!mounted) return;
    _gateway?.close();
    refresh(() {
      _gateway = null;
      _gatewayLabel = null;
      _rememberGateway = false;
    });
    message('Gateway disconnected and saved token removed.');
  }

  Future<void> _askAi({Map<String, dynamic>? selectedNote}) async {
    final fields = await entryForm(
      context,
      'Ask your selected AI provider',
      [
        EntryField(
          'question',
          'Question (sent to your gateway)',
          lines: 4,
          value: selectedNote == null
              ? ''
              : 'Help me understand ${selectedNote['title']}. Cite only the selected source and say when the evidence is insufficient.',
        ),
        const EntryField(
          'mode',
          'Assistance mode',
          value: 'general',
          choices: {
            'general': 'General coaching',
            'explain': 'Learn / explain',
            'worked': 'Worked example',
            'practice': 'Practice from memory',
            'hints': 'Hints only',
            'quiz': 'Quiz',
            'debug': 'Debugging',
            'review': 'Code review',
            'flashcards': 'Flashcards',
            'exam': 'Mock test',
          },
        ),
        const EntryField(
          'difficulty',
          'Difficulty',
          value: 'adaptive',
          choices: {
            'adaptive': 'Ask / adapt to my response',
            'introductory': 'Introductory',
            'intermediate': 'Intermediate',
            'advanced': 'Advanced',
          },
        ),
        EntryField(
          'source',
          'Optional source excerpt to send (up to 6,000 characters)',
          value: selectedNote?['id'] ?? '',
          optional: true,
          choices: {
            '': 'No source excerpt',
            for (final note in store.of('note')) note['id']: note['title'],
          },
        ),
        EntryField(
          'task',
          'Optional task to send to the provider',
          value: '',
          optional: true,
          choices: {
            '': 'No task context',
            for (final task in store.tasks) task.id: task.title,
          },
        ),
        const EntryField(
          'context',
          'Optional record summary to send',
          value: 'none',
          choices: {
            'none': 'No record summary',
            'training': 'Last 28 days of training (summary)',
            'budget': 'Current week budget totals',
          },
        ),
      ],
      notice: 'Only your question and explicitly selected source/task/summary leave the device. Review the provider’s data-use terms before sending sensitive information. Source context is limited to 6,000 characters.',
      confirm: 'Send question',
    );
    if (fields == null || _gateway == null) return;
    final note = store.snapshot.records[fields['source']];
    final selectedTask = store.snapshot.records[fields['task']];
    final summary = aiContext(
      store.snapshot.records.values.toList(),
      fields['context']!,
      clock,
    );
    final sourceText = [
      if (summary.isNotEmpty) summary,
      if (note != null)
        '${note['title']} · ${note['source']} · ${note['reference']}\n${note['body']}',
    ].join('\n\n');
    final revision = store.snapshot.revision;
    refresh(() => _aiBusy = true);
    try {
      final answer = await _gateway!.ask(
        'Mode: ${fields['mode']}; difficulty: ${fields['difficulty']}. Only provide hints when hints-only is selected. Do not claim code was compiled or tested. Separate source evidence from interpretation.\n\n${fields['question']!}',
        task: selectedTask,
        source: sourceText.isEmpty ? null : sourceText,
      );
      if (mounted)
        refresh(
          () => _answers.add((
            question: fields['question']!,
            answer: answer,
            revision: revision,
          )),
        );
    } catch (e) {
      message('AI unavailable: $e');
    } finally {
      if (mounted) refresh(() => _aiBusy = false);
    }
  }

  Future<void> _reviewAiSuggestion(AiAnswer answer, int revision) async {
    if (revision != store.snapshot.revision) {
      message('Your local data changed. Ask again or edit the task manually.');
      return;
    }
    final suggestion = answer.suggestion!;
    final current = suggestion.type == 'update_task'
        ? store.tasks.where((task) => task.id == suggestion.taskId).firstOrNull
        : null;
    if (suggestion.type == 'update_task' && current == null) {
      message('The selected task is no longer available.');
      return;
    }
    final next = PlanTask(
      id: current?.id ?? store.id('task'),
      title: suggestion.title ?? current!.title,
      minutes: suggestion.minutes ?? current!.minutes,
      deadline: suggestion.deadline ?? current!.deadline,
      priority: current?.priority ?? 2,
      dependencies: current?.dependencies ?? [],
      parentId: current?.parentId,
      state: current?.state ?? TaskState.pending,
      actualMinutes: current?.actualMinutes ?? 0,
      estimatedMinutes: current?.effortWeight,
      minimumBlock: current?.minimumBlock ?? 25,
      splittable: current?.splittable ?? true,
    );
    var reason = 'User-approved new task';
    if (current != null && !next.deadline.isAtSameMomentAs(current.deadline)) {
      final response = await entryForm(
        context,
        'Confirm a true deadline change',
        [
          const EntryField(
            'reason',
            'Source/reason for extension or correction',
          ),
        ],
        confirm: 'Continue review',
      );
      if (response == null) return;
      reason = response['reason']!;
    }
    if (!await confirm(
      'Approve this local task proposal?',
      'BEFORE\n${current == null ? 'New task' : '${current.title} · ${current.minutes} min · ${clock.stamp(current.deadline)}'}\n\nAFTER\n${next.title} · ${next.minutes} min · Due ${clock.stamp(next.deadline)}\n\nReason: $reason\n\nNo calendar block or outside account will be changed.',
    ))
      return;
    if (revision != store.snapshot.revision) {
      message('Data changed during review; no action was applied.');
      return;
    }
    final saved = await store.put({
      ...?store.snapshot.records[next.id],
      ...next.toJson(),
      'kind': 'task',
      'aiProvider': answer.provider,
      'aiModel': answer.model,
      'deadlineReason': reason,
    }, 'Approve AI task proposal');
    if (saved && mounted) refresh(() => _acceptedAiActions.add(answer));
  }

  Future<void> _localCommand() async {
    final fields = await entryForm(context, 'Offline planning assistant', [
      const EntryField(
        'text',
        'Command: Add:, Remaining:, or Deadline:',
        lines: 4,
      ),
    ], confirm: 'Preview proposal');
    if (fields == null) return;
    try {
      final revision = store.snapshot.revision;
      final proposal = const OfflineAssistant().propose(
        fields['text']!,
        store.tasks,
        clock,
        store.id('task'),
      );
      if (!await confirm(
        'Review local proposal',
        '${proposal.description}\n\nTask: ${proposal.task.title}\nRemaining: ${proposal.task.minutes} min\nDeadline: ${clock.stamp(proposal.task.deadline)}\n\nThis is deterministic parsing, not live AI. Nothing has been saved yet.',
      ))
        return;
      if (revision != store.snapshot.revision) {
        message('Data changed while reviewing. Preview the command again.');
        return;
      }
      await store.put({
        ...?store.snapshot.records[proposal.task.id],
        ...proposal.task.toJson(),
        'kind': 'task',
        'changeSource': fields['text'],
      }, 'Approve local assistant proposal');
    } catch (e) {
      message('No change applied: $e');
    }
  }

  Future<void> _searchSources() async {
    final fields = await entryForm(context, 'Find evidence', [
      const EntryField('query', 'Words to look for'),
    ], confirm: 'Search');
    if (fields == null || !mounted) return;
    final terms = fields['query']!.toLowerCase().split(RegExp(r'\s+'));
    final matches = store
        .of('note')
        .where(
          (r) => terms.every(
            (term) => '${r['title']} ${r['body']}'.toLowerCase().contains(term),
          ),
        )
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('From your local sources'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(
              matches.isEmpty
                  ? 'No matching evidence found.'
                  : matches
                        .map(
                          (r) =>
                              '${r['title']}\n${r['source']} · ${r['reference']}\n${r['body']}',
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
