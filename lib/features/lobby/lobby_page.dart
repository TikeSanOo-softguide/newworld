import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../auth/auth_service.dart';
import 'models/lobby_dashboard_data.dart';
import 'models/lobby_round_result.dart';
import 'roadmap/roadmap_calculations.dart';
import 'roadmap/roadmap_models.dart';
import 'realtime/lobby_socket_service.dart';
import 'widgets/lobby_dashboard_widgets.dart';
import '../preload/lobby_preload.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key, this.showNotice = false});

  final bool showNotice;

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage>
    with WidgetsBindingObserver {
  String _account = '';
  String _balance = '0';
  bool _trial = false;
  int _gameId = 0;
  bool _noticeShown = false;
  bool _kicking = false;
  String? _profileError;
  String? _statusError;
  String? _realtimeError;
  Map<int, _RoundLive> _rounds = {};
  late final LobbySocketService _lobbySocket;
  StreamSubscription<LobbyRoundResult>? _resultSubscription;
  StreamSubscription<LobbySocketStatus>? _socketStatusSubscription;
  StreamSubscription<String>? _protocolErrorSubscription;
  bool _syncingResults = false;
  bool _resyncRequested = false;
  bool _checkingSocketAuth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lobbySocket = ref.read(lobbySocketServiceProvider);
    _resultSubscription = _lobbySocket.results.listen((result) {
      if (!mounted) return;
      ref.read(lobbyPreloadProvider.notifier).upsertResult(result);
    });
    _socketStatusSubscription = _lobbySocket.statuses.listen((status) {
      if (!mounted) return;
      if (status.connected) {
        debugPrint('[LobbySocket] lobby connected; synchronizing desk history');
        setState(() => _realtimeError = null);
        unawaited(_synchronizeDeskResults());
      } else if (status.error != null) {
        debugPrint(
          '[LobbySocket] lobby disconnected '
          'authenticationRejected=${status.authenticationFailed} '
          'error=${status.error}',
        );
        setState(() => _realtimeError = '实时连接失败：${status.error}，正在尝试重新连接');
        if (status.authenticationFailed) {
          unawaited(_verifySocketAuthentication());
        }
      }
    });
    _protocolErrorSubscription = _lobbySocket.protocolErrors.listen((_) {
      if (mounted) {
        setState(() => _realtimeError = '收到无效的实时桌台结果');
      }
    });
    _loadMember();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lobbySocket.disconnect(resetSession: false);
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_connectLobbySocket());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lobbySocket.disconnect(resetSession: false);
    unawaited(_resultSubscription?.cancel());
    unawaited(_socketStatusSubscription?.cancel());
    unawaited(_protocolErrorSubscription?.cancel());
    super.dispose();
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
    await _connectLobbySocket();
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

  Future<void> _connectLobbySocket() async {
    final token = await ref.read(secureStorageProvider).getAuthToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      debugPrint('[LobbySocket] not connecting: no stored auth token');
      return;
    }
    final snapshot = ref.read(lobbyPreloadProvider);
    final games = _games(snapshot.games);
    final gameById = {for (final game in games) game.id: game};
    final deskIds = <int>[];
    for (final desk in snapshot.desks) {
      final id = _asInt(desk['id']);
      final gameId = _asInt(desk['game_id']);
      final game = desk['game'];
      final gameMap = game is Map ? game : null;
      final type = gameMap?['type']?.toString() ?? gameById[gameId]?.type ?? '';
      if (id != null && type.toUpperCase() == 'BACCARAT') {
        deskIds.add(id);
      }
    }
    debugPrint(
      '[LobbySocket] lobby connect requested '
      'baccaratDeskCount=${deskIds.length}',
    );
    _lobbySocket.connect(token: token, deskIds: deskIds);
  }

  Future<void> _synchronizeDeskResults() async {
    if (_syncingResults) {
      _resyncRequested = true;
      return;
    }
    _syncingResults = true;
    try {
      final storage = ref.read(secureStorageProvider);
      final token = await storage.getAuthToken();
      if (token == null || token.isEmpty) return;
      final response = await ref
          .read(apiClientProvider)
          .getJson(
            '/user/desks',
            query: const {'site_name': 'user'},
            token: token,
          );
      final data = response['data'];
      final rawDesks = data is Map ? data['desks'] : null;
      if (rawDesks is! List) {
        throw const FormatException('桌台同步响应缺少 desks 列表');
      }

      final histories = <int, List<LobbyRoundResult>>{};
      final sessionIds = <int, int?>{};
      for (final rawDesk in rawDesks) {
        if (rawDesk is! Map) {
          throw const FormatException('桌台同步响应包含无效桌台');
        }
        final deskId = _asInt(rawDesk['id']);
        if (deskId == null) {
          throw const FormatException('桌台同步响应缺少桌台 ID');
        }
        final rawResults = rawDesk['results'];
        if (rawResults is! List) {
          throw FormatException('桌台 $deskId 的 results 不是列表');
        }
        histories[deskId] = rawResults
            .map((result) => LobbyRoundResult.fromApi(deskId, result))
            .toList(growable: false);
        final session = rawDesk['session'];
        sessionIds[deskId] = session is Map ? _asInt(session['id']) : null;
      }
      if (!mounted) return;
      debugPrint(
        '[LobbySocket] desk history synchronized '
        'deskCount=${histories.length} '
        'resultCount=${histories.values.fold<int>(0, (sum, rows) => sum + rows.length)}',
      );
      ref
          .read(lobbyPreloadProvider.notifier)
          .synchronizeDeskResults(histories: histories, sessionIds: sessionIds);
    } on ApiException catch (error) {
      debugPrint(
        '[LobbySocket] desk history API failed '
        'status=${error.statusCode} code=${error.code} message=${error.message}',
      );
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
      } else if (error.statusCode == 401 || error.statusCode == 403) {
        await ref.read(authServiceProvider).logout();
        if (mounted) context.go(AppRoutes.login);
      } else if (mounted) {
        setState(() => _realtimeError = '桌台结果同步失败');
      }
    } on FormatException catch (error) {
      debugPrint('[LobbySocket] invalid desk history response: $error');
      if (mounted) setState(() => _realtimeError = '桌台结果同步失败');
    } on TimeoutException catch (error) {
      debugPrint(
        '[LobbySocket] desk history synchronization timed out: $error',
      );
      if (mounted) setState(() => _realtimeError = '桌台结果同步超时');
    } on http.ClientException catch (error) {
      debugPrint('[LobbySocket] desk history synchronization failed: $error');
      if (mounted) setState(() => _realtimeError = '无法连接服务器以同步桌台结果');
    } finally {
      _syncingResults = false;
      if (_resyncRequested && mounted) {
        _resyncRequested = false;
        unawaited(_synchronizeDeskResults());
      }
    }
  }

  Future<void> _verifySocketAuthentication() async {
    if (_checkingSocketAuth) return;
    _checkingSocketAuth = true;
    try {
      final token = await ref.read(secureStorageProvider).getAuthToken();
      if (token == null || token.isEmpty) {
        await ref.read(authServiceProvider).logout();
        if (mounted) context.go(AppRoutes.login);
        return;
      }
      await ref
          .read(apiClientProvider)
          .getJson(AppConstants.verifyPath, token: token);
      if (mounted) {
        setState(() => _realtimeError = '实时连接身份验证失败，请重新登录');
      }
    } on ApiException catch (error) {
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
      } else if (error.statusCode == 401 || error.statusCode == 403) {
        await ref.read(authServiceProvider).logout();
        if (mounted) context.go(AppRoutes.login);
      } else if (mounted) {
        setState(() => _realtimeError = '无法验证实时连接，请稍后重试');
      }
    } on TimeoutException catch (error) {
      debugPrint('Socket authentication verification timed out: $error');
      if (mounted) setState(() => _realtimeError = '实时连接身份验证超时');
    } on http.ClientException catch (error) {
      debugPrint('Socket authentication verification failed: $error');
      if (mounted) setState(() => _realtimeError = '无法验证实时连接');
    } finally {
      _checkingSocketAuth = false;
    }
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
    await _connectLobbySocket();
    if (!mounted) return;

    final token = await ref.read(secureStorageProvider).getAuthToken();
    if (token != null && token.isNotEmpty) {
      await _loadRoundStatus(ref.read(apiClientProvider), token);
      await _loadMemberProfile();
    }
  }

  Future<void> _openBaccaratDesk(int deskId) async {
    await context.pushNamed<void>(
      'baccaratDetail',
      pathParameters: {'deskId': '$deskId'},
    );
    if (mounted) await _loadMemberProfile();
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
          if (_realtimeError != null)
            LobbyStateMessage(
              message: _realtimeError!,
              error: true,
              onRetry: () => _connectLobbySocket(),
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
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: desks.length,
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (context, index) {
                        final desk = desks[index];
                        return LobbyGameTableSection(
                          desk: _dashboardData(desk),
                          isTrial: _trial,
                          onEnter: () {
                            if (desk.baccarat) {
                              unawaited(_openBaccaratDesk(desk.id));
                            } else {
                              showGoldDialog(
                                context: context,
                                kind: GoldDialogKind.info,
                                title: desk.name,
                                message: '该游戏暂不支持移动端牌桌',
                              );
                            }
                          },
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
    final results = desk.results
        .map((result) => RoadmapResult(key: result.key))
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
    required this.results,
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
  final List<LobbyRoundResult> results;
  final String? status;
  final String statusLabel;

  List<String> get resultKeys =>
      results.map((result) => result.key).toList(growable: false);

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
    final id = _asInt(row['id']);
    if (id == null) continue;
    final results = row['results'];
    final roundResults = <LobbyRoundResult>[];
    if (results is List) {
      for (final result in results) {
        try {
          roundResults.add(LobbyRoundResult.fromApi(id, result));
        } on FormatException catch (error) {
          debugPrint('Ignoring malformed result for desk $id: $error');
        }
      }
    }
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
        resultCount: roundResults.length,
        results: List.unmodifiable(roundResults),
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
