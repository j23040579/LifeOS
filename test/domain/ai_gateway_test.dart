import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lifeos/domain/ai_gateway.dart';
import 'package:lifeos/domain/ai_context.dart';
import 'package:lifeos/domain/clock.dart';

void main() {
  const token = 'synthetic-session-token-only';
  test('AI requests contain only the explicit question/source and are labelled by provider', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer $token');
      final body = jsonDecode(request.body);
      expect(body.keys.toSet(), {'message', 'source'});
      expect(body['message'], 'Explain a queue');
      return http.Response(
        jsonEncode({
          'text': 'Mock output',
          'provider': 'mock',
          'model': 'test',
          'live': false,
        }),
        200,
      );
    });
    final gateway = AiGateway(
      Uri.parse('http://127.0.0.1:8787'),
      token,
      client: client,
    );
    final answer = await gateway.ask(
      'Explain a queue',
      source: 'User selected paragraph',
    );
    expect(answer.live, isFalse);
    expect(answer.text, 'Mock output');
    gateway.close();
  });
  test('remote cleartext, URL credentials and weak tokens are rejected', () {
    expect(
      () => AiGateway(Uri.parse('http://remote.example'), token),
      throwsFormatException,
    );
    expect(
      () => AiGateway(Uri.parse('https://user:password@example.com'), token),
      throwsFormatException,
    );
    expect(
      () => AiGateway(Uri.parse('https://example.com'), 'short'),
      throwsFormatException,
    );
  });
  test(
    'quota failures remain failures without any retry or paid fallback',
    () async {
      var calls = 0;
      final gateway = AiGateway(
        Uri.parse('https://gateway.example'),
        token,
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 429);
        }),
      );
      await expectLater(gateway.ask('Explain a queue'), throwsStateError);
      expect(calls, 1);
      gateway.close();
    },
  );
  test('unknown actions, normalized invalid dates and unselected updates cannot mutate anything', () async {
    expect(
      () => AiTaskSuggestion.parse({'type': 'delete_everything'}),
      throwsFormatException,
    );
    expect(
      () => AiTaskSuggestion.parse({
        'type': 'create_task',
        'title': 'Bad',
        'minutes': 30,
        'deadline': '2026-02-30T12:00:00Z',
      }),
      throwsFormatException,
    );
    final gateway = AiGateway(
      Uri.parse('https://gateway.example'),
      token,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'text': 'Proposed change',
            'provider': 'mock',
            'model': 'synthetic',
            'live': false,
            'proposal': {
              'type': 'update_task',
              'taskId': 'unselected',
              'minutes': 45,
            },
          }),
          200,
        ),
      ),
    );
    final answer = await gateway.ask(
      'Help with my selected task',
      task: {
        'id': 'selected',
        'title': 'A',
        'minutes': 30,
        'deadline': '2030-01-01T12:00:00Z',
      },
    );
    expect(answer.suggestion, isNull);
    expect(answer.warning, isNotNull);
    gateway.close();
  });
  test('context sharing is opt-in and budget summary excludes descriptions and notes', () {
    final records = <Map<String, dynamic>>[
      {'id': 'settings', 'kind': 'settings', 'weeklyMinor': 10000},
      {'id': 'private', 'kind': 'note', 'body': 'private lecture'},
      {
        'id': 'expense',
        'kind': 'expense',
        'title': 'private merchant',
        'date': ZoneClock().day(ZoneClock().now()),
        'minor': 1000,
        'paid': true,
      },
    ];
    expect(aiContext(records, 'none', ZoneClock()), isEmpty);
    final summary = aiContext(records, 'budget', ZoneClock());
    expect(summary, contains('1000'));
    expect(summary, isNot(contains('private')));
  });
  test('offline demo is explicitly labelled and requires no provider or credentials', () async {
    final gateway = AiGateway.demo();
    expect(await gateway.check(), contains('offline-demo'));
    final answer = await gateway.ask('Synthetic interface question');
    expect(answer.live, isFalse);
    expect(answer.suggestion, isNull);
    expect(answer.text, contains('not live AI'));
    gateway.close();
  });
}
