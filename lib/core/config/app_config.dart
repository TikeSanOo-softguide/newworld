import 'package:flutter/foundation.dart';

/// Environment configuration. Endpoint paths live in [AppEndpoints].
abstract final class AppConfig {
  /// Chrome uses this PC. A real phone uses the PC's LAN address.
  /// Override both via `--dart-define=API_BASE_URL=...`.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Member API origin, including the `/api` suffix.
  /// Socket.IO derives its host by removing that suffix.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return 'http://localhost:3001/api';
    return 'http://192.168.10.176:3001/api';
  }
}
