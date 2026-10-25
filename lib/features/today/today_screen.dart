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
                        Text('TODAY', style: theme.textTheme.labelLarge),
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
                          Text('SAMPLE DAY', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Fictional data · Changes reset when you '
                            'restart. No accounts or services connected.',
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
                    Text(
                      SampleDay.date,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make room for\nwhat matters.',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A little structure. Space for real life.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priority.category.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(priority.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(priority.detail),
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
        const Text('Your sample plan, with breathing room between blocks.'),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < SampleDay.blocks.length; index++) ...[
                if (index > 0) const Divider(height: 32),
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
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
        Text(block.time, style: theme.textTheme.labelLarge),
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
            Text(block.detail),
            if (complete) const Text('✓ Complete'),
          ],
        ),
      ],
    );
  }
}
