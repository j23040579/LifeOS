import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/assistant.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/planning.dart';

void main() {
  final clock = ZoneClock();
  const assistant = OfflineAssistant();
  final task = PlanTask(
    id: 'a',
    title: 'Study',
    minutes: 90,
    deadline: clock.parse('2026-10-28 17:00'),
  );
  test('remaining-effort proposal preserves deadline and input record', () {
    final proposal = assistant.propose(
      'Remaining: Study | 30',
      [task],
      clock,
      'new',
    );
    expect(proposal.task.minutes, 30);
    expect(proposal.task.deadline, task.deadline);
    expect(task.minutes, 90);
  });
  test('ambiguous tasks and unknown commands cannot propose changes', () {
    expect(
      () => assistant.propose('Delete: Study', [task], clock, 'new'),
      throwsFormatException,
    );
    expect(
      () => assistant.propose(
        'Remaining: Study | 30',
        [task, task],
        clock,
        'new',
      ),
      throwsFormatException,
    );
  });
}
