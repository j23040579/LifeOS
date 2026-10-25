import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import 'sample_day.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    this.initialPreview = DayPreview.ready,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final DayPreview initialPreview;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final Set<String> _completed = {};
  late DayPreview _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
  }

  void _reset() => setState(() {
    _completed.clear();
    _preview = DayPreview.ready;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: DesignTokens.brand,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Text('LifeOS', style: theme.textTheme.titleLarge),
                        _CategoryBadge(
                          label: 'YOUR DAILY EDIT',
                          category: 'Study',
                        ),
                        PopupMenuButton<ThemeMode>(
                          tooltip: 'Choose appearance',
                          initialValue: widget.themeMode,
                          onSelected: widget.onThemeChanged,
                          icon: const Icon(Icons.contrast_outlined),
                          itemBuilder: (_) => [
                            for (final mode in ThemeMode.values)
                              CheckedPopupMenuItem(
                                value: mode,
                                checked: widget.themeMode == mode,
                                child: Text(switch (mode) {
                                  ThemeMode.system => 'Use system appearance',
                                  ThemeMode.light => 'Light appearance',
                                  ThemeMode.dark => 'Dark appearance',
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DEMO WORKSPACE',
                            style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fictional data · Changes reset when you restart. No services connected.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                key: const Key('reset-sample'),
                                onPressed: _reset,
                                icon: const Icon(Icons.restart_alt),
                                label: const Text('Reset sample'),
                              ),
                              PopupMenuButton<DayPreview>(
                                tooltip: 'Preview sample states',
                                onSelected: (value) =>
                                    setState(() => _preview = value),
                                itemBuilder: (_) => [
                                  for (final preview in DayPreview.values)
                                    PopupMenuItem(
                                      value: preview,
                                      child: Text(switch (preview) {
                                        DayPreview.ready => 'Sample day',
                                        DayPreview.loading => 'Loading state',
                                        DayPreview.empty => 'Empty state',
                                        DayPreview.error => 'Error state',
                                      }),
                                    ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Preview states'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _DayHeading(completed: _completed.length),
                    const SizedBox(height: 32),
                    if (_preview == DayPreview.ready)
                      _ready(context)
                    else
                      _alternative(context),
                    const SizedBox(height: 32),
                    Text(
                      'Sample times shown in Asia/Kuala_Lumpur. '
                      'No calendar changes have been made.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ready(BuildContext context) {
    final theme = Theme.of(context);
    final priorities = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your priorities', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text('${_completed.length} of 3 sample priorities complete'),
        ),
        const SizedBox(height: 16),
        for (final priority in SampleDay.priorities)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Panel(
              color: priority.id == 'assignment'
                  ? EditorialPalette.of(context).featureSurface
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(
                    label: priority.category,
                    category: priority.category,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priority.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: priority.id == 'assignment' ? 26 : 22,
                      height: 1.3,
                      color: priority.id == 'assignment'
                          ? EditorialPalette.of(context).featureText
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priority.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: Key('complete-${priority.id}'),
                    onPressed: () => setState(() {
                      if (!_completed.add(priority.id)) {
                        _completed.remove(priority.id);
                      }
                    }),
                    icon: Icon(
                      _completed.contains(priority.id)
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                    ),
                    label: Text(
                      _completed.contains(priority.id)
                          ? 'Completed · Undo'
                          : 'Mark complete',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final schedule = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The shape of your day', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'A rhythm, not a rigid routine.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < SampleDay.blocks.length; index++) ...[
                if (index > 0) const SizedBox(height: 24),
                _ScheduleBlock(
                  block: SampleDay.blocks[index],
                  complete: _completed.contains(
                    SampleDay.blocks[index].priorityId,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
        if (constraints.maxWidth < 900 || largeText) {
          return Column(
            children: [priorities, const SizedBox(height: 24), schedule],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: priorities),
            const SizedBox(width: 32),
            Expanded(child: schedule),
          ],
        );
      },
    );
  }

  Widget _alternative(BuildContext context) {
    final theme = Theme.of(context);
    if (_preview == DayPreview.loading) {
      return Semantics(
        label: 'Loading sample day',
        liveRegion: true,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Loading sample day…'),
              for (var i = 0; i < 3; i++)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final error = _preview == DayPreview.error;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.event_available_outlined,
            color: error ? theme.colorScheme.error : null,
          ),
          const SizedBox(height: 16),
          Text(
            error ? 'The sample day could not load' : 'A little open space',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error
                ? 'This is a preview of an error. No data has been lost.'
                : 'No priorities or time blocks in this sample state.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _preview = DayPreview.ready),
            child: Text(error ? 'Retry sample' : 'Load sample day'),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color});

  final Color? color;

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(DesignTokens.radiusPanel),
    ),
    child: child,
  );
}

class _ScheduleBlock extends StatelessWidget {
  const _ScheduleBlock({required this.block, required this.complete});

  final SampleBlock block;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.time,
          style: theme.textTheme.labelLarge?.copyWith(
            color: EditorialPalette.of(context).brandText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(block.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              block.isFixed ? Icons.lock_outline : Icons.swap_vert,
              size: 20,
            ),
            Text(
              block.detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (complete) const Text('✓ Complete'),
          ],
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.category});
  final String label, category;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editorial = EditorialPalette.of(context);
    final feedback = theme.extension<LifeFeedback>()!;
    final color = category == 'Learn'
        ? feedback.info
        : category == 'Wellbeing'
        ? feedback.success
        : editorial.brandText;
    final surface = category == 'Learn'
        ? feedback.infoSurface
        : category == 'Wellbeing'
        ? feedback.successSurface
        : editorial.brandSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.completed});
  final int completed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editorial = EditorialPalette.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SampleDay.date.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Make room for\n'),
              TextSpan(
                text: 'what matters.',
                style: TextStyle(
                  color: editorial.brandText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: compact ? 44 : 64,
            height: 1.08,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Less noise. More intention. A day that feels like yours.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _Metric(value: '03', label: 'priorities'),
            _Metric(value: '05', label: 'time blocks'),
            _Metric(value: '$completed/3', label: 'complete'),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w400,
          color: EditorialPalette.of(context).featureText,
        ),
      ),
      Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
