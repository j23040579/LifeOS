import 'package:lifeos/data/gateway_credentials.dart';

class MemoryCredentials implements GatewayCredentialStore {
  GatewayCredentials? value;
  bool fail = false;
  @override
  bool get supported => true;
  @override
  Future<GatewayCredentials?> read() async {
    if (fail) throw StateError('OS storage unavailable');
    return value;
  }

  @override
  Future<void> write(GatewayCredentials credentials) async {
    value = credentials;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
