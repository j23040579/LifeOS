part of 'workspace_shell.dart';

extension _HomeActions on _WorkspaceShellState {
  DayEvidence _evidence() => dayEvidence(
    store.tasks,
    store.blocks,
    store.snapshot.records.values.toList(),
    clock,
    clock.now(),
  );
  Widget _homeOverview() {
    final evidence = _evidence();
    final todoIds = evidence.todoIds.toSet();
    final leaves = resolveHierarchy(store.tasks).leaves;
    final remaining =
        leaves
            .where(
              (t) =>
                  t.state == TaskState.pending || t.state == TaskState.active,
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final stale =
        _dayAssessment != null &&
        (_assessmentRevision != store.snapshot.revision ||
            clock.day(clock.local(_dayAssessment!.at)) != evidence.day ||
            clock.now().difference(_dayAssessment!.at).inMinutes >= 15);
    return HomeOverview(
      day: evidence.day,
      asOf: clock.stamp(
        (stale
                ? DayAssessment.local(evidence)
                : _dayAssessment ?? DayAssessment.local(evidence))
            .at,
      ),
      assessment: stale
          ? DayAssessment.local(evidence)
          : _dayAssessment ?? DayAssessment.local(evidence),
      todos: [
        for (final id in evidence.todoIds) leaves.firstWhere((t) => t.id == id),
      ],
      upcoming: remaining.where((t) => !todoIds.contains(t.id)).toList(),
      busy: store.busy,
      refreshing: _checkInBusy,
      stale: stale,
      notice: _assessmentNotice,
      onCreate: () => _task(),
      onPlan: () => refresh(() => page = 1),
      onTask: (task) => _task(task),
      onComplete: (task) async {
        if (!await store.complete(task))
          message(store.error ?? 'Task completion was not saved.');
      },
      onRefresh: _refreshCheckIn,
      onEvidence: _explainCheckIn,
      onDemo: _openDemo,
    );
  }

  Future<void> _explainCheckIn() async {
    final evidence = _evidence();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A snapshot of your current pace'),
        content: SingleChildScrollView(
          child: Text(
            'Local score = recorded completed estimated effort ÷ eligible estimated effort × 100. '
            'Eligible work is due by now, linked to a work block ending today by now, or recorded complete today. '
            'Parent containers are excluded to avoid counting their subtasks twice. Paused tasks and future work are excluded. '
            'No evidence means no score, not zero. Reduced remaining effort contributes partial credit. Completion reflects your records, not independently verified work. '
            'Gemini may interpret the same aggregate evidence differently and is labelled separately. No comparisons with other people are made.\n\n'
            '${const JsonEncoder.withIndent('  ').convert(evidence.sharedSummary)}',
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

  Future<void> _refreshCheckIn() async {
    if (_checkInBusy) return;
    final evidence = _evidence(), revision = store.snapshot.revision;
    if (_gateway == null || evidence.localScore == null) {
      refresh(() {
        _dayAssessment = DayAssessment.local(evidence);
        _assessmentRevision = revision;
        _assessmentNotice = _gateway == null
            ? 'Local fallback · no gateway connected. Configure Gemini in Coach for an online assessment.'
            : 'No score yet · insufficient recorded work due by now.';
      });
      return;
    }
    if (!await confirm(
      'Share this summary with Gemini?',
      'Only these aggregate planning counts and effort totals will be sent. No task titles, documents, finance or health records. Your configured provider may process this data under its terms.\n\n${const JsonEncoder.withIndent('  ').convert(evidence.sharedSummary)}',
    ))
      return;
    if (!mounted) return;
    refresh(() => _checkInBusy = true);
    try {
      final assessment = await _gateway!.assessDay(evidence);
      if (!mounted) return;
      if (revision != store.snapshot.revision ||
          clock.day(clock.now()) != evidence.day) {
        refresh(
          () => _assessmentNotice = 'Records changed while Gemini was reviewing. The local snapshot is shown; refresh again.',
        );
        return;
      }
      refresh(() {
        _dayAssessment = assessment;
        _assessmentRevision = revision;
        _assessmentNotice = null;
      });
    } catch (error) {
      if (mounted)
        refresh(() {
          _dayAssessment = DayAssessment.local(_evidence());
          _assessmentRevision = store.snapshot.revision;
          _assessmentNotice = error is AiFailure ? 'Local fallback · $error' : 'Local fallback · Gemini is offline, unavailable, rate-limited, or returned an invalid assessment. No paid fallback was used.';
        });
    } finally {
      if (mounted) refresh(() => _checkInBusy = false);
    }
  }
}
