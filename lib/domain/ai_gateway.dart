import 'dart:convert';

import 'package:http/http.dart' as http;

import 'clock.dart';

class AiAnswer {
  const AiAnswer(
    this.text,
    this.provider,
    this.model,
    this.live, {
    this.suggestion,
    this.warning,
  });
  final String text, provider, model;
  final bool live;
  final AiTaskSuggestion? suggestion;
  final String? warning;
}

/// Sends only the explicit question and optional source excerpt, never the DB.
class AiGateway {
  AiGateway(this.endpoint, this.token, {http.Client? client})
    : client = client ?? http.Client() {
    final local = const {
      'localhost',
      '127.0.0.1',
      '::1',
      '10.0.2.2',
    }.contains(endpoint.host);
    if (!endpoint.hasAuthority ||
        endpoint.host.isEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.userInfo.isNotEmpty ||
        (!local && endpoint.scheme != 'https') ||
        !const {'http', 'https'}.contains(endpoint.scheme)) {
      throw const FormatException(
        'Use HTTPS for a remote gateway. HTTP is allowed only for local development.',
      );
    }
    if (token.length < 16)
      throw const FormatException(
        'Gateway tokens must be at least 16 characters.',
      );
  }
  factory AiGateway.demo() => AiGateway(
    Uri.parse('http://127.0.0.1'),
    'offline-public-demo-token',
    client: _OfflineDemoClient(),
  );
  final Uri endpoint;
  final String token;
  final http.Client client;
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  Uri _route(String path) =>
      Uri.parse('${endpoint.toString().replaceAll(RegExp(r'/+$'), '')}/$path');
  Future<String> check() async {
    final response = await client
        .get(_route('health'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw StateError('Gateway unavailable (${response.statusCode}).');
    final data = jsonDecode(response.body);
    if (data['ready'] != true)
      throw StateError('The gateway is not configured for a provider yet.');
    return '${data['provider']} · ${data['model']}';
  }

  Future<AiAnswer> ask(
    String question, {
    String? source,
    Map<String, dynamic>? task,
  }) async {
    if (question.trim().isEmpty || question.length > 12000)
      throw const FormatException('Use a question of 1–12,000 characters.');
    final response = await client
        .post(
          _route('v1/chat'),
          headers: _headers,
          body: jsonEncode({
            'message': question,
            if (task != null)
              'task': {
                for (final key in ['id', 'title', 'minutes', 'deadline'])
                  key: task[key],
              },
            'source': source == null
                ? null
                : source.substring(
                    0,
                    source.length > 6000 ? 6000 : source.length,
                  ),
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode != 200)
      throw StateError(
        'AI request failed (${response.statusCode}). No local data was changed.',
      );
    final data = jsonDecode(response.body);
    if (data['text'] is! String || data['text'].isEmpty)
      throw const FormatException('The provider returned no usable text.');
    AiTaskSuggestion? suggestion;
    String? warning;
    if (data['proposal'] is Map) {
      try {
        suggestion = AiTaskSuggestion.parse(
          Map<String, dynamic>.from(data['proposal']),
        );
        if (suggestion.type == 'update_task' &&
            suggestion.taskId != task?['id'])
          throw const FormatException('Proposal targeted an unselected task.');
      } catch (_) {
        suggestion = null;
        warning =
            'An invalid model action was ignored. No local records changed.';
      }
    }
    return AiAnswer(
      data['text'],
      data['provider'] ?? 'Unknown',
      data['model'] ?? 'Unknown',
      data['live'] == true,
      suggestion: suggestion,
      warning: warning,
    );
  }

  void close() => client.close();
}

class AiTaskSuggestion {
  const AiTaskSuggestion(
    this.type,
    this.taskId,
    this.title,
    this.minutes,
    this.deadline,
  );
  final String type;
  final String? taskId, title;
  final int? minutes;
  final DateTime? deadline;
  factory AiTaskSuggestion.parse(Map<String, dynamic> data) {
    final type = data['type'];
    if (type != 'create_task' && type != 'update_task')
      throw const FormatException('Unsupported AI action');
    final minutes = data['minutes'];
    if (minutes != null && (minutes is! int || minutes < 1 || minutes > 100000))
      throw const FormatException('Invalid proposed duration');
    final title = data['title'];
    if (title != null &&
        (title is! String || title.trim().isEmpty || title.length > 500))
      throw const FormatException('Invalid proposed title');
    final deadlineText = data['deadline'];
    DateTime? deadline;
    if (deadlineText != null) {
      if (deadlineText is! String ||
          !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(deadlineText))
        throw const FormatException(
          'Proposed deadlines require an explicit UTC offset.',
        );
      deadline = strictInstant(deadlineText);
    }
    if (type == 'create_task' &&
        (title == null || minutes == null || deadline == null))
      throw const FormatException(
        'A new task requires a title, duration and explicit deadline.',
      );
    if (type == 'update_task' &&
        (data['taskId'] is! String ||
            title == null && minutes == null && deadline == null))
      throw const FormatException(
        'Task changes require a target and changed fields.',
      );
    return AiTaskSuggestion(type, data['taskId'], title, minutes, deadline);
  }
}

class _OfflineDemoClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = request.url.path.endsWith('/health')
        ? {'ready': true, 'provider': 'offline-demo', 'model': 'interface-demo'}
        : {
            'text': 'Demo response — not live AI. This sample tests the chat interface offline. No model read or interpreted your question or sources. Use the local planner or source recall tools for actual work.',
            'provider': 'offline-demo',
            'model': 'interface-demo',
            'live': false,
          };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
