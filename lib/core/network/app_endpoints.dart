/// Member API paths. The host comes from `AppConfig.apiBaseUrl`.
abstract final class AppEndpoints {
  static const String login = '/auth/player_login';
  static const String logout = '/auth/player_logout';
  static const String verify = '/auth/player_verify';

  static const String changePassword = '/user/change_password';
  static const String users = '/user/users';
  static const String room = '/user/room';
  static const String profile = '/user/profile';
  static const String desks = '/user/desks';
  static const String lastRoundStatus = '/user/last_round_status';
  static const String betResults = '/user/bet_results';

  /// Live server route. The spelling is part of the API contract.
  static const String cancelBetResults = '/user/cancle_bet_results';
  static const String memberLedger = '/user/member_ledger';

  static const String publicGames = '/public/user/games';
  static const String publicDesks = '/public/user/desks';
  static const String publicCameras = '/public/user/cameras';
  static const String publicSettings = '/public/user/parameter-settings';
  static const String streamToken = '/stream/token';

  /// Sent with the member desk list and the public desk list.
  static const Map<String, String> siteNameUserQuery = {'site_name': 'user'};

  static String userById(String userId) => '$users/$userId';

  static String lastRoundStatusFor(int deskId) => '$lastRoundStatus/$deskId';

  static String resultsByDesk(int deskId) => '/user/results_by_desk/$deskId';

  static String confirmBets(int roundId) => '/user/confirm_bets/$roundId';

  static String roundPoolTotals(int roundId) =>
      '/user/round_pool_totals/$roundId';

  /// HLS proxy on this API. The playback host is the camera URL, not an app path.
  static String cameraProxy({
    required String apiBaseUrl,
    required String scheme,
    required String authority,
    required String upstreamPath,
  }) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return '$base/public/user/camera-proxy/$scheme/'
        '${Uri.encodeComponent(authority)}$upstreamPath';
  }
}
