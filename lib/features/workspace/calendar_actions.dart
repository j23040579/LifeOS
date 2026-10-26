part of 'workspace_shell.dart';

extension _CalendarActions on _WorkspaceShellState {
  Widget _calendar() => CalendarTimeline(
    clock: clock,
    initialDate: _calendarDate,
    onDateChanged: (date) => _calendarDate = date,
    blocks: store.blocks,
    tasks: store.tasks,
    eventBodyBuilder: _inlineEventTasks,
    onCreate: (localStart) => _block(null, localStart),
    onOpen: _openEvent,
  );

  Future<void> _openEvent(PlanBlock initial) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final event = store.blocks
              .where((b) => b.id == initial.id)
              .firstOrNull;
          if (event == null)
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('This event was removed.'),
            );
          final roots = eventTasks(event, store.tasks).roots;
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * .85,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Close event',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${clock.stamp(event.start)} → ${clock.stamp(event.end)}\n${event.source} · ${event.immovable ? 'Fixed / pinned' : 'Flexible'}',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: store.busy
                            ? null
                            : () => _task(null, event.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add task to event'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _block(event);
                        },
                        child: const Text('Edit / move event'),
                      ),
                      if (!event.fixed && event.source == 'LifeOS')
                        TextButton(
                          onPressed: () => store.put({
                            ...event.toJson(),
                            'kind': 'block',
                            'pinned': !event.pinned,
                          }, 'Change event pin'),
                          child: Text(
                            event.pinned ? 'Unpin event' : 'Pin event',
                          ),
                        ),
                      TextButton(
                        onPressed: () async {
                          if (await confirm(
                            'Remove this event?',
                            'Linked tasks remain in your backlog. Their deadlines will not change.',
                          )) {
                            await store.remove(event.id);
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text('Remove event'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tasks & subtasks',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Linked tasks stay in your backlog. Linking does not mark them completed or allocate this entire event to each task.',
                  ),
                  if (roots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No tasks linked yet. Add a task or link existing tasks with Edit / move event.',
                      ),
                    ),
                  for (final task in roots) _eventTask(task, event.id, {}),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inlineEventTasks(PlanBlock event) {
    final summary = eventTasks(event, store.tasks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in summary.issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(issue),
          ),
        if (summary.roots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No tasks here yet. Create a task or link existing work in Event details.',
            ),
          ),
        for (final task in summary.roots) _inlineTask(task, event, {}, 0),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: store.busy ? null : () => _task(null, event.id),
              icon: const Icon(Icons.add),
              label: const Text('Create task'),
            ),
            TextButton.icon(
              onPressed: store.busy ? null : () => _chooseEventColor(event),
              icon: const Icon(Icons.palette_outlined),
              label: Text('Color: ${EventColors.fromId(event.colorId).name}'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inlineTask(
    PlanTask task,
    PlanBlock event,
    Set<String> ancestors,
    int depth,
  ) {
    if (ancestors.contains(task.id))
      return const Text('Task hierarchy cycle needs review.');
    final next = {...ancestors, task.id};
    final children = store.tasks.where((t) => t.parentId == task.id).toList();
    final colors = EventColors.fromId(event.colorId),
        brightness = Theme.of(context).brightness;
    final done = task.state == TaskState.completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth.clamp(0, 2) * 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: done,
                activeColor: colors.foreground(brightness),
                checkColor: colors.surface(brightness),
                side: BorderSide(color: colors.foreground(brightness)),
                semanticLabel: '${done ? 'Reopen' : 'Complete'} ${task.title}',
                onChanged: store.busy
                    ? null
                    : (_) async {
                        if (!await store.complete(task))
                          message(store.error ?? 'Task not saved.');
                      },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: colors.foreground(brightness),
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        done
                            ? 'Completed · ${task.effortWeight} min estimated effort'
                            : children.isEmpty
                            ? '${task.minutes} min remaining'
                            : '${(weightedTaskProgress(task.id, store.tasks) * 100).round()}% estimated subtask effort',
                        style: TextStyle(
                          color: colors.foreground(brightness),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Task actions: ${task.title}',
                icon: Icon(
                  Icons.more_horiz,
                  color: colors.foreground(brightness),
                ),
                onSelected: (action) {
                  if (action == 'edit')
                    _task(task);
                  else
                    _task(null, event.id, task.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit task')),
                  PopupMenuItem(value: 'subtask', child: Text('Add subtask')),
                ],
              ),
            ],
          ),
        ),
        for (final child in children)
          _inlineTask(child, event, next, depth + 1),
      ],
    );
  }

  Future<void> _chooseEventColor(PlanBlock event) async {
    final fields = await entryForm(context, 'Choose event color', [
      EntryField(
        'color',
        'Color',
        value: event.colorId,
        builder: (context, value, onChanged) =>
            EventColorPicker(value: value, onChanged: onChanged),
      ),
    ]);
    if (fields == null) return;
    final latest = store.snapshot.records[event.id];
    if (latest == null) {
      message('This event was removed.');
      return;
    }
    await store.put({
      ...latest,
      'colorId': fields['color'],
    }, 'Change event color');
  }

  Widget _eventTask(PlanTask task, String eventId, Set<String> ancestors) {
    if (ancestors.contains(task.id))
      return const Text('Task hierarchy cycle needs review in Plan.');
    final children = store.tasks.where((t) => t.parentId == task.id).toList();
    final visited = {...ancestors, task.id};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: EditorialPalette.of(context).featureSurface,
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          key: ValueKey(task.id),
          initiallyExpanded: true,
          expansionAnimationStyle: AnimationStyle(
            duration: motionDuration(context),
          ),
          title: Text(
            task.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            '${task.minutes} min · ${task.state.name}\nDue ${clock.stamp(task.deadline)}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: store.busy
                      ? null
                      : () async {
                          if (!await store.complete(task))
                            message(store.error ?? 'Not saved.');
                        },
                  icon: Icon(
                    task.state == TaskState.completed
                        ? Icons.undo
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    task.state == TaskState.completed
                        ? 'Reopen task'
                        : 'Complete task',
                  ),
                ),
                TextButton(
                  onPressed: () => _task(task),
                  child: const Text('Edit task'),
                ),
                TextButton(
                  onPressed: () => _task(null, eventId, task.id),
                  child: const Text('Add subtask'),
                ),
              ],
            ),
            for (final child in children) _eventTask(child, eventId, visited),
          ],
        ),
      ),
    );
  }
}
