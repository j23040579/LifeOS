import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../../core/design/design_tokens.dart';
import '../../data/workspace_database.dart';
import '../../data/documents.dart';
import '../../data/gateway_credentials.dart';
import '../../domain/clock.dart';
import '../../domain/assistant.dart';
import '../../domain/ai_gateway.dart';
import '../../domain/ai_context.dart';
import '../../domain/analytics.dart';
import '../../domain/calendar_file.dart';
import '../../domain/availability.dart';
import '../../domain/day_assessment.dart';
import '../../core/design/motion.dart';
import 'home_overview.dart';
import 'calendar_timeline.dart';
import '../../domain/sample_workspace.dart';
import '../../domain/imports.dart';
import '../../domain/planning.dart';
import '../../application/workspace.dart';
import '../today/today_screen.dart';
import 'entry_form.dart';
import 'trend_chart.dart';

part 'planning_view.dart';
part 'calendar_actions.dart';
part 'home_actions.dart';

part 'learning_view.dart';

part 'progress_view.dart';

part 'coach_view.dart';

part 'data_actions.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    this.workspace,
    this.demoMode = false,
    this.initialGateway,
    this.credentialStore,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final Workspace? workspace;
  final bool demoMode;
  final AiGateway? initialGateway;
  final GatewayCredentialStore? credentialStore;
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  late final Workspace store =
      widget.workspace ??
      Workspace(
        WorkspaceDatabase.local(
          name: widget.demoMode ? 'lifeos_demo' : 'lifeos',
        ),
      );
  late final GatewayCredentialStore _credentials =
      widget.credentialStore ??
      SecureGatewayCredentialStore(demo: widget.demoMode);
  bool _rememberGateway = false;
  late Future<void> loaded = _loadWorkspace();
  Future<void> _loadWorkspace() async {
    await store.load();
    if (!mounted) return;
    final savedTheme = store.snapshot.records['settings']?['theme'];
    for (final mode in ThemeMode.values) {
      if (mode.name == savedTheme) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onThemeChanged(mode);
        });
      }
    }
    unawaited(_restoreGateway());
    if (widget.demoMode && store.snapshot.records.isEmpty) {
      await store.change(
        'Initialize fictional demo workspace',
        (records) => records.addAll(sampleWorkspace(ZoneClock())),
      );
    }
  }

  Future<void> _restoreGateway() async {
    if (widget.initialGateway == null && _credentials.supported) {
      try {
        final saved = await _credentials.read().timeout(
          const Duration(seconds: 3),
        );
        if (saved != null && mounted) {
          refresh(() {
            _gateway = AiGateway(Uri.parse(saved.url), saved.token);
            _gatewayLabel = 'Saved gateway (not checked this session)';
            _rememberGateway = true;
          });
        }
      } catch (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          message(
            'Saved gateway could not be opened. Reconnect in Coach; local records are available.',
          );
        });
      }
    }
  }

  void refresh(VoidCallback change) => setState(change);
  int page = 0;
  DateTime? _calendarDate;
  int _notePage = 0;
  String _sourceCourse = '';
  late AiGateway? _gateway = widget.initialGateway;
  late String? _gatewayLabel = widget.initialGateway == null
      ? null
      : 'Development/test gateway';
  bool _aiBusy = false;
  bool _checkInBusy = false;
  DayAssessment? _dayAssessment;
  int? _assessmentRevision;
  String? _assessmentNotice;
  final List<({String question, AiAnswer answer, int revision})> _answers = [];
  final Set<AiAnswer> _acceptedAiActions = {};
  final Stopwatch _focusWatch = Stopwatch();
  final ValueNotifier<int> _focusSeconds = ValueNotifier(0);
  Timer? _focusTick;
  String? _focusId;
  int? _lastSnapshotMinute;
  @override
  void initState() {
    super.initState();
    _focusTick = Timer.periodic(const Duration(seconds: 1), (_) {
      _focusSeconds.value = _focusWatch.elapsed.inSeconds;
      final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      if (_lastSnapshotMinute != minute) {
        _lastSnapshotMinute = minute;
        if (mounted && page == 0) refresh(() {});
      }
    });
  }

  ZoneClock get clock => ZoneClock(
    store.snapshot.records['settings']?['zone'] ?? 'Asia/Kuala_Lumpur',
  );
  final titles = ['Today', 'Plan', 'Learn', 'Progress', 'Coach'];
  @override
  void dispose() {
    _gateway?.close();
    _focusTick?.cancel();
    _focusSeconds.dispose();
    if (widget.workspace == null) {
      store.database.close();
      store.dispose();
    }
    super.dispose();
  }

  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> confirm(String title, String text) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  ).then((value) => value ?? false);
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loaded,
    builder: (context, result) {
      if (result.hasError)
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your local workspace could not open. Your data has not been replaced.',
                  ),
                  FilledButton(
                    onPressed: () => refresh(() => loaded = store.load()),
                    child: const Text('Retry local storage'),
                  ),
                ],
              ),
            ),
          ),
        );
      if (result.connectionState != ConnectionState.done)
        return const Scaffold(
          body: Center(child: Text('Opening your local workspace…')),
        );
      return AnimatedBuilder(
        animation: store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text('LifeOS / ${titles[page]}'),
            actions: [
              IconButton(
                tooltip: 'Change appearance',
                onPressed: _appearance,
                icon: const Icon(Icons.contrast),
              ),
              IconButton(
                tooltip: 'Workspace settings',
                onPressed: _settings,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              key: PageStorageKey('workspace-$page'),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.demoMode)
                          panel(
                            const Text(
                              'DEMO WORKSPACE · Separate test database with fictional starter data. Personal records are stored elsewhere.',
                            ),
                          ),
                        if (store.busy) const LinearProgressIndicator(),
                        if (store.error != null)
                          panel(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  store.error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => store.load(),
                                  child: const Text('Reload latest local data'),
                                ),
                              ],
                            ),
                          ),
                        DestinationMotion(
                          destination: page,
                          child: switch (page) {
                            0 => _today(),
                            1 => _plan(),
                            2 => _learn(),
                            3 => _progress(),
                            _ => _coach(),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            animationDuration: motionDuration(context),
            selectedIndex: page,
            onDestinationSelected: (value) => refresh(() => page = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                label: 'Learn',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                label: 'Coach',
              ),
            ],
          ),
        ),
      );
    },
  );
  Future<void> _appearance() async {
    final mode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    widget.onThemeChanged(mode);
    await store.put({
      ...?store.snapshot.records['settings'],
      'id': 'settings',
      'kind': 'settings',
      'zone': clock.name,
      'weeklyMinor': store.snapshot.records['settings']?['weeklyMinor'] ?? 0,
      'theme': mode.name,
    }, 'Change appearance');
  }

  void _openDemo() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WorkspaceShell(
        demoMode: true,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontSize: MediaQuery.sizeOf(context).width >= 900 ? 60 : 42,
            height: 1.08,
            letterSpacing: -1.8,
            color: EditorialPalette.of(context).brandText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
  Widget panel(Widget child, {bool feature = false}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: feature
          ? EditorialPalette.of(context).featureSurface
          : Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
  Widget line(String title, String detail, {Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          detail,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null) action,
      ],
    ),
  );
  Widget _today() {
    final today = clock.day(clock.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _homeOverview(),
        const SizedBox(height: 24),
        ExpansionTile(
          expansionAnimationStyle: AnimationStyle(
            duration: motionDuration(context),
          ),
          title: const Text('Goals & daily anchors'),
          children: [
            Text(
              'The longer view',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            for (final goal in store.of('goal'))
              panel(
                line(
                  goal['title'],
                  '${goal['body']} · ${goal['status']}',
                  action: TextButton(
                    onPressed: () => _goal(goal),
                    child: const Text('Review goal'),
                  ),
                ),
              ),
            OutlinedButton(onPressed: _goal, child: const Text('Add a goal')),
            const SizedBox(height: 24),
            Text(
              'Small anchors',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            for (final habit in store.of('habit'))
              panel(
                line(
                  habit['title'],
                  (List.from(habit['days'] ?? []).contains(today))
                      ? 'Done today'
                      : 'Not recorded today',
                  action: TextButton(
                    onPressed: () => store.put({
                      ...habit,
                      'days': (List<String>.from(
                        habit['days'] ?? [],
                      )..remove(today))..add(today),
                    }, 'Record habit completion'),
                    child: Text(
                      habit['paused'] == true
                          ? 'Record anyway'
                          : 'Record today',
                    ),
                  ),
                ),
              ),
            OutlinedButton(onPressed: _habit, child: const Text('Add a habit')),
            TextButton(
              onPressed: _planHabits,
              child: const Text('Plan next week’s habits'),
            ),
            for (final habit in store.of('habit'))
              TextButton(
                onPressed: () => store.put({
                  ...habit,
                  'paused': habit['paused'] != true,
                }, 'Change habit pause'),
                child: Text(
                  '${habit['paused'] == true ? 'Resume' : 'Pause'} ${habit['title']}',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TodayScreen(
                    themeMode: widget.themeMode,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
              ),
              child: const Text('View the fictional design sample'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskCard(PlanTask task, {bool feature = false}) => panel(
    line(
      task.title,
      '${task.minutes} min remaining · Due ${clock.stamp(task.deadline)}\n${task.state.name} · Priority ${task.priority}${store.snapshot.records[task.id]?['sourceStale'] == true ? ' · Source changed; review this action' : ''}${task.parentId == null ? '' : ' · Subtask'}${store.tasks.any((t) => t.parentId == task.id) ? ' · Estimated subtask effort ${(weightedTaskProgress(task.id, store.tasks) * 100).round()}%' : ''}',
      action: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: store.busy ? null : () => store.complete(task),
            icon: Icon(
              task.state == TaskState.completed
                  ? Icons.undo
                  : Icons.check_circle_outline,
            ),
            label: Text(
              task.state == TaskState.completed ? 'Reopen' : 'Complete',
            ),
          ),
          TextButton(onPressed: () => _task(task), child: const Text('Edit')),
          TextButton(
            onPressed: () async {
              if (await confirm(
                'Delete task?',
                'This removes the task and its LifeOS flexible blocks. Dependent tasks will need review.',
              )) {
                await store.deleteTask(task.id);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    ),
    feature: feature,
  );
}
