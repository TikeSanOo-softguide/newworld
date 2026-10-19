/// Application-wide constants for NEWWOLD.
abstract final class AppConstants {
  static const String brandName = 'NEWWOLD';
  static const String tagline = '新世界';
  static const String appLogoAsset = 'assets/images/app_logo.png';

  /// JSON API base URL. Override via `--dart-define=API_BASE_URL=...`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.newsworld.local',
  );

  /// WebSocket endpoint. Override via `--dart-define=WS_URL=...`.
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://api.newsworld.local/ws',
  );

  static const String loginPath = '/auth/login';

  static const String keyUiStyle = 'ui_style';
  static const String keyRememberMe = 'remember_me';
  static const String keyRememberedUsername = 'remembered_username';
  static const String keyAuthToken = 'auth_token';
  static const String keyAuthUserId = 'auth_user_id';

  /// Per-UI-style remember keys (U1 / U2 keep separate accounts).
  static String keyRememberMeFor(UiStyle style) => 'remember_me_${style.id}';
  static String keyRememberedUsernameFor(UiStyle style) =>
      'remembered_username_${style.id}';
  static String keyRememberedPasswordFor(UiStyle style) =>
      'remembered_password_${style.id}';
}

/// Persisted browsing layout identifiers.
enum UiStyle {
  u1('U1'),
  u2('U2');

  const UiStyle(this.id);
  final String id;

  static UiStyle? fromId(String? value) {
    if (value == null) return null;
    for (final style in UiStyle.values) {
      if (style.id == value) return style;
    }
    return null;
  }
}
