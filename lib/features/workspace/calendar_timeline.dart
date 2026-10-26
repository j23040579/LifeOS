import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../core/design/motion.dart';
import '../../core/design/event_colors.dart';
import 'calendar_event_card.dart';
import '../../domain/calendar_geometry.dart';
import '../../domain/clock.dart';
import '../../domain/planning.dart';

enum CalendarView { day, week, month }

class CalendarTimeline extends StatefulWidget {
  const CalendarTimeline({
    super.key,
    required this.clock,
    required this.blocks,
    required this.onCreate,
    required this.onOpen,
    this.initialDate,
    this.onDateChanged,
    this.tasks = const [],
    this.eventBodyBuilder,
  });
  final ZoneClock clock;
  final List<PlanBlock> blocks;
  final ValueChanged<String> onCreate;
  final ValueChanged<PlanBlock> onOpen;
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onDateChanged;
  final List<PlanTask> tasks;
  final Widget Function(PlanBlock)? eventBodyBuilder;
  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline>
    with SingleTickerProviderStateMixin {
  String? _expandedId;
  String? _expandedDay;
  final _expandedKey = GlobalKey();
  late final AnimationController _expansion = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted)
        setState(() => _expandedId = null);
    });
  late final CurvedAnimation _expansionCurve = CurvedAnimation(
    parent: _expansion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expansion.duration = motionDuration(context);
    _expansion.reverseDuration = motionDuration(context, milliseconds: 180);
  }

  @override
  void didUpdateWidget(CalendarTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expandedId != null && !widget.blocks.any((b) => b.id == _expandedId)) {
      _expansion.stop();
      _expandedId = null;
    }
  }

  @override
  void dispose() {
    _expansionCurve.dispose();
    _expansion.dispose();
    super.dispose();
  }

  bool _isExpanded(PlanBlock block, DateTime day) =>
      _expandedId == block.id && _expandedDay == widget.clock.day(day);
  void _toggleEvent(PlanBlock block, DateTime day) {
    if (_isExpanded(block, day)) {
      if (_expansion.status == AnimationStatus.reverse)
        _expansion.forward();
      else
        _expansion.reverse();
      return;
    }
    _expansion.stop();
    _expansion.value = 0;
    setState(() {
      _expandedId = block.id;
      _expandedDay = widget.clock.day(day);
    });
    _expansion.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _expandedKey.currentContext;
      if (mounted && target != null)
        Scrollable.ensureVisible(
          target,
          duration: motionDuration(context),
          alignment: .08,
        );
    });
  }

  late DateTime date = widget.initialDate ?? widget.clock.now();
  CalendarView view = CalendarView.day;
  bool agenda = false;
  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  void shift(int direction) {
    setState(() {
      if (view == CalendarView.month)
        date = DateTime.utc(date.year, date.month + direction, 1);
      else
        date = DateTime.utc(
          date.year,
          date.month,
          date.day + direction * (view == CalendarView.week ? 7 : 1),
        );
    });
    widget.onDateChanged?.call(date);
  }

  List<PlanBlock> events(DateTime date) {
    final day = CalendarDay(widget.clock, date);
    return widget.blocks
        .where((b) => b.start.isBefore(day.end) && b.end.isAfter(day.start))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  String label(DateTime date) =>
      '${weekdays[date.weekday - 1]} · ${widget.clock.day(date)}';
  void _openDate(DateTime day) => setState(() {
    date = day;
    widget.onDateChanged?.call(date);
    view = CalendarView.day;
  });
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              'Your calendar',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Previous ${view.name}',
                  onPressed: () => shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    date = widget.clock.now();
                    widget.onDateChanged?.call(date);
                  }),
                  child: const Text('Today'),
                ),
                IconButton(
                  tooltip: 'Next ${view.name}',
                  onPressed: () => shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${label(date)} · ${widget.clock.name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in CalendarView.values)
              ChoiceChip(
                label: Text(
                  '${value.name[0].toUpperCase()}${value.name.substring(1)}',
                ),
                selected: view == value,
                onSelected: (_) => setState(() => view = value),
              ),
            FilterChip(
              label: const Text('Agenda'),
              selected: agenda || large,
              onSelected: large
                  ? null
                  : (value) => setState(() => agenda = value),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                );
                if (selected != null && mounted)
                  setState(() {
                    date = selected;
                    widget.onDateChanged?.call(date);
                  });
              },
              icon: const Icon(Icons.event_outlined),
              label: const Text('Choose date'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          view == CalendarView.day && !agenda && !large
              ? 'Tap an empty hour to create an event. Tap an event to expand its tasks here.'
              : 'Tap a date to open its timeline; tap an event to expand its tasks here.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: motionDuration(context),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) =>
              current ?? const SizedBox.shrink(),
          child: KeyedSubtree(
            key: ValueKey(
              '${view.name}-${widget.clock.day(date)}-${agenda || large}',
            ),
            child: switch (view) {
              CalendarView.day => agenda || large ? _agenda(date) : _day(date),
              CalendarView.week => _week(),
              CalendarView.month => _month(),
            },
          ),
        ),
      ],
    );
  }

  Widget _event(PlanBlock block, DateTime day) {
    final expanded = _isExpanded(block, day);
    return Padding(
      key: expanded
          ? _expandedKey
          : ValueKey('${widget.clock.day(day)}-${block.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CalendarEventCard(
        event: block,
        clock: widget.clock,
        tasks: widget.tasks,
        expanded: expanded,
        animation: expanded
            ? _expansionCurve
            : const AlwaysStoppedAnimation<double>(0),
        onToggle: () => _toggleEvent(block, day),
        onDetails: () => widget.onOpen(block),
        body: expanded
            ? widget.eventBodyBuilder?.call(block) ??
                  const Text(
                    'No task data available. Use Event details to edit this event.',
                  )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _agenda(DateTime day) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in events(day)) _event(block, day),
      if (events(day).isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Open space. Nothing is scheduled for this day.'),
        ),
      TextButton.icon(
        onPressed: () => widget.onCreate('${widget.clock.day(day)} 09:00'),
        icon: const Icon(Icons.add),
        label: const Text('Create event on this day'),
      ),
    ],
  );
  Widget _week() {
    final monday = DateTime.utc(
      date.year,
      date.month,
      date.day - date.weekday + 1,
    );
    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      date = monday.add(Duration(days: i));
                      widget.onDateChanged?.call(date);
                      view = CalendarView.day;
                    }),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(label(monday.add(Duration(days: i)))),
                    ),
                  ),
                  _agenda(monday.add(Duration(days: i))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _month() {
    final first = DateTime.utc(date.year, date.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final large = MediaQuery.textScalerOf(context).scale(16) > 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${date.year} · Month ${date.month}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = large ? 3 : 7;
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 42; i++)
                  SizedBox(
                    width: (constraints.maxWidth - (columns - 1) * 4) / columns,
                    child: _dateCell(start.add(Duration(days: i))),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _dateCell(DateTime day) {
    final count = events(day).length;
    return Semantics(
      label: '${label(day)}, $count events',
      button: true,
      onTap: () => _openDate(day),
      excludeSemantics: true,
      child: Material(
        color: day.month == date.month
            ? EditorialPalette.of(context).brandSurface
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDate(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Column(
              children: [
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('$count', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _day(DateTime date) {
    final day = CalendarDay(widget.clock, date),
        placements = calendarPlacements(
          widget.blocks,
          CalendarDay(widget.clock, date),
        );
    final now = widget.clock.now();
    final scrollHour = widget.clock.day(date) == widget.clock.day(now)
        ? (now.difference(day.start).inHours - 1).clamp(0, 20)
        : 7;
    final selected = placements
        .where((p) => _isExpanded(p.block, date))
        .firstOrNull;
    final total = day.minutes / 60 * 64 + 48;
    final anchor = selected == null ? 0.0 : selected.startMinute / 60 * 64;
    return SizedBox(
      height: 600,
      child: _DayScroll(
        key: ValueKey('${widget.clock.day(date)}-${widget.clock.name}'),
        offset: scrollHour * 64.0,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected == null)
                _daySegment(
                  day,
                  placements,
                  date,
                  constraints.maxWidth,
                  0,
                  total,
                  null,
                )
              else ...[
                if (anchor > 0)
                  _daySegment(
                    day,
                    placements,
                    date,
                    constraints.maxWidth,
                    0,
                    anchor,
                    selected.block.id,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 64,
                      child: Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('Tasks', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _event(selected.block, date),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Event time is unchanged. The timeline continues below.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _daySegment(
                  day,
                  placements,
                  date,
                  constraints.maxWidth,
                  anchor,
                  total - anchor,
                  selected.block.id,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Details occupy a separate flow row between time-grid segments. They never
  // cover neighboring events or alter the event's scheduled start/end instants.
  Widget _daySegment(
    CalendarDay day,
    List<CalendarPlacement> placements,
    DateTime date,
    double width,
    double from,
    double height,
    String? expandedId,
  ) {
    if (height <= 0) return const SizedBox.shrink();
    final total = day.minutes / 60 * 64 + 48;
    return ClipRect(
      child: SizedBox(
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: total,
          maxHeight: total,
          child: Transform.translate(
            offset: Offset(0, -from),
            child: SizedBox(
              height: total,
              width: width,
              child: _dayCanvas(
                day,
                placements,
                date,
                width,
                from,
                from + height,
                expandedId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayCanvas(
    CalendarDay day,
    List<CalendarPlacement> placements,
    DateTime date,
    double canvasWidth,
    double visibleFrom,
    double visibleUntil,
    String? expandedId,
  ) {
    final width = (canvasWidth - 64).clamp(1.0, double.infinity),
        now = widget.clock.now();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var minute = 0; minute < day.minutes; minute += 60)
          if (minute / 60 * 64 + 64 > visibleFrom &&
              minute / 60 * 64 < visibleUntil)
            Positioned(
              top: minute / 60 * 64,
              left: 0,
              right: 0,
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      calendarHourLabel(
                        widget.clock,
                        day,
                        day.start.add(Duration(minutes: minute)),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label:
                          'Create event ${calendarCreateTime(widget.clock, day, day.start.add(Duration(minutes: minute)))}',
                      child: InkWell(
                        onTap: () => widget.onCreate(
                          calendarCreateTime(
                            widget.clock,
                            day,
                            day.start.add(Duration(minutes: minute)),
                          ),
                        ),
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (!now.isBefore(day.start) && now.isBefore(day.end))
          Positioned(
            top: now.difference(day.start).inSeconds / 3600 * 64,
            left: 54,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 2,
                color: EditorialPalette.of(context).brandText,
              ),
            ),
          ),
        for (final place in placements)
          if (place.startMinute / 60 * 64 +
                      (place.minutes / 60 * 64).clamp(48.0, double.infinity) >
                  visibleFrom &&
              place.startMinute / 60 * 64 < visibleUntil)
            Positioned(
              top: place.startMinute / 60 * 64,
              left: 64 + place.column * width / place.columns + 2,
              width: place.block.id == expandedId
                  ? 5
                  : (width / place.columns - 4).clamp(1.0, double.infinity),
              height: (place.minutes / 60 * 64 - 2).clamp(
                48.0,
                double.infinity,
              ),
              child: place.block.id == expandedId
                  ? ExcludeSemantics(
                      child: Container(
                        decoration: BoxDecoration(
                          color: EventColors.fromId(place.block.colorId)
                              .foreground(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  : _collapsedEvent(
                      place,
                      date,
                      place.startMinute / 60 * 64 < visibleFrom,
                    ),
            ),
      ],
    );
  }

  Widget _collapsedEvent(
    CalendarPlacement place,
    DateTime day,
    bool continuation,
  ) {
    final colors = EventColors.fromId(place.block.colorId),
        brightness = Theme.of(context).brightness;
    return Semantics(
      button: true,
      expanded: false,
      onTap: () => _toggleEvent(place.block, day),
      label:
          '${continuation ? 'Continuation of ' : ''}${place.block.title}, ${widget.clock.stamp(place.block.start)} to ${widget.clock.stamp(place.block.end)}, ${colors.name}, ${place.block.immovable ? 'fixed or pinned' : 'flexible'}. Expand event tasks',
      excludeSemantics: true,
      child: Material(
        color: colors.surface(brightness),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggleEvent(place.block, day),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${place.block.title}\n${place.block.immovable ? 'Fixed / pinned' : 'Flexible'}',
              maxLines: place.minutes < 65 ? 1 : 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: colors.foreground(brightness)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayScroll extends StatefulWidget {
  const _DayScroll({super.key, required this.offset, required this.child});
  final double offset;
  final Widget child;
  @override
  State<_DayScroll> createState() => _DayScrollState();
}

class _DayScrollState extends State<_DayScroll> {
  late final controller = ScrollController(initialScrollOffset: widget.offset);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    child: SingleChildScrollView(controller: controller, child: widget.child),
  );
}
