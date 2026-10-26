import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lifeos/domain/day_assessment.dart';
import 'package:lifeos/domain/ai_gateway.dart';
import 'package:lifeos/domain/clock.dart';
import 'package:lifeos/domain/planning.dart';

void main() {
  final clock = ZoneClock('Asia/Kuala_Lumpur'),
      now = DateTime.utc(2026, 10, 26, 4);
  PlanTask task(
    String id,
    int hour, {
    int minutes = 60,
    TaskState state = TaskState.pending,
    String? parent,
  }) => PlanTask(
    id: id,
    title: id,
    minutes: minutes,
    deadline: DateTime.utc(2026, 10, 26, hour),
    state: state,
    parentId: parent,
  );
  test(
    'no evidence is unknown rather than zero; future work is not failure',
    () {
      final result = dayEvidence([task('future', 10)], [], [], clock, now);
      expect(result.localScore, isNull);
      expect(result.todoIds, ['future']);
    },
  );
  test('current score weights only eligible effort and never double counts parents', () {
    final tasks = [
      task('parent', 2, minutes: 600),
      task(
        'done',
        2,
        minutes: 60,
        state: TaskState.completed,
        parent: 'parent',
      ),
      task('remaining', 2, minutes: 180, parent: 'parent'),
      task('later', 10),
    ];
    final result = dayEvidence(tasks, [], [], clock, now);
    expect(result.dueCount, 2);
    expect(result.localScore, 25);
    expect(result.todoIds, contains('later'));
    expect(result.sharedSummary.keys, isNot(contains('titles')));
  });
  test(
    'ended work blocks count today; unrelated lifetime completion does not',
    () {
      final old = PlanTask(
        id: 'old',
        title: 'Old',
        minutes: 5000,
        deadline: DateTime.utc(2020),
        state: TaskState.completed,
      );
      final blocks = [
        PlanBlock(
          id: 'b',
          title: 'B',
          taskId: 'work',
          start: now.subtract(const Duration(hours: 2)),
          end: now.subtract(const Duration(hours: 1)),
        ),
      ];
      final result = dayEvidence(
        [old, task('work', 10)],
        blocks,
        [],
        clock,
        now,
      );
      expect(result.dueCount, 1);
      expect(result.localScore, 0);
    },
  );
  test(
    'invalid or demo model assessments never masquerade as live Gemini',
    () async {
      expect(
        () => DayAssessment.gemini(
          '{"score":101,"feedback":"Fine","confidence":"limited"}',
          'model',
          now,
        ),
        throwsFormatException,
      );
      final demo = AiGateway.demo();
      final evidence = dayEvidence([task('due', 2)], [], [], clock, now);
      await expectLater(demo.assessDay(evidence), throwsFormatException);
      demo.close();
    },
  );
  test('online assessment sends aggregate evidence only and preserves provider label', () async {
    final evidence = dayEvidence(
      [task('private task title', 2)],
      [],
      [],
      clock,
      now,
    );
    final gateway = AiGateway(
      Uri.parse('https://gateway.example'),
      'synthetic-access-token',
      client: MockClient((request) async {
        expect(request.body, isNot(contains('private task title')));
        return http.Response(
          jsonEncode({
            'text': jsonEncode({
              'score': 35,
              'feedback': 'Review the next small step.',
              'confidence': 'limited',
            }),
            'live': true,
            'provider': 'gemini',
            'model': 'gemini-3.8-flash',
          }),
          200,
        );
      }),
    );
    final assessment = await gateway.assessDay(evidence);
    expect(assessment.score, 35);
    expect(assessment.source, 'Gemini assessment');
    expect(assessment.model, 'gemini-3.8-flash');
    gateway.close();
  });
  test('partial effort is reflected and linking a parent includes its future-due leaves today', () {
    final parent = PlanTask(
      id: 'p',
      title: 'P',
      minutes: 120,
      deadline: DateTime.utc(2026, 10, 30),
    );
    final child = PlanTask(
      id: 'c',
      title: 'C',
      minutes: 30,
      estimatedMinutes: 60,
      deadline: now.subtract(const Duration(minutes: 1)),
      parentId: 'p',
    );
    expect(dayEvidence([parent, child], [], [], clock, now).localScore, 50);
    final laterChild = PlanTask(
      id: 'later-child',
      title: 'Later',
      minutes: 30,
      deadline: parent.deadline,
      parentId: 'p',
    );
    final event = PlanBlock(
      id: 'e',
      title: 'E',
      start: now,
      end: now.add(const Duration(hours: 1)),
      relatedTaskIds: ['p'],
    );
    expect(dayEvidence([parent, laterChild], [event], [], clock, now).todoIds, [
      'later-child',
    ]);
  });
}
