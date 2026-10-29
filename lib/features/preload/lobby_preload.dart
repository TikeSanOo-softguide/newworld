import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';

final lobbyPreloadProvider =
    NotifierProvider<LobbyPreloadNotifier, LobbySnapshot>(
  LobbyPreloadNotifier.new,
);

final preloadLoaderProvider = Provider<PreloadLoader>((ref) {
  return ApiPreloadLoader(ref.watch(apiClientProvider));
});

class LobbyPreloadNotifier extends Notifier<LobbySnapshot> {
  @override
  LobbySnapshot build() => LobbySnapshot.empty;

  void replace(LobbySnapshot snapshot) => state = snapshot;
}

class LobbySnapshot {
  const LobbySnapshot({
    required this.games,
    required this.desks,
    required this.cameras,
    required this.parameterSettings,
    required this.failures,
  });

  final List<Map<String, dynamic>> games;
  final List<Map<String, dynamic>> desks;
  final List<Map<String, dynamic>> cameras;
  final List<Map<String, dynamic>> parameterSettings;
  final List<String> failures;

  static const empty = LobbySnapshot(
    games: [],
    desks: [],
    cameras: [],
    parameterSettings: [],
    failures: [],
  );

  String? setting(String type) {
    for (final row in parameterSettings) {
      if (row['type']?.toString() == type) {
        final value = row['value']?.toString() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }
}

abstract class PreloadLoader {
  Future<LobbySnapshot> load({
    required void Function(int completed, int total) onProgress,
  });
}

class ApiPreloadLoader implements PreloadLoader {
  ApiPreloadLoader(this._api);

  final ApiClient _api;

  @override
  Future<LobbySnapshot> load({
    required void Function(int completed, int total) onProgress,
  }) async {
    const total = 4;
    var completed = 0;
    final failures = <String>[];

    Future<List<Map<String, dynamic>>> run(
      String label,
      Future<List<Map<String, dynamic>>> Function() task,
    ) async {
      try {
        return await task();
      } catch (error) {
        failures.add(label);
        return const [];
      } finally {
        completed += 1;
        onProgress(completed, total);
      }
    }

    final results = await Future.wait([
      run('games', () async {
        final json = await _api.getJson(AppConstants.publicGamesPath);
        return extractNamedList(json, 'games');
      }),
      run('desks', () async {
        final json = await _api.getJson(
          AppConstants.publicDesksPath,
          query: const {'site_name': 'user'},
        );
        return extractNamedList(json, 'desks')
            .where(isOnlineBettingDesk)
            .toList();
      }),
      run('cameras', () async {
        final json = await _api.getJson(AppConstants.publicCamerasPath);
        return extractNamedList(json, 'cameras');
      }),
      run('settings', () async {
        final json = await _api.getJson(AppConstants.publicSettingsPath);
        return extractNamedList(json, 'parameterSettings');
      }),
    ]);

    return LobbySnapshot(
      games: results[0],
      desks: results[1],
      cameras: results[2],
      parameterSettings: results[3],
      failures: failures,
    );
  }
}

List<Map<String, dynamic>> extractNamedList(
  Map<String, dynamic> json,
  String key,
) {
  final data = json['data'];
  final raw = data is Map ? data[key] : null;
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

bool isOnlineBettingDesk(Map<String, dynamic> desk) {
  final flag = desk['online_betting_flg'];
  return flag == true || flag == 1 || flag == '1';
}
