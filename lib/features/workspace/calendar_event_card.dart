import 'package:flutter/material.dart';

import '../../core/design/event_colors.dart';
import '../../domain/clock.dart';
import '../../domain/event_tasks.dart';
import '../../domain/planning.dart';

/// Same card in the timeline and agenda; the first tap only expands its contents.
class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.event,
    required this.clock,
    required this.tasks,
    required this.expanded,
    required this.onToggle,
    required this.animation,
    required this.body,
    required this.onDetails,
  });
  final PlanBlock event;
  final ZoneClock clock;
  final List<PlanTask> tasks;
  final bool expanded;
  final VoidCallback onToggle, onDetails;
  final Animation<double> animation;
  final Widget body;
  @override
  Widget build(BuildContext context) {
    final colors = EventColors.fromId(event.colorId),
        brightness = Theme.of(context).brightness;
    final foreground = colors.foreground(brightness),
        summary = eventTasks(event, tasks);
    final progress = summary.progress;
    return Material(
      color: colors.surface(brightness),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            onTap: onToggle,
            label:
                '${expanded ? 'Collapse' : 'Expand'} tasks for ${event.title}. ${clock.stamp(event.start)} to ${clock.stamp(event.end)}. ${colors.name}. ${summary.completed} of ${summary.leaves.length} tasks complete.',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: foreground),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          color: foreground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${clock.stamp(event.start)} → ${clock.stamp(event.end)}',
                      style: TextStyle(color: foreground),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${colors.name} · ${event.immovable ? 'Fixed / pinned' : 'Flexible'}',
                      style: TextStyle(color: foreground),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      summary.leaves.isEmpty
                          ? 'No available linked tasks'
                          : '${summary.completed} / ${summary.leaves.length} tasks complete${progress == null ? '' : ' · ${(progress * 100).round()}% estimated effort'}',
                      style: TextStyle(color: foreground),
                    ),
                    if (progress != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ExcludeSemantics(
                          child: LinearProgressIndicator(
                            value: progress,
                            color: foreground,
                            backgroundColor: foreground.withValues(alpha: .15),
                            minHeight: 3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: foreground),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(),
                          body,
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: foreground,
                              side: BorderSide(color: foreground),
                            ),
                            onPressed: onDetails,
                            icon: const Icon(Icons.tune),
                            label: const Text('Event details'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
