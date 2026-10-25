import 'planning.dart';
import 'clock.dart';

/// A local tool parser, intentionally not described as a language model.
class LocalActionProposal {
  const LocalActionProposal(this.description, this.task);
  final String description;
  final PlanTask task;
}

class OfflineAssistant {
  const OfflineAssistant();
  LocalActionProposal propose(
    String text,
    List<PlanTask> tasks,
    ZoneClock clock,
    String newId,
  ) {
    final colon = text.indexOf(':');
    if (colon < 0)
      throw const FormatException(
        'Use Add:, Remaining:, or Deadline: followed by fields separated with |.',
      );
    final command = text.substring(0, colon).trim().toLowerCase();
    final parts = text
        .substring(colon + 1)
        .split('|')
        .map((p) => p.trim())
        .toList();
    if (command == 'add') {
      if (parts.length != 3 || parts[0].isEmpty)
        throw const FormatException(
          'Add: task title | minutes | YYYY-MM-DD HH:MM',
        );
      final minutes = int.tryParse(parts[1]);
      if (minutes == null || minutes < 1 || minutes > 100000)
        throw const FormatException('Enter a valid duration.');
      return LocalActionProposal(
        'Create a task; no time block is booked.',
        PlanTask(
          id: newId,
          title: parts[0],
          minutes: minutes,
          deadline: clock.parse(parts[2]),
        ),
      );
    }
    if (parts.length != 2)
      throw const FormatException(
        'Remaining: exact task title | minutes, or Deadline: exact task title | YYYY-MM-DD HH:MM',
      );
    final matches = tasks
        .where((t) => t.title.toLowerCase() == parts[0].toLowerCase())
        .toList();
    if (matches.length != 1)
      throw const FormatException(
        'Task title must match exactly one local task. Edit from Plan if titles are duplicated.',
      );
    final current = matches.single;
    if (command == 'remaining') {
      final minutes = int.tryParse(parts[1]);
      if (minutes == null || minutes < 1 || minutes > 100000)
        throw const FormatException(
          'Use positive remaining minutes. Completion is a separate explicit action.',
        );
      return LocalActionProposal(
        'Change remaining effort from ${current.minutes} to $minutes minutes. The deadline stays fixed.',
        PlanTask.fromJson({...current.toJson(), 'minutes': minutes}),
      );
    }
    if (command == 'deadline') {
      return LocalActionProposal(
        'Change the true deadline only after confirming an extension or correction. Existing work blocks are not moved.',
        PlanTask.fromJson({
          ...current.toJson(),
          'deadline': clock.parse(parts[1]).toIso8601String(),
        }),
      );
    }
    throw const FormatException(
      'Unsupported local command. No changes were made.',
    );
  }
}
