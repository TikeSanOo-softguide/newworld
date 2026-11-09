import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../lobby/models/lobby_round_result.dart';

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

  void upsertResult(LobbyRoundResult result) {
    final desks = state.desks
        .map((desk) {
          if (_asInt(desk['id']) != result.deskId) return desk;
          final current = _parseDeskResults(result.deskId, desk['results']);
          final merged = mergeLobbyRoundResults(current, [result]);
          return {
            ...desk,
            'results': merged.map((item) => item.toApiJson()).toList(),
          };
        })
        .toList(growable: false);
    state = _copyWithDesks(desks);
  }

  void synchronizeDeskResults({
    required Map<int, List<LobbyRoundResult>> histories,
    required Map<int, int?> sessionIds,
  }) {
    final desks = state.desks
        .map((desk) {
          final deskId = _asInt(desk['id']);
          if (deskId == null || !histories.containsKey(deskId)) return desk;
          final currentSessionId = _sessionId(desk['session']);
          final nextSessionId = sessionIds[deskId];
          final sameSession =
              currentSessionId != null && currentSessionId == nextSessionId;
          final current = sameSession
              ? _parseDeskResults(deskId, desk['results'])
              : const <LobbyRoundResult>[];
          final results = mergeLobbyRoundResults(current, histories[deskId]!);
          return {
            ...desk,
            'session': nextSessionId == null
                ? null
                : {
                    if (desk['session'] is Map)
                      ...Map<String, dynamic>.from(desk['session'] as Map),
                    'id': nextSessionId,
                  },
            'results': results.map((item) => item.toApiJson()).toList(),
          };
        })
        .toList(growable: false);
    state = _copyWithDesks(desks);
  }

  LobbySnapshot _copyWithDesks(List<Map<String, dynamic>> desks) =>
      LobbySnapshot(
        games: state.games,
        desks: desks,
        cameras: state.cameras,
        parameterSettings: state.parameterSettings,
        failures: state.failures,
      );
}

List<LobbyRoundResult> _parseDeskResults(int deskId, Object? raw) {
  if (raw is! List) return const [];
  final results = <LobbyRoundResult>[];
  for (final item in raw) {
    try {
      results.add(LobbyRoundResult.fromApi(deskId, item));
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed API result for desk $deskId: $error');
    }
  }
  return results;
}

int? _sessionId(Object? raw) {
  final session = raw is Map ? raw : null;
  final id = session?['id'];
  if (id is int) return id;
  if (id is num) return id.toInt();
  return int.tryParse(id?.toString() ?? '');
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
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
        return extractNamedList(
          json,
          'desks',
        ).where(isOnlineBettingDesk).toList();
      }),
      run('cameras', () async {
        final json = await _api.getJson(AppConstants.publicCamerasPath);
        return extractNamedList(
          json,
          'cameras',
        ).map(projectCameraRecord).toList(growable: false);
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

Map<String, dynamic> projectCameraRecord(Map<String, dynamic> camera) {
  const allowedFields = {'id', 'desk_id', 'camera_no', 'position', 'url'};
  return {
    for (final entry in camera.entries)
      if (allowedFields.contains(entry.key))
        entry.key: entry.key == 'url'
            ? _stripCameraUrlCredentials(entry.value)
            : entry.value,
  };
}

Object? _stripCameraUrlCredentials(Object? value) {
  final rawUrl = value?.toString() ?? '';
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.userInfo.isEmpty) return value;
  return uri.replace(userInfo: '').toString();
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
