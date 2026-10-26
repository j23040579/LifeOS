import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../core/design/motion.dart';
import '../../domain/day_assessment.dart';
import '../../domain/planning.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.day,
    required this.asOf,
    required this.assessment,
    required this.todos,
    required this.upcoming,
    required this.onCreate,
    required this.onPlan,
    required this.onTask,
    required this.onComplete,
    required this.onRefresh,
    required this.onEvidence,
    required this.onDemo,
    required this.busy,
    required this.refreshing,
    required this.stale,
    this.notice,
  });
  final String day, asOf;
  final DayAssessment assessment;
  final List<PlanTask> todos, upcoming;
  final VoidCallback onCreate, onPlan, onRefresh, onEvidence, onDemo;
  final ValueChanged<PlanTask> onTask, onComplete;
  final bool busy, refreshing, stale;
  final String? notice;
  @override
  Widget build(BuildContext context) {
    final colors = EditorialPalette.of(context), theme = Theme.of(context);
    Widget card(Color color, Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          theme.colorScheme.surface,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$day · YOUR DAY', style: theme.textTheme.labelLarge),
              const SizedBox(height: 24),
              Text(
                'Hello.\nMake today\nfeel lighter.',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width >= 900 ? 68 : 44,
                  height: 1.05,
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.checklist, size: 18),
                    label: Text('${todos.length} to-dos today'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPlan,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Open calendar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        card(
          colors.brandSurface,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOW YOU’RE DOING NOW',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.brandText,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: assessment.score == null
                    ? 'Current score: not enough evidence'
                    : 'Current planning score ${assessment.score} out of 100',
                excludeSemantics: true,
                child: TweenAnimationBuilder<double>(
                  duration: motionDuration(context, milliseconds: 480),
                  tween: Tween(end: assessment.score?.toDouble() ?? 0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Text(
                    assessment.score == null
                        ? '— / 100'
                        : '${value.round()} / 100',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 64,
                      color: colors.brandText,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(assessment.feedback, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                '${assessment.source}${assessment.model == null ? '' : ' · ${assessment.model}'} · $asOf\nEvidence confidence: ${assessment.confidence}. A planning snapshot, not total progress or a health rating.',
                style: theme.textTheme.bodySmall,
              ),
              if (stale)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Updated local snapshot: the evidence changed or the previous Gemini assessment expired. Refresh for new Gemini feedback.',
                  ),
                ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(notice!),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: refreshing ? null : onRefresh,
                    icon: Icon(
                      refreshing
                          ? Icons.hourglass_top
                          : Icons.auto_awesome_outlined,
                    ),
                    label: Text(
                      refreshing ? 'Reviewing your day…' : 'Refresh check-in',
                    ),
                  ),
                  TextButton(
                    onPressed: onEvidence,
                    child: const Text('How is this calculated?'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Today’s to-dos', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (todos.isEmpty)
          card(
            colors.featureSurface,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A little open space.', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'No remaining work is due today, overdue, or linked to today’s events. Choose what deserves a place in your day.',
                ),
                TextButton(
                  onPressed: onDemo,
                  child: const Text('Explore a separate demo workspace'),
                ),
              ],
            ),
          ),
        for (final task in todos) _todo(context, task),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Next up · upcoming', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final task in upcoming.take(3)) _todo(context, task),
        ],
      ],
    );
  }

  Widget _todo(BuildContext context, PlanTask task) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: EditorialPalette.of(context).featureSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onTask(task),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Complete ${task.title}',
                onPressed: busy ? null : () => onComplete(task),
                icon: const Icon(Icons.radio_button_unchecked),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${task.minutes} min remaining · Priority ${task.priority}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
