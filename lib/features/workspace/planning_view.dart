part of 'workspace_shell.dart';

extension _PlanningView on _WorkspaceShellState {
  Future<void> _task([
    PlanTask? task,
    String? eventId,
    String? parentId,
  ]) async {
    final choices = {
      '': 'None',
      if (task?.parentId != null &&
          !store.snapshot.records.containsKey(task!.parentId))
        task.parentId!: 'Removed parent — review link',
      for (final id in task?.dependencies ?? <String>[])
        if (!store.snapshot.records.containsKey(id) || id == task?.id)
          id: 'Removed or invalid prerequisite — review link',
      for (final t in store.tasks.where((t) => t.id != task?.id)) t.id: t.title,
    };
    final fields = await entryForm(
      context,
      task == null ? 'A new priority' : 'Edit priority',
      [
        EntryField('title', 'What needs doing?', value: task?.title ?? ''),
        EntryField(
          'minutes',
          'Remaining effort (minutes)',
          value: '${task?.minutes ?? 60}',
        ),
        EntryField(
          'deadline',
          'True deadline (${clock.name})',
          value: _editableTime(
            task?.deadline ??
                store.blocks.where((b) => b.id == eventId).firstOrNull?.end ??
                clock.now().add(const Duration(days: 2)),
          ),
        ),
        EntryField(
          'priority',
          'Importance (1–5)',
          value: '${task?.priority ?? 3}',
        ),
        EntryField(
          'parent',
          'Parent task',
          value: task?.parentId ?? parentId ?? '',
          choices: choices,
          optional: true,
        ),
        EntryField(
          'state',
          'Work status',
          value: task?.state.name ?? 'pending',
          choices: const {
            'pending': 'Not started',
            'active': 'In progress',
            'paused': 'Paused',
            'completed': 'Completed',
          },
        ),
        EntryField(
          'split',
          'Split across sessions?',
          value: task?.splittable == false ? 'no' : 'yes',
          choices: const {'yes': 'Allowed', 'no': 'One continuous session'},
        ),
        EntryField(
          'minimum',
          'Smallest useful session (minutes)',
          value: '${task?.minimumBlock ?? 25}',
        ),
        EntryField(
          'projectId',
          'Project',
          value: store.snapshot.records[task?.id]?['projectId'] ?? '',
          optional: true,
          choices: {
            '': 'No project',
            for (final project in store.of('project'))
              project['id']: project['title'],
          },
        ),
        EntryField(
          'dependency',
          'Prerequisite',
          value: jsonEncode(task?.dependencies ?? <String>[]),
          multiple: true,
          choices: choices,
          optional: true,
        ),
        EntryField(
          'reason',
          'Reason/source for changed deadline',
          optional: true,
        ),
      ],
      validate: (v) {
        try {
          clock.parse(v['deadline']!);
        } catch (e) {
          return e.toString();
        }
        final minimum = int.tryParse(v['minimum']!);
        if (minimum == null || minimum < 1 || minimum > 1440)
          return 'Smallest useful session must be 1–1440 minutes.';
        final minutes = int.tryParse(v['minutes']!),
            priority = int.tryParse(v['priority']!);
        if (minutes == null || minutes <= 0 || minutes > 100000)
          return 'Enter a positive duration below 100,000 minutes.';
        if (priority == null || priority < 1 || priority > 5)
          return 'Importance must be 1–5.';
        if (task != null &&
            v['deadline'] != _editableTime(task.deadline) &&
            v['reason']!.isEmpty)
          return 'Give the reason/source for a true deadline change.';
        // Ancestor cycles would make weighted progress and hierarchy ambiguous.
        var parent = v['parent'];
        final seen = {task?.id};
        while (parent != null && parent.isNotEmpty) {
          if (!seen.add(parent)) return 'Parent tasks cannot form a cycle.';
          parent = store.snapshot.records[parent]?['parentId'];
        }
        return null;
      },
    );
    if (fields == null) return;
    final id = task?.id ?? store.id('task');
    final next = PlanTask(
      id: id,
      title: fields['title']!,
      minutes: int.parse(fields['minutes']!),
      deadline:
          task != null && fields['deadline'] == _editableTime(task.deadline)
          ? task.deadline
          : clock.parse(fields['deadline']!),
      priority: int.parse(fields['priority']!),
      parentId: fields['parent']!.isEmpty ? null : fields['parent'],
      dependencies: List<String>.from(jsonDecode(fields['dependency']!)),
      state: TaskState.values.byName(fields['state']!),
      actualMinutes: task?.actualMinutes ?? 0,
      estimatedMinutes: task?.effortWeight,
      minimumBlock: int.parse(fields['minimum']!),
      splittable: fields['split'] == 'yes',
    );
    final record = <String, dynamic>{
      ...?store.snapshot.records[id],
      ...next.toJson(),
      'kind': 'task',
      'deadlineReason': fields['reason'],
      'projectId': fields['projectId'],
    };
    if (eventId != null) {
      await store.saveEventTask(record, eventId);
    } else {
      await store.put(
        record,
        task == null ? 'Create task' : 'Edit task: ${fields['reason']}',
      );
    }
  }

  Future<void> _goal([Map<String, dynamic>? goal]) async {
    final fields = await entryForm(context, 'The longer view', [
      EntryField('title', 'Goal', value: goal?['title'] ?? ''),
      EntryField(
        'body',
        'Why it matters / evidence of progress',
        value: goal?['body'] ?? '',
        lines: 3,
      ),
      EntryField(
        'status',
        'Status',
        value: goal?['status'] ?? 'active',
        choices: const {
          'active': 'Active',
          'paused': 'Paused',
          'achieved': 'Achieved',
        },
      ),
    ]);
    if (fields != null)
      await store.put({
        'id': goal?['id'] ?? store.id('goal'),
        'kind': 'goal',
        ...fields,
      }, 'Save goal');
  }

  Future<void> _habit() async {
    final fields = await entryForm(
      context,
      'A small recurring anchor',
      [
        const EntryField('title', 'Habit name'),
        const EntryField(
          'minutes',
          'Minimum viable duration (minutes)',
          value: '15',
        ),
        const EntryField(
          'weekdays',
          'Weekdays (1=Mon to 7=Sun, comma-separated)',
          value: '1,2,3,4,5',
        ),
      ],
      validate: (v) {
        final minutes = int.tryParse(v['minutes']!);
        final days = v['weekdays']!
            .split(',')
            .map((d) => int.tryParse(d.trim()))
            .toList();
        if (minutes == null || minutes < 1 || minutes > 1440)
          return 'Enter 1–1440 minutes.';
        if (days.any((d) => d == null || d < 1 || d > 7))
          return 'Choose weekdays 1–7.';
        return null;
      },
    );
    if (fields != null)
      await store.put({
        'id': store.id('habit'),
        'kind': 'habit',
        'title': fields['title'],
        'minutes': int.parse(fields['minutes']!),
        'weekdays': fields['weekdays']!
            .split(',')
            .map((d) => int.parse(d.trim()))
            .toList(),
        'days': [],
      }, 'Create habit');
  }

  Future<void> _planHabits() async {
    if (!await confirm(
      'Plan the next seven days of habits?',
      'Create finite task instances for your selected weekdays. Existing instances are preserved. Paused habits are skipped.',
    ))
      return;
    final now = clock.now();
    await store.change('Generate seven days of habit instances', (records) {
      for (final habit in store.of('habit')) {
        if (habit['paused'] == true) continue;
        for (var i = 0; i < 7; i++) {
          final date = DateTime.utc(now.year, now.month, now.day + i);
          if (!List.from(habit['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7])
              .contains(date.weekday))
            continue;
          final day = clock.day(date), id = '${habit['id']}-${clock.day(date)}';
          if (records.containsKey(id)) continue;
          records[id] = {
            ...PlanTask(
              id: id,
              title: habit['title'],
              minutes: habit['minutes'] ?? 15,
              deadline: clock.parse('$day 23:59'),
              priority: 1,
            ).toJson(),
            'kind': 'task',
            'habitId': habit['id'],
          };
        }
      }
    });
  }

  Widget _plan() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: store.busy ? null : _propose,
            child: const Text('Propose a schedule'),
          ),
          OutlinedButton(
            onPressed: () => _block(),
            child: const Text('Create event'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _calendar(),
      const SizedBox(height: 24),
      ExpansionTile(
        expansionAnimationStyle: AnimationStyle(
          duration: motionDuration(context),
        ),
        title: const Text('Backlog & projects'),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _task(),
                child: const Text('Add a task'),
              ),
              OutlinedButton(
                onPressed: _project,
                child: const Text('Add a project'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final project in store.of('project'))
            panel(
              line(
                project['title'],
                project['body'] ?? '',
                action: TextButton(
                  onPressed: () => _project(project),
                  child: const Text('Edit project'),
                ),
              ),
            ),
          Text(
            'Tasks & subtasks',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final task in store.tasks) _taskCard(task),
          if (store.tasks.isEmpty) const Text('No tasks yet.'),
        ],
      ),
    ],
  );
  Future<void> _project([Map<String, dynamic>? project]) async {
    final fields = await entryForm(context, 'A project', [
      EntryField('title', 'Project name', value: project?['title'] ?? ''),
      EntryField(
        'body',
        'Goal / definition of done',
        value: project?['body'] ?? '',
        lines: 3,
        optional: true,
      ),
    ]);
    if (fields != null)
      await store.put({
        'id': project?['id'] ?? store.id('project'),
        'kind': 'project',
        ...fields,
      }, 'Save project');
  }

  Future<void> _block([PlanBlock? block, String? localStart]) async {
    final now = clock.now();
    final fields = await entryForm(
      context,
      'Time block',
      [
        EntryField('title', 'Title', value: block?.title ?? ''),
        EntryField(
          'start',
          'Start (${clock.name})',
          value: localStart ?? _editableTime(block?.start ?? now),
        ),
        EntryField(
          'end',
          'End (${clock.name})',
          value: block != null
              ? _editableTime(block.end)
              : localStart != null
              ? _eventEnd(localStart)
              : _editableTime(now.add(const Duration(hours: 1))),
        ),
        EntryField(
          'task',
          'Linked task',
          value: block?.taskId ?? '',
          optional: true,
          choices: {
            '': 'No task link',
            if (block?.taskId != null)
              block!.taskId!: 'Current task — review mapping',
            for (final task in resolveHierarchy(store.tasks).leaves)
              task.id: task.title,
          },
        ),
        EntryField(
          'related',
          'Event tasks / task groups',
          value: jsonEncode(block?.relatedTaskIds ?? []),
          optional: true,
          multiple: true,
          choices: {for (final task in store.tasks) task.id: task.title},
        ),
        EntryField(
          'fixed',
          'Commitment type',
          value: block?.fixed == false ? 'flexible' : 'fixed',
          choices: const {
            'fixed': 'Fixed commitment',
            'flexible': 'LifeOS flexible block',
          },
        ),
      ],
      validate: (v) {
        try {
          if (!clock.parse(v['end']!).isAfter(clock.parse(v['start']!)))
            return 'End must be after start.';
        } catch (e) {
          return e.toString();
        }
        return null;
      },
    );
    if (fields == null) return;
    await store.put({
      ...?store.snapshot.records[block?.id],
      ...PlanBlock(
        id: block?.id ?? store.id('block'),
        title: fields['title']!,
        start: clock.parse(fields['start']!),
        end: clock.parse(fields['end']!),
        fixed: fields['fixed'] == 'fixed',
        pinned: fields['fixed'] == 'flexible',
        taskId: fields['task']!.isEmpty ? null : fields['task'],
        source: block?.source ?? 'LifeOS',
        relatedTaskIds: List<String>.from(jsonDecode(fields['related']!)),
      ).toJson(),
      'kind': 'block',
    }, 'Manually edit time block');
  }

  String _editableTime(DateTime instant) {
    final text = clock.stamp(instant);
    try {
      clock.parse(text);
      return text;
    } catch (_) {
      return instant.toUtc().toIso8601String();
    }
  }

  String _eventEnd(String start) {
    try {
      return _editableTime(clock.parse(start).add(const Duration(hours: 1)));
    } catch (_) {
      return start;
    }
  }

  Future<void> _propose() async {
    final fields = await entryForm(
      context,
      'Your availability',
      [
        const EntryField(
          'start',
          'Daily available from (HH:MM)',
          value: '09:00',
        ),
        const EntryField(
          'end',
          'Daily available until (HH:MM)',
          value: '18:00',
        ),
        const EntryField('days', 'Planning horizon (1–30 days)', value: '7'),
        const EntryField(
          'reserve',
          'Keep free time unallocated (%)',
          value: '20',
        ),
      ],
      validate: (v) {
        final reserve = int.tryParse(v['reserve']!);
        if (reserve == null || reserve < 0 || reserve > 70)
          return 'Choose 0–70% free time.';
        final days = int.tryParse(v['days']!);
        if (days == null || days < 1 || days > 30) return 'Choose 1–30 days.';
        try {
          final date = clock.day(clock.now());
          if (!clock
              .parse('$date ${v['end']}')
              .isAfter(clock.parse('$date ${v['start']}')))
            return 'Availability must end after it starts.';
        } catch (e) {
          return e.toString();
        }
        return null;
      },
    );
    if (fields == null || !mounted) return;
    late final List<TimeWindow> windows;
    try {
      windows = availabilityWindows(
        clock: clock,
        now: clock.now(),
        days: int.parse(fields['days']!),
        start: fields['start']!,
        end: fields['end']!,
      );
    } catch (error) {
      message(
        'No proposal created: $error Choose hours valid throughout the horizon. Existing records were preserved.',
      );
      return;
    }
    final proposal = Scheduler().propose(
      revision: store.snapshot.revision,
      tasks: store.tasks,
      existing: store.blocks,
      windows: reserveFreeTime(
        windows,
        store.blocks,
        int.parse(fields['reserve']!),
      ),
    );
    if (!mounted) return;
    final before = store.blocks
        .where((b) => !b.immovable)
        .map((b) => '${b.title}: ${clock.stamp(b.start)}')
        .join('\n');
    final after = proposal.blocks
        .where((b) => !b.immovable)
        .map(
          (b) => '${b.title}: ${clock.stamp(b.start)} → ${clock.stamp(b.end)}',
        )
        .join('\n');
    final issues = [
      ...proposal.conflicts,
      for (final id in proposal.unscheduled)
        'Cannot fit: ${store.snapshot.records[id]?['title'] ?? id}',
    ];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review your proposed schedule'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(
              'BEFORE\n${before.isEmpty ? 'No flexible blocks' : before}\n\nAFTER\n${after.isEmpty ? 'No new flexible blocks' : after}\n\n${issues.join('\n')}\n\nDeadline-first planning leaves ${fields['reserve']}% of available free time unallocated. Fixed/pinned blocks and true deadlines are preserved. Nothing has been applied.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: proposal.feasible
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Approve changes'),
          ),
        ],
      ),
    );
    if (accepted == true) await store.apply(proposal);
  }
}
