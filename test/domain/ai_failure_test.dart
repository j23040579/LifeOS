import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lifeos/domain/ai_gateway.dart';

import '../../tool/check_gemini.dart' show verifyGeminiGeneration;

void main() {
  test('old gateways and unknown errors remain actionable without echoing raw bodies', () {
    for (final status in [401, 429, 503, 502]) {
      final failure = AiFailure.fromGateway(
        status,
        '{"error":"PRIVATE KEY / DOCUMENT","code":"PRIVATE KEY"}',
      );
      expect(failure.toString(), isNot(contains('PRIVATE')));
    }
    expect(
      AiFailure.fromGateway(502, '<html>server failure</html>').code,
      'gateway_failure',
    );
    expect(AiFailure.fromGateway(401, '{}').code, 'gateway_auth');
  });
  test(
    'Gemini categories use status and key reason, never raw provider messages',
    () {
      final cases = {
        400: 'gemini_request',
        401: 'gemini_key',
        403: 'gemini_permission',
        404: 'gemini_model',
        429: 'gemini_quota',
        503: 'gemini_unavailable',
      };
      for (final entry in cases.entries) {
        final failure = AiFailure.fromGemini(
          entry.key,
          '{"error":{"message":"PRIVATE KEY / DOCUMENT"}}',
        );
        expect(failure.code, entry.value);
        expect(failure.upstreamStatus, entry.key);
        expect(failure.toString(), isNot(contains('PRIVATE')));
      }
      expect(
        AiFailure.fromGemini(
          400,
          '{"error":{"details":[{"reason":"API_KEY_INVALID"}]}}',
        ).code,
        'gemini_key',
      );
    },
  );
  test('chat and health propagate safe gateway diagnostics without retry', () async {
    var calls = 0;
    final gateway = AiGateway(
      Uri.parse('https://gateway.example'),
      'synthetic-session-token',
      client: MockClient((_) async {
        calls++;
        return http.Response(
          '{"code":"gemini_model","upstreamStatus":404,"error":"PRIVATE KEY"}',
          502,
        );
      }),
    );
    for (final action in [
      () => gateway.check(),
      () => gateway.ask('A test question'),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<AiFailure>()
              .having((e) => e.code, 'code', 'gemini_model')
              .having(
                (e) => e.toString(),
                'safe message',
                isNot(contains('PRIVATE')),
              ),
        ),
      );
    }
    expect(calls, 2);
    gateway.close();
  });
  test('direct test sends one fixed JSON request without personal content or retries', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, endsWith('/models/test-flash:generateContent'));
      expect(request.headers['x-goog-api-key'], 'synthetic-key');
      final body = jsonDecode(request.body);
      expect(
        body['contents'][0]['parts'][0]['text'],
        'Reply with a single brief greeting.',
      );
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '{"answer":"Hello","proposal":null}'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    await verifyGeminiGeneration(client, 'synthetic-key', 'test-flash');
    expect(calls, 1);
    client.close();
  });
  test('direct test distinguishes denied generation from a malformed or empty answer', () async {
    for (final entry in [
      (403, '{"error":{"message":"PRIVATE KEY"}}', 'gemini_permission'),
      (429, '{}', 'gemini_quota'),
      (200, '{"candidates":[]}', 'gemini_empty'),
      (
        200,
        '{"candidates":[{"finishReason":"MAX_TOKENS"}]}',
        'gemini_output_limit',
      ),
      (200, '{"promptFeedback":{"blockReason":"SAFETY"}}', 'gemini_blocked'),
      (
        200,
        '{"candidates":[{"content":{"parts":[{"text":"bad JSON"}]}}]}',
        'gemini_invalid_response',
      ),
    ]) {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(entry.$2, entry.$1);
      });
      await expectLater(
        verifyGeminiGeneration(client, 'synthetic-key', 'test-flash'),
        throwsA(isA<AiFailure>().having((e) => e.code, 'code', entry.$3)),
      );
      expect(calls, 1);
      client.close();
    }
  });
}
