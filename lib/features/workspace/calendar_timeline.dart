import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../core/design/motion.dart';
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
  });
  final ZoneClock clock;
  final List<PlanBlock> blocks;
  final ValueChanged<String> onCreate;
  final ValueChanged<PlanBlock> onOpen;
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onDateChanged;
  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline> {
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
              ? 'Tap an empty hour to create an event. Tap an event to see its tasks.'
              : 'Tap a date to open its timeline; tap an event to see its tasks.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: motionDuration(context),
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

  Widget _event(PlanBlock block) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      color: EditorialPalette.of(context).brandSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpen(block),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '${widget.clock.stamp(block.start)} → ${widget.clock.stamp(block.end)}',
              ),
              Text(
                '${block.source} · ${block.immovable ? 'Fixed / pinned' : 'Flexible'} · Tap for tasks',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _agenda(DateTime day) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in events(day)) _event(block),
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
      excludeSemantics: true,
      child: Material(
        color: day.month == date.month
            ? EditorialPalette.of(context).brandSurface
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            date = day;
            widget.onDateChanged?.call(date);
            view = CalendarView.day;
          }),
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
    return SizedBox(
      height: 600,
      child: _DayScroll(
        key: ValueKey('${widget.clock.day(date)}-${widget.clock.name}'),
        offset: scrollHour * 64.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 64).clamp(
              1.0,
              double.infinity,
            );
            return SizedBox(
              height: day.minutes / 60 * 64 + 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var minute = 0; minute < day.minutes; minute += 60)
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
                    Positioned(
                      top: place.startMinute / 60 * 64,
                      left: 64 + place.column * width / place.columns + 2,
                      width: (width / place.columns - 4).clamp(
                        1.0,
                        double.infinity,
                      ),
                      height: (place.minutes / 60 * 64 - 2).clamp(
                        48.0,
                        double.infinity,
                      ),
                      child: Semantics(
                        button: true,
                        label:
                            '${place.block.title}, ${widget.clock.stamp(place.block.start)} to ${widget.clock.stamp(place.block.end)}, ${place.block.source}, ${place.block.immovable ? 'fixed or pinned' : 'flexible'}. Open event tasks',
                        excludeSemantics: true,
                        child: Material(
                          color: EditorialPalette.of(context).brandSurface,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => widget.onOpen(place.block),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '${place.block.title}\n${place.block.immovable ? 'Fixed / pinned' : 'Flexible'}',
                                maxLines: place.minutes < 65 ? 1 : 5,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: EditorialPalette.of(context)
                                          .brandText,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
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
