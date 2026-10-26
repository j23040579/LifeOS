// One fixed, non-personal generation request. No retry, model switch or raw
// provider output/error logging. Credentials are read from the environment only.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:lifeos/domain/ai_failure.dart';

Future<void> verifyGeminiGeneration(
  http.Client client,
  String key,
  String model,
) async {
  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model))
    throw const FormatException('Use the model ID without models/ or spaces.');
  final response = await client
      .post(
        Uri.https(
          'generativelanguage.googleapis.com',
          'v1beta/models/$model:generateContent',
        ),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': 'Return JSON with answer (string) and proposal (null).'},
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'Reply with a single brief greeting.'},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'maxOutputTokens': 2048,
            'temperature': 0.2,
          },
        }),
      )
      .timeout(
        const Duration(seconds: 80),
        onTimeout: () => throw AiFailure('gateway_timeout'),
      );
  if (response.statusCode != 200)
    throw AiFailure.fromGemini(response.statusCode, response.body);
  dynamic data;
  try {
    data = jsonDecode(response.body);
  } catch (_) {
    throw AiFailure('gemini_invalid_response');
  }
  final candidates = data is Map ? data['candidates'] : null;
  final candidate =
      candidates is List && candidates.isNotEmpty && candidates.first is Map
      ? candidates.first as Map
      : <String, dynamic>{};
  final feedback = data is Map ? data['promptFeedback'] : null;
  if (feedback is Map && feedback['blockReason'] != null ||
      const [
        'SAFETY',
        'RECITATION',
        'BLOCKLIST',
        'PROHIBITED_CONTENT',
      ].contains(candidate['finishReason']))
    throw AiFailure('gemini_blocked');
  if (candidate['finishReason'] == 'MAX_TOKENS')
    throw AiFailure('gemini_output_limit');
  final content = candidate['content'];
  final parts = content is Map && content['parts'] is List
      ? content['parts'] as List
      : [];
  final text = parts
      .whereType<Map>()
      .where((p) => p['thought'] != true && p['text'] is String)
      .map((p) => p['text'])
      .join('\n');
  if (text.trim().isEmpty) throw AiFailure('gemini_empty');
  try {
    final output = jsonDecode(text);
    if (output is! Map ||
        output['answer'] is! String ||
        (output['answer'] as String).trim().isEmpty)
      throw const FormatException();
  } catch (_) {
    throw AiFailure('gemini_invalid_response');
  }
}

Future<void> main() async {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '',
      model = Platform.environment['LIFEOS_AI_MODEL'] ?? '';
  if (key.isEmpty ||
      model.isEmpty ||
      Platform.environment['GEMINI_FREE_PROJECT_CONFIRMED'] != 'true') {
    stderr.writeln(
      'Set GEMINI_API_KEY, LIFEOS_AI_MODEL and GEMINI_FREE_PROJECT_CONFIRMED=true after confirming free/no-billing eligibility. No request was sent.',
    );
    exitCode = 1;
    return;
  }
  final client = IOClient(
    HttpClient()..findProxy = HttpClient.findProxyFromEnvironment,
  );
  try {
    await verifyGeminiGeneration(client, key, model);
    stdout.writeln(
      'PASS: Gemini returned a usable JSON answer for $model. One fixed test question was sent; no personal records or gateway token were sent.',
    );
  } on AiFailure catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } catch (_) {
    stderr.writeln(
      'Network request failed. Check internet/proxy access to generativelanguage.googleapis.com. No retry was made.',
    );
    exitCode = 1;
  } finally {
    client.close();
  }
}
