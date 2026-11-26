import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/app_endpoints.dart';

final lobbyRepositoryProvider = Provider<LobbyRepository>((ref) {
  return LobbyRepository(ref.watch(apiClientProvider));
});

/// Member lobby requests. Response parsing stays with the caller.
class LobbyRepository {
  LobbyRepository(this._api);

  final ApiClient _api;

  Future<void> verify(String token) async {
    await _api.getJson(AppEndpoints.verify, token: token);
  }

  Future<void> updateRoom({
    required String token,
    String? csrfToken,
    required String room,
  }) async {
    await _api.patchJson(
      AppEndpoints.room,
      token: token,
      csrfToken: csrfToken,
      body: {'room': room},
    );
  }

  /// Raw `data.desks`, or null when that list is absent.
  Future<List<dynamic>?> getDesks(String token) async {
    final response = await _api.getJson(
      AppEndpoints.desks,
      query: AppEndpoints.siteNameUserQuery,
      token: token,
    );
    final data = response['data'];
    final desks = data is Map ? data['desks'] : null;
    if (desks is! List) return null;
    return desks;
  }

  Future<Map<String, dynamic>> getProfile(String token) {
    return _api.getJson(AppEndpoints.profile, token: token);
  }

  Future<Map<String, dynamic>> lastRoundStatus(int deskId, String token) {
    return _api.getJson(AppEndpoints.lastRoundStatusFor(deskId), token: token);
  }
}
