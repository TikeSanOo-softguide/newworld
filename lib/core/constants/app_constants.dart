/// Application-wide constants for NEWWOLD.
abstract final class AppConstants {
  static const String brandName = 'NEWWOLD';
  static const String appLogoAsset = 'assets/images/logo.png';
  static const String loginBackgroundAsset = 'assets/images/login_bg.jpg';
  static const String loginBackgroundFallback = 'assets/images/login_bg.png';

  /// JSON API base URL, including the `/api` prefix.
  /// Override via `--dart-define=API_BASE_URL=...`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.newsworld.local/api',
  );

  static const String loginPath = '/auth/player_login';
  static const String logoutPath = '/auth/player_logout';
  static const String verifyPath = '/auth/player_verify';
  static const String changePasswordPath = '/user/change_password';
  static const String publicGamesPath = '/public/user/games';
  static const String publicDesksPath = '/public/user/desks';
  static const String publicCamerasPath = '/public/user/cameras';
  static const String publicSettingsPath = '/public/user/parameter-settings';

  /// Same trial account the member website uses.
  static const String trialAccount = 'shiwan093';
  static const String trialPassword = '123456';

  static const String keyRememberMe = 'remember_me';
  static const String keyRememberedAccount = 'remembered_account';
  static const String keyAuthToken = 'auth_token';
  static const String keyAuthUserId = 'auth_user_id';
  static const String keyCsrfToken = 'csrf_token';
  static const String keyAccount = 'auth_account';
  static const String keyDisplayName = 'auth_display_name';
  static const String keyOldUserFlg = 'old_user_flg';
  static const String keyTrialUser = 'trial_user_flg';
}
