import 'dart:convert';

/// Only bounded codes/statuses cross the provider boundary. Never echo provider
/// messages: they may contain credentials, submitted text or account details.
class AiFailure extends StateError {
  AiFailure(this.code, {this.upstreamStatus, String? rpcStatus})
    : rpcStatus = _rpcStatuses.contains(rpcStatus) ? rpcStatus : null,
      super(_messages[code] ?? _messages['gateway_failure']!);
  final String code;
  final int? upstreamStatus;
  final String? rpcStatus;
  static const _rpcStatuses = {
    'INVALID_ARGUMENT',
    'FAILED_PRECONDITION',
    'UNAUTHENTICATED',
    'PERMISSION_DENIED',
    'NOT_FOUND',
    'RESOURCE_EXHAUSTED',
    'UNAVAILABLE',
    'INTERNAL',
    'DEADLINE_EXCEEDED',
  };
  static const _messages = {
    'gateway_auth': 'Gateway token rejected. Re-enter the token saved in your Worker secrets.',
    'gateway_not_ready': 'Gateway configuration is incomplete. Check its secrets, model ID and free-project confirmation, then deploy the settings.',
    'gateway_failure': 'Gateway generation failed. Update the Worker code to obtain a specific provider error code.',
    'gateway_timeout':
        'The provider request timed out. No automatic retry was made.',
    'gateway_network': 'The gateway could not reach Gemini. Check Worker connectivity or try again later.',
    'gemini_key': 'Gemini rejected the API key. Check the GEMINI_API_KEY Worker secret and redeploy.',
    'gemini_permission': 'Gemini denied access. Check the key restrictions, API/project access and free-tier eligibility. Keep billing disabled.',
    'gemini_model': 'Gemini could not find this model for generation. Check the exact model ID and project access.',
    'gemini_request': 'Gemini rejected a request or configuration value. Compare the Worker API key/model with a direct test and check the Google status below.',
    'gemini_precondition': 'Gemini rejected an account/project precondition. Check region, project and free-tier eligibility. Keep billing disabled.',
    'gemini_quota': 'Gemini quota was reached or is unavailable for this project/model. Check the free-tier quota and reset time; no paid fallback was used.',
    'rate_limit': 'A request limit was reached. Check the free-tier or local gateway limit and wait for its reset.',
    'gemini_unavailable': 'Gemini is temporarily unavailable. No automatic retry or provider switch was made.',
    'gemini_blocked': 'Gemini returned a blocked response. Try a different question; no local records changed.',
    'gemini_output_limit': 'Gemini reached the output limit before returning a complete answer. Try a shorter question or request a shorter answer.',
    'gemini_empty': 'Gemini returned no answer text. Try a short text-only question and check model compatibility.',
    'gemini_invalid_response': 'Gemini returned an unreadable response. Check the selected model and gateway compatibility.',
    'invalid_request': 'The gateway rejected the request format or size.',
  };
  static Map<dynamic, dynamic> _object(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map ? value : {};
    } catch (_) {
      return {};
    }
  }

  factory AiFailure.fromGateway(int status, String body) {
    final data = _object(body), code = data['code'];
    final upstream = data['upstreamStatus'];
    return AiFailure(
      code is String && _messages.containsKey(code)
          ? code
          : switch (status) {
              401 => 'gateway_auth',
              429 => 'rate_limit',
              503 => 'gateway_not_ready',
              400 || 413 => 'invalid_request',
              _ => 'gateway_failure',
            },
      upstreamStatus: upstream is int && upstream >= 400 && upstream <= 599
          ? upstream
          : null,
      rpcStatus: data['rpcStatus'] is String ? data['rpcStatus'] : null,
    );
  }
  factory AiFailure.fromGemini(int status, String body) {
    final error = _object(body)['error'];
    final rpcStatus = error is Map && error['status'] is String
        ? error['status'] as String
        : null;
    final invalidKeyMessage =
        error is Map &&
        error['message'] is String &&
        RegExp(
          r'api key (?:not valid|is invalid|expired|has expired|was reported as leaked)|invalid api key',
          caseSensitive: false,
        ).hasMatch(error['message'] as String);
    final reasons = error is Map && error['details'] is List
        ? (error['details'] as List)
              .whereType<Map>()
              .map((d) => d['reason'])
              .toSet()
        : <dynamic>{};
    return AiFailure(
      reasons.contains('API_KEY_INVALID') ||
              reasons.contains('API_KEY_EXPIRED') ||
              invalidKeyMessage ||
              status == 401
          ? 'gemini_key'
          : status == 400 && rpcStatus == 'FAILED_PRECONDITION'
          ? 'gemini_precondition'
          : status == 403
          ? 'gemini_permission'
          : status == 404
          ? 'gemini_model'
          : status == 429
          ? 'gemini_quota'
          : status >= 500
          ? 'gemini_unavailable'
          : 'gemini_request',
      upstreamStatus: status,
      rpcStatus: rpcStatus,
    );
  }
  @override
  String toString() =>
      '$message [code: $code${upstreamStatus == null ? '' : '; Gemini HTTP $upstreamStatus'}${rpcStatus == null ? '' : '; Google status $rpcStatus'}]';
}
