part of 'workspace_shell.dart';

extension _CalendarActions on _WorkspaceShellState {
  Widget _calendar() => CalendarTimeline(
    clock: clock,
    initialDate: _calendarDate,
    onDateChanged: (date) => _calendarDate = date,
    blocks: store.blocks,
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
          final selected = {
            if (event.taskId != null) event.taskId!,
            ...event.relatedTaskIds,
          };
          final all = store.tasks;
          final roots = all.where((task) {
            if (!selected.contains(task.id)) return false;
            var parent = task.parentId;
            final visited = {task.id};
            while (parent != null && visited.add(parent)) {
              if (selected.contains(parent)) return false;
              parent = all.where((t) => t.id == parent).firstOrNull?.parentId;
            }
            return true;
          }).toList();
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
