// Read-only model discovery. Names do not establish free-tier eligibility.
import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';

Future<void> main() async {
  final key = Platform.environment['GEMINI_API_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln(
      'GEMINI_API_KEY is not configured. Supply it through secure environment settings, never source or chat.',
    );
    exitCode = 1;
    return;
  }
  final client = IOClient(
    HttpClient()..findProxy = HttpClient.findProxyFromEnvironment,
  );
  try {
    String? page;
    do {
      final response = await client
          .get(
            Uri.https('generativelanguage.googleapis.com', 'v1beta/models', {
              'pageSize': '100',
              if (page != null) 'pageToken': page,
            }),
            headers: {'x-goog-api-key': key},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200)
        throw StateError('Model list request failed (${response.statusCode}).');
      final data = jsonDecode(response.body);
      for (final model in data['models'] as List? ?? []) {
        if ((model['supportedGenerationMethods'] as List? ?? []).contains(
          'generateContent',
        ))
          stdout.writeln(model['name']);
      }
      page = data['nextPageToken'];
    } while (page != null && page.isNotEmpty);
    stdout.writeln(
      'Verify current free/no-billing availability and data-use terms before configuring any model.',
    );
  } catch (_) {
    stderr.writeln(
      'Model discovery unavailable. Check network access and the key/project permissions.',
    );
    exitCode = 1;
  } finally {
    client.close();
  }
}
