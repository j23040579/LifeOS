import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GatewayCredentials {
  const GatewayCredentials(this.url, this.token);
  final String url, token;
}

abstract interface class GatewayCredentialStore {
  bool get supported;
  Future<GatewayCredentials?> read();
  Future<void> write(GatewayCredentials credentials);
  Future<void> clear();
}

/// Browser credentials remain session-only. Native values use OS-backed storage,
/// never the workspace database, history, or JSON backup.
class SecureGatewayCredentialStore implements GatewayCredentialStore {
  SecureGatewayCredentialStore({bool demo = false})
    : _key = demo ? 'lifeos.demo.gateway.v1' : 'lifeos.gateway.v1';
  final String _key;
  final _storage = const FlutterSecureStorage();
  @override
  bool get supported => !kIsWeb;
  @override
  Future<GatewayCredentials?> read() async {
    if (!supported) return null;
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return GatewayCredentials(data['url'] as String, data['token'] as String);
  }

  @override
  Future<void> write(GatewayCredentials credentials) async {
    if (!supported) throw UnsupportedError('Browser tokens are session-only.');
    await _storage.write(
      key: _key,
      value: jsonEncode({'url': credentials.url, 'token': credentials.token}),
    );
  }

  @override
  Future<void> clear() async {
    if (supported) await _storage.delete(key: _key);
  }
}
