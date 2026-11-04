import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../auth/auth_service.dart';
import 'models/lobby_dashboard_data.dart';
import 'roadmap/roadmap_calculations.dart';
import 'roadmap/roadmap_models.dart';
import 'widgets/lobby_dashboard_widgets.dart';
import '../preload/lobby_preload.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key, this.showNotice = false});

  final bool showNotice;

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  String _account = '';
  String _balance = '0';
  bool _trial = false;
  int _gameId = 0;
  bool _noticeShown = false;
  bool _kicking = false;
  String? _profileError;
  String? _statusError;
  Map<int, _RoundLive> _rounds = {};

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    final storage = ref.read(secureStorageProvider);
    final account = await storage.getAccount() ?? '';
    final balance = await storage.getBalance();
    final trial = await storage.getTrialUser();
    if (!mounted) return;
    setState(() {
      _account = account;
      _balance = balance;
      _trial = trial;
    });
    final kicked = await _syncLobby();
    if (!mounted || kicked) return;
    await _loadMemberProfile();
    if (!mounted) return;
    if (!widget.showNotice || _noticeShown) return;
    _noticeShown = true;
    final notice = ref
        .read(lobbyPreloadProvider)
        .setting('pc_popup_announcement');
    if (notice == null || notice.trim().isEmpty) return;
    await showGoldDialog(
      context: context,
      kind: GoldDialogKind.info,
      title: '提示',
      message: notice.trim(),
    );
    if (mounted) context.go(AppRoutes.lobby);
  }

  Future<bool> _syncLobby() async {
    final storage = ref.read(secureStorageProvider);
    final api = ref.read(apiClientProvider);
    final token = await storage.getAuthToken();
    final csrf = await storage.getCsrfToken();
    if (token == null || token.isEmpty) return false;
    try {
      await api.getJson(AppConstants.verifyPath, token: token);
    } on ApiException catch (error) {
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
        return true;
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        await ref.read(authServiceProvider).logout();
        if (mounted) context.go(AppRoutes.login);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
    try {
      await api.patchJson(
        AppConstants.roomPath,
        token: token,
        csrfToken: csrf,
        body: const {'room': 'home'},
      );
    } on ApiException catch (error) {
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
        return true;
      }
    } catch (_) {}
    await _loadRoundStatus(api, token);
    return false;
  }

  Future<void> _kickSuperseded(String? ip) async {
    if (_kicking) return;
    _kicking = true;
    final where = ip?.trim() ?? '';
    final message = where.isEmpty
        ? '此账号在其他处登录，你将被踢出系统'
        : '此账号在$where处登录，你将被踢出系统';
    if (mounted) {
      await showGoldDialog(
        context: context,
        kind: GoldDialogKind.error,
        title: '提示',
        message: message,
      );
    }
    await ref.read(authServiceProvider).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _loadRoundStatus(ApiClient api, String token) async {
    final desks = ref.read(lobbyPreloadProvider).desks;
    final next = <int, _RoundLive>{};
    var failed = false;
    await Future.wait(
      desks.map((row) async {
        final id = _asInt(row['id']);
        if (id == null) return;
        try {
          final json = await api.getJson(
            '${AppConstants.lastRoundStatusPath}/$id',
            token: token,
          );
          final data = json['data'];
          if (data is! Map) return;
          final lastRound = data['lastRound'];
          final status = lastRound is Map
              ? lastRound['status']?.toString()
              : null;
          next[id] = _RoundLive(
            status: status,
            seconds: _asInt(data['remaining_seconds']) ?? 0,
          );
        } on ApiException catch (error) {
          if (error.code == 'SESSION_SUPERSEDED') {
            await _kickSuperseded(error.supersededIp);
            return;
          }
          failed = true;
        } catch (_) {
          failed = true;
        }
      }),
    );
    if (mounted) {
      setState(() {
        _rounds = next;
        _statusError = failed ? '桌台状态加载失败' : null;
      });
    }
  }

  Future<void> _refreshLobby() async {
    final snapshot = await ref
        .read(preloadLoaderProvider)
        .load(onProgress: (_, _) {});
    if (!mounted) return;
    ref.read(lobbyPreloadProvider.notifier).replace(snapshot);

    final token = await ref.read(secureStorageProvider).getAuthToken();
    if (token != null && token.isNotEmpty) {
      await _loadRoundStatus(ref.read(apiClientProvider), token);
      await _loadMemberProfile();
    }
  }

  Future<void> _loadMemberProfile() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.getAuthToken();
    if (token == null || token.isEmpty) return;

    try {
      final response = await ref
          .read(apiClientProvider)
          .getJson('/user/profile', token: token);
      final data = response['data'];
      final profile = data is Map ? data['user'] : null;
      if (profile is! Map) {
        throw const FormatException('会员资料格式错误');
      }

      final account = profile['account']?.toString();
      final balance = profile['balance']?.toString();
      final trialValue = profile['trial_user_flg'];
      final trial =
          trialValue == true ||
          trialValue == 1 ||
          trialValue == '1' ||
          trialValue == 'true';
      if (account != null && account.isNotEmpty) {
        await storage.setAccount(account);
      }
      if (balance != null && balance.isNotEmpty) {
        await storage.setBalance(balance);
      }
      await storage.setTrialUser(trial);
      if (!mounted) return;
      setState(() {
        _account = account ?? _account;
        _balance = balance ?? _balance;
        _trial = trial;
        _profileError = null;
      });
    } on ApiException catch (error) {
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
      } else if (mounted) {
        setState(() => _profileError = error.message);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _profileError = error.message);
    } catch (_) {
      if (mounted) setState(() => _profileError = '会员资料加载失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(lobbyPreloadProvider);
    final games = _games(snapshot.games);
    final desks = _desks(snapshot.desks, games, _gameId, _rounds);
    final ticker = snapshot.setting('web_bet_announcement');
    final lobbyLoadFailed = snapshot.failures.any(
      (failure) =>
          failure == 'games' || failure == 'desks' || failure == 'settings',
    );

    return GoldenDarkBackground(
      child: Column(
        children: [
          LobbyDashboardHeader(
            account: _account,
            balance: _balance,
            onMenu: () => context.push(AppRoutes.settings),
          ),
          LobbyAnnouncementBanner(text: ticker),
          LobbyGameCategoryTabs(
            categories: games
                .map(
                  (game) => LobbyGameCategory(
                    id: game.id,
                    name: game.name,
                    type: game.type,
                  ),
                )
                .toList(growable: false),
            selectedId: _gameId,
            onSelected: (id) => setState(() => _gameId = id),
          ),
          if (_profileError != null)
            LobbyStateMessage(
              message: _profileError!,
              error: true,
              onRetry: () => _loadMemberProfile(),
            ),
          if (_statusError != null)
            LobbyStateMessage(
              message: _statusError!,
              error: true,
              onRetry: () => _refreshLobby(),
            ),
          if (lobbyLoadFailed && desks.isNotEmpty)
            LobbyStateMessage(
              message: '部分大厅数据加载失败，请重试',
              error: true,
              onRetry: () => _refreshLobby(),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshLobby,
              color: CasinoColors.gold,
              backgroundColor: const Color(0xFF211B12),
              child: desks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 100),
                        LobbyStateMessage(
                          message: lobbyLoadFailed
                              ? '大厅数据加载失败'
                              : games.isEmpty
                              ? '暂无游戏分类'
                              : '暂无可用台桌',
                          error: lobbyLoadFailed,
                          onRetry: lobbyLoadFailed ? _refreshLobby : null,
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: desks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final desk = desks[index];
                        return LobbyGameTableSection(
                          desk: _dashboardData(desk),
                          isTrial: _trial,
                          onEnter: () => showGoldDialog(
                            context: context,
                            kind: GoldDialogKind.info,
                            title: desk.name,
                            message: '投注将在下一阶段接入',
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  LobbyDeskDashboardData _dashboardData(_DeskItem desk) {
    final results = desk.resultKeys
        .map((key) => RoadmapResult(key: key))
        .toList(growable: false);
    final statistics = desk.baccarat
        ? [
            LobbyOutcomeStat(
              label: '庄',
              count: desk.count('banker'),
              color: RoadmapMarkerColor.red,
            ),
            LobbyOutcomeStat(
              label: '闲',
              count: desk.count('player'),
              color: RoadmapMarkerColor.blue,
            ),
            LobbyOutcomeStat(
              label: '和',
              count: desk.count('tie'),
              color: RoadmapMarkerColor.green,
            ),
          ]
        : [
            LobbyOutcomeStat(
              label: '龙',
              count: desk.count('dragon'),
              color: RoadmapMarkerColor.red,
            ),
            LobbyOutcomeStat(
              label: '虎',
              count: desk.count('tiger'),
              color: RoadmapMarkerColor.blue,
            ),
            LobbyOutcomeStat(
              label: '和',
              count: desk.count('tie'),
              color: RoadmapMarkerColor.green,
            ),
          ];
    return LobbyDeskDashboardData(
      id: desk.id,
      name: desk.name,
      gameName: desk.gameName,
      gameType: desk.gameType,
      status: desk.status,
      statusLabel: desk.statusLabel,
      minBet: desk.minBet,
      maxBet: desk.maxBet,
      resultCount: desk.resultCount,
      statistics: List.unmodifiable(statistics),
      markerRoad: calculateMarkerRoad(results),
      bigRoad: calculateBigRoad(results),
      bigEyeRoad: calculateBigEyeRoad(results),
      smallRoad: calculateSmallRoad(results),
      cockroachRoad: calculateCockroachRoad(results),
      secondBigRoad: calculateSecondBigRoad(results),
    );
  }
}

class _GameItem {
  const _GameItem({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
  });

  final int id;
  final String name;
  final String type;
  final int position;
}

class _DeskItem {
  const _DeskItem({
    required this.id,
    required this.name,
    required this.gameName,
    required this.gameType,
    required this.gamePosition,
    required this.position,
    required this.minBet,
    required this.maxBet,
    required this.resultCount,
    required this.resultKeys,
    required this.status,
    required this.statusLabel,
  });

  final int id;
  final String name;
  final String gameName;
  final String gameType;
  final int gamePosition;
  final int position;
  final int minBet;
  final int maxBet;
  final int resultCount;
  final List<String> resultKeys;
  final String? status;
  final String statusLabel;

  bool get baccarat => gameType.toUpperCase() == 'BACCARAT';

  int count(String outcome) =>
      resultKeys.where((key) => key.split('|').contains(outcome)).length;
}

List<_GameItem> _games(List<Map<String, dynamic>> raw) {
  final games = <_GameItem>[];
  for (final row in raw) {
    final type = row['type']?.toString() ?? '';
    if (type.toUpperCase() == 'NIUNIU') continue;
    final id = _asInt(row['id']);
    if (id == null) continue;
    games.add(
      _GameItem(
        id: id,
        name: row['name']?.toString() ?? '',
        type: type,
        position: _asInt(row['position']) ?? 1 << 20,
      ),
    );
  }
  games.sort((a, b) => a.position.compareTo(b.position));
  return games;
}

List<_DeskItem> _desks(
  List<Map<String, dynamic>> raw,
  List<_GameItem> games,
  int gameId,
  Map<int, _RoundLive> rounds,
) {
  final gameById = {for (final game in games) game.id: game};
  String? selectedType;
  if (gameId != 0) {
    selectedType = gameById[gameId]?.type;
  }
  final desks = <_DeskItem>[];
  for (final row in raw) {
    final game = row['game'];
    final gameMap = game is Map ? Map<String, dynamic>.from(game) : null;
    final type = gameMap?['type']?.toString() ?? '';
    if (selectedType != null && type != selectedType) continue;
    final gameIdValue = _asInt(row['game_id']);
    final known = gameIdValue == null ? null : gameById[gameIdValue];
    final results = row['results'];
    final resultKeys = results is List
        ? results
              .whereType<Map>()
              .map((result) => result['key']?.toString() ?? '')
              .where((key) => key.isNotEmpty)
              .toList()
        : <String>[];
    final id = _asInt(row['id']);
    if (id == null) continue;
    final lastRound = row['last_round'];
    final fallback = lastRound is Map ? lastRound['status']?.toString() : null;
    final live = rounds[id];
    final status = live?.status ?? fallback;
    desks.add(
      _DeskItem(
        id: id,
        name: row['name']?.toString() ?? '台桌',
        gameName: gameMap?['name']?.toString() ?? known?.name ?? '',
        gameType: type,
        gamePosition:
            _asInt(gameMap?['position']) ?? known?.position ?? 1 << 20,
        position: _asInt(row['position']) ?? 0,
        minBet: _asInt(row['min_bet']) ?? 0,
        maxBet: _asInt(row['max_bet']) ?? 0,
        resultCount: resultKeys.length,
        resultKeys: resultKeys,
        status: status,
        statusLabel: _statusLabel(status, live?.seconds ?? 0),
      ),
    );
  }
  desks.sort((a, b) {
    final byGame = a.gamePosition.compareTo(b.gamePosition);
    if (byGame != 0) return byGame;
    return a.position.compareTo(b.position);
  });
  return desks;
}

String _statusLabel(String? status, int seconds) {
  final label = switch (status) {
    'betting' => '开始下注',
    'dealing' => '停止下注',
    'finished' || 'active' => '等待开局',
    _ => '等待开局',
  };
  if (status == 'betting' && seconds > 0) return '$label $seconds';
  return label;
}

class _RoundLive {
  const _RoundLive({required this.status, required this.seconds});

  final String? status;
  final int seconds;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
