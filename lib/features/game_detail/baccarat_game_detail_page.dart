import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../auth/auth_service.dart';
import '../lobby/models/lobby_round_result.dart';
import '../lobby/realtime/lobby_socket_service.dart';
import '../preload/lobby_preload.dart';
import 'baccarat_detail_models.dart';
import 'baccarat_detail_repository.dart';
import 'baccarat_bet_validation.dart';
import 'camera_playback.dart';
import 'widgets/baccarat_betting_panel.dart';
import 'widgets/baccarat_roadmap_panel.dart';
import 'widgets/baccarat_video_panel.dart';

class BaccaratGameDetailPage extends ConsumerStatefulWidget {
  const BaccaratGameDetailPage({super.key, required this.deskId});

  final int deskId;

  @override
  ConsumerState<BaccaratGameDetailPage> createState() =>
      _BaccaratGameDetailPageState();
}

class _BaccaratGameDetailPageState extends ConsumerState<BaccaratGameDetailPage>
    with WidgetsBindingObserver {
  late final BaccaratDetailRepository _repository;
  late final LobbySocketService _socket;
  late final ApiClient _api;
  late final SecureStorage _storage;
  late int _deskId;
  String? _token;
  String? _csrfToken;
  BaccaratDeskDetail? _desk;
  List<BaccaratResultOption> _options = const [];
  BaccaratRoundStatus? _roundStatus;
  BaccaratConfirmedBets _confirmedBets = _emptyBets;
  BaccaratPoolTotals _poolTotals = BaccaratPoolTotals.empty;
  Map<int, BaccaratBetLimit> _memberLimits = const {};
  num _balance = 0;
  List<int> _chipDenominations = const [];
  List<int> _displayChipDenominations = const [];
  Map<int, num> _pendingBets = {};
  int? _selectedChip;
  int _cameraIndex = 0;
  bool _soundEnabled = true;
  bool _loading = true;
  bool _loadingBets = false;
  bool _submitting = false;
  bool _canceling = false;
  bool _betsLoaded = false;
  int _loadGeneration = 0;
  bool _hasSeenSocketConnection = false;
  bool _socketWasLost = false;
  bool _refreshingLiveData = false;
  String? _error;
  String? _socketError;
  String? _betsError;
  String? _poolError;
  String? _chipError;
  StreamSubscription<LobbyRoundResult>? _resultSubscription;
  StreamSubscription<LobbySocketStatus>? _statusSubscription;
  StreamSubscription<LobbyDeskUpdate>? _deskUpdateSubscription;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deskId = widget.deskId;
    _api = ref.read(apiClientProvider);
    _storage = ref.read(secureStorageProvider);
    _repository = BaccaratDetailRepository(_api);
    _socket = ref.read(lobbySocketServiceProvider);
    _resultSubscription = _socket.results.listen(_onResult);
    _statusSubscription = _socket.statuses.listen(_onSocketStatus);
    _deskUpdateSubscription = _socket.deskUpdates.listen(_onDeskUpdate);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    unawaited(_loadChipDenominations());
    unawaited(_loadDetail());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    unawaited(_resultSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_deskUpdateSubscription?.cancel());
    unawaited(_setRoom('home'));
    super.dispose();
  }

  Future<void> _loadDetail({
    bool showLoading = true,
    bool preservePending = false,
  }) async {
    final generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _betsError = null;
        _poolError = null;
      });
    }

    try {
      final token = await _storage.getAuthToken();
      final csrfToken = await _storage.getCsrfToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = '登录状态已失效，请重新登录';
          });
        }
        return;
      }

      final loaded = await Future.wait<Object>([
        _repository.getDesk(_deskId, token),
        _repository.getResultOptions(_deskId, token),
        _repository.getRoundStatus(_deskId, token),
        _repository.getProfile(token),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      final desk = loaded[0] as BaccaratDeskDetail;
      final options = loaded[1] as List<BaccaratResultOption>;
      final status = loaded[2] as BaccaratRoundStatus;
      final profile = loaded[3] as BaccaratMemberProfile;
      final previousRoundId = _desk?.lastRoundId;
      if (!mounted) return;

      setState(() {
        _token = token;
        _csrfToken = csrfToken;
        _desk = desk;
        _options = options;
        _roundStatus = status;
        _balance = profile.balance;
        _memberLimits = profile.resultRateLimits;
        _loading = false;
        _betsLoaded = false;
        if (previousRoundId != desk.lastRoundId) {
          _confirmedBets = _emptyBets;
          _poolTotals = BaccaratPoolTotals.empty;
        }
        if (!preservePending || previousRoundId != desk.lastRoundId) {
          _pendingBets = {};
        }
        _cameraIndex = 0;
      });
      ref
          .read(lobbyPreloadProvider.notifier)
          .synchronizeDeskResults(
            histories: {_deskId: desk.results},
            sessionIds: {_deskId: desk.sessionId},
          );
      unawaited(_setRoom('$_deskId'));
      _connectSharedSocket(token);
      await _loadOpenRoundAmounts(
        token,
        desk.lastRoundId,
        generation: generation,
      );
    } on ApiException catch (error) {
      if (generation != _loadGeneration) return;
      if (!await _handleAuthError(error)) _showLoadError(error.message);
    } on FormatException catch (error) {
      if (generation != _loadGeneration) return;
      _showLoadError(error.message);
    } on TimeoutException {
      if (generation != _loadGeneration) return;
      _showLoadError('加载桌台信息超时');
    } on http.ClientException {
      if (generation != _loadGeneration) return;
      _showLoadError('无法连接服务器，请稍后重试');
    }
  }

  Future<void> _loadOpenRoundAmounts(
    String token,
    int? roundId, {
    int? generation,
  }) async {
    final activeGeneration = generation ?? _loadGeneration;
    if (!mounted || activeGeneration != _loadGeneration) return;
    setState(() => _loadingBets = true);
    try {
      final confirmed = await _repository.getConfirmedBets(roundId, token);
      if (!mounted || activeGeneration != _loadGeneration) return;
      setState(() {
        _confirmedBets = confirmed;
        _betsLoaded = true;
        _betsError = null;
      });
    } on ApiException catch (error) {
      if (activeGeneration == _loadGeneration &&
          !await _handleAuthError(error) &&
          mounted) {
        setState(() => _betsError = error.message);
      }
    } on FormatException catch (error) {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _betsError = error.message);
      }
    } on TimeoutException {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _betsError = '读取本局投注超时');
      }
    } on http.ClientException {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _betsError = '无法读取本局投注');
      }
    } finally {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _loadingBets = false);
      }
    }

    try {
      final totals = await _repository.getPoolTotals(roundId, token);
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() {
          _poolTotals = totals;
          _poolError = null;
        });
      }
    } on ApiException catch (error) {
      if (activeGeneration == _loadGeneration &&
          !await _handleAuthError(error) &&
          mounted) {
        setState(() => _poolError = error.message);
      }
    } on FormatException catch (error) {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _poolError = error.message);
      }
    } on TimeoutException {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _poolError = '读取台面投注汇总超时');
      }
    } on http.ClientException {
      if (mounted && activeGeneration == _loadGeneration) {
        setState(() => _poolError = '无法读取台面投注汇总');
      }
    }
  }

  void _connectSharedSocket(String token) {
    final snapshot = ref.read(lobbyPreloadProvider);
    final deskIds = <int>{_deskId};
    final gamesById = {
      for (final game in snapshot.games)
        if (_asInt(game['id']) != null)
          _asInt(game['id'])!: game['type']?.toString().toUpperCase(),
    };
    for (final desk in snapshot.desks) {
      final id = _asInt(desk['id']);
      final game = desk['game'];
      final gameType = game is Map
          ? game['type']?.toString().toUpperCase()
          : gamesById[_asInt(desk['game_id'])];
      if (id != null && gameType == 'BACCARAT') deskIds.add(id);
    }
    _socket.connect(token: token, deskIds: deskIds);
  }

  void _onResult(LobbyRoundResult result) {
    if (!mounted) return;
    const baccaratResultKeys = {
      'banker',
      'player',
      'tie',
      'bankerPair',
      'playerPair',
    };
    final resultKeys = result.key.split('|');
    if (resultKeys.any((key) => !baccaratResultKeys.contains(key)) ||
        !resultKeys.any(
          (key) => const {'banker', 'player', 'tie'}.contains(key),
        )) {
      debugPrint(
        '[BaccaratDetail] ignoring invalid result '
        'deskId=${result.deskId} roundId=${result.roundId}',
      );
      return;
    }
    if (result.deskId == _deskId &&
        (_desk?.results.any(
              (existing) =>
                  existing.roundId == result.roundId &&
                  existing.key == result.key,
            ) ??
            false)) {
      return;
    }
    ref.read(lobbyPreloadProvider.notifier).upsertResult(result);
    if (result.deskId != _deskId) return;
    setState(() {
      if (_desk != null) {
        _desk = BaccaratDeskDetail(
          id: _desk!.id,
          gameId: _desk!.gameId,
          name: _desk!.name,
          gameName: _desk!.gameName,
          minBet: _desk!.minBet,
          maxBet: _desk!.maxBet,
          sessionId: _desk!.sessionId,
          lastRoundId: _desk!.lastRoundId,
          lastRoundNo: _desk!.lastRoundNo,
          singleCamera: _desk!.singleCamera,
          rateLimitEnabled: _desk!.rateLimitEnabled,
          deskResultRateLimits: _desk!.deskResultRateLimits,
          results: mergeLobbyRoundResults(_desk!.results, [result]),
        );
      }
    });
  }

  void _onSocketStatus(LobbySocketStatus status) {
    if (!mounted) return;
    setState(() => _socketError = status.connected ? null : status.error);
    if (status.connected) {
      if (_hasSeenSocketConnection && _socketWasLost) {
        _socketWasLost = false;
        unawaited(_refreshLiveData());
      }
      _hasSeenSocketConnection = true;
    } else if (_hasSeenSocketConnection) {
      _socketWasLost = true;
    }
  }

  void _onDeskUpdate(LobbyDeskUpdate update) {
    if (!mounted || update.deskId != _deskId) return;
    if (update is LobbyDeskTimerUpdate) {
      final current = _roundStatus;
      if (current != null) {
        setState(
          () => _roundStatus = BaccaratRoundStatus(
            status: current.status,
            remainingSeconds: update.remainingSeconds.clamp(0, 3600),
          ),
        );
      }
    } else if (update is LobbyDeskStatusUpdate) {
      final current = _roundStatus;
      if (current != null) {
        setState(
          () => _roundStatus = BaccaratRoundStatus(
            status: update.status,
            remainingSeconds: update.status == 'betting'
                ? current.remainingSeconds
                : 0,
          ),
        );
      }
    } else if (update is LobbyDeskPoolTotalsUpdate) {
      if (_desk?.lastRoundId == update.roundId) {
        setState(() {
          _poolTotals = BaccaratPoolTotals.fromSocket(update);
          _poolError = null;
        });
      }
    } else if (update is LobbyDeskSessionFinished) {
      unawaited(_loadDetail(showLoading: false));
    }
  }

  void _tickCountdown() {
    final status = _roundStatus;
    if (!mounted || status == null || !status.isBetting) return;
    if (status.remainingSeconds <= 0) return;
    setState(
      () => _roundStatus = BaccaratRoundStatus(
        status: status.status,
        remainingSeconds: status.remainingSeconds - 1,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _token == null) return;
    if (!_socket.connected) _connectSharedSocket(_token!);
    unawaited(_refreshLiveData());
  }

  Future<void> _refreshLiveData() async {
    if (!mounted || _refreshingLiveData || _token == null) return;
    _refreshingLiveData = true;
    try {
      await _loadDetail(showLoading: false, preservePending: true);
    } finally {
      _refreshingLiveData = false;
    }
  }

  Future<void> _setRoom(String room) async {
    final token = _token ?? await _storage.getAuthToken();
    if (token == null || token.isEmpty) return;
    final csrf = _csrfToken ?? await _storage.getCsrfToken();
    try {
      await _api.patchJson(
        AppConstants.roomPath,
        token: token,
        csrfToken: csrf,
        body: {'room': room},
      );
    } on ApiException catch (error) {
      debugPrint('[BaccaratDetail] room update failed: ${error.message}');
    } on TimeoutException catch (error) {
      debugPrint('[BaccaratDetail] room update timed out: $error');
    } on http.ClientException catch (error) {
      debugPrint('[BaccaratDetail] room update failed: $error');
    }
  }

  void _showLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<bool> _handleAuthError(ApiException error) async {
    if (error.code != 'SESSION_SUPERSEDED' &&
        error.statusCode != 401 &&
        error.statusCode != 403) {
      return false;
    }
    await ref.read(authServiceProvider).logout();
    if (mounted) context.go(AppRoutes.login);
    return true;
  }

  List<LobbyRoundResult> _resultsForDesk(List<Map<String, dynamic>> desks) {
    final row = desks
        .where((desk) => _asInt(desk['id']) == _deskId)
        .firstOrNull;
    final rawResults = row?['results'];
    if (rawResults is List) {
      try {
        return List.unmodifiable(
          rawResults.map((item) => LobbyRoundResult.fromApi(_deskId, item)),
        );
      } on FormatException {
        return _desk?.results ?? const [];
      }
    }
    return _desk?.results ?? const [];
  }

  List<BaccaratCameraFeed> _camerasForDesk(
    List<Map<String, dynamic>> cameras,
    BaccaratDeskDetail desk,
  ) {
    final feeds = <BaccaratCameraFeed>[];
    for (final camera in cameras) {
      if (_asInt(camera['desk_id']) != desk.id) continue;
      try {
        feeds.add(BaccaratCameraFeed.fromJson(camera));
      } on FormatException catch (error) {
        debugPrint('[BaccaratDetail] ignoring invalid camera row: $error');
      }
    }
    feeds.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.cameraId.compareTo(b.cameraId);
    });
    if (desk.singleCamera && feeds.length > 1) return [feeds.first];
    return feeds;
  }

  List<Map<String, dynamic>> _availableBaccaratDesks(LobbySnapshot snapshot) {
    final gamesById = {
      for (final game in snapshot.games)
        if (_asInt(game['id']) != null)
          _asInt(game['id'])!: game['type']?.toString().toUpperCase(),
    };
    return snapshot.desks
        .where((desk) {
          final game = desk['game'];
          final type = game is Map
              ? game['type']?.toString().toUpperCase()
              : gamesById[_asInt(desk['game_id'])];
          return type == 'BACCARAT' && _asInt(desk['id']) != null;
        })
        .toList(growable: false);
  }

  Future<void> _showTablePicker(List<Map<String, dynamic>> desks) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF132437),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '切换台桌',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final desk in desks)
              ListTile(
                title: Text(desk['name']?.toString() ?? '台桌'),
                subtitle: Text(
                  '限红 ${desk['min_bet'] ?? '-'}-${desk['max_bet'] ?? '-'}',
                ),
                trailing: _asInt(desk['id']) == _deskId
                    ? const Icon(Icons.check, color: Color(0xFF55D88B))
                    : null,
                onTap: () => Navigator.pop(context, desk),
              ),
          ],
        ),
      ),
    );
    final id = _asInt(selected?['id']);
    if (id == null || id == _deskId) return;
    setState(() {
      _deskId = id;
      _desk = null;
      _options = const [];
      _roundStatus = null;
      _confirmedBets = _emptyBets;
      _poolTotals = BaccaratPoolTotals.empty;
      _pendingBets = {};
      _betsLoaded = false;
    });
    await _loadDetail();
  }

  void _placeBet(BaccaratResultOption option) {
    final selectedChip = _selectedChip;
    if (!_bettingOpen || selectedChip == null) return;
    setState(() {
      _pendingBets = Map.of(_pendingBets)
        ..update(
          option.id,
          (amount) => amount + selectedChip,
          ifAbsent: () => selectedChip,
        );
    });
  }

  Future<void> _loadChipDenominations() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final denominations =
          manifest
              .listAssets()
              .map(
                (asset) =>
                    RegExp(r'^assets/images/coins/(\d+)chip\.png$')
                        .firstMatch(asset),
              )
              .whereType<RegExpMatch>()
              .map((match) => int.parse(match.group(1)!))
              .toSet()
              .toList()
            ..sort();
      if (denominations.isEmpty) {
        throw const FormatException('筹码图片目录中没有有效的筹码资源');
      }
      if (!mounted) return;
      setState(() {
        final displayed = _websiteDefaultChipValues
            .where(denominations.contains)
            .toList(growable: false);
        if (displayed.isEmpty) {
          throw const FormatException('筹码资源与网站默认筹码配置不匹配');
        }
        _chipDenominations = List.unmodifiable(denominations);
        _displayChipDenominations = List.unmodifiable(displayed);
        _selectedChip = displayed.first;
        _chipError = null;
      });
    } on FormatException catch (error) {
      debugPrint('[BaccaratDetail] chip assets invalid: ${error.message}');
      if (mounted) setState(() => _chipError = error.message);
    } on FlutterError catch (error) {
      debugPrint('[BaccaratDetail] failed to load chip assets: $error');
      if (mounted) setState(() => _chipError = '筹码图片资源加载失败');
    }
  }

  Future<void> _submitBets() async {
    final desk = _desk;
    final token = _token;
    final lastRoundId = desk?.lastRoundId;
    if (_submitting ||
        _canceling ||
        !_bettingOpen ||
        !_betsLoaded ||
        desk == null ||
        token == null ||
        lastRoundId == null ||
        _pendingBets.isEmpty) {
      return;
    }

    final validationError = validateBaccaratBetBatch(
      desk: desk,
      options: _options,
      confirmedBets: _confirmedBets.byResultKey,
      pendingBets: _pendingBets,
      memberLimits: _memberLimits,
      roundPoolTotals: _poolTotals.totals,
      roundPoolTotalsAvailable: _poolTotals.roundId == lastRoundId,
      balance: _balance,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    final csrf = _csrfToken ?? '';
    setState(() => _submitting = true);
    try {
      final bets = _options
          .where((option) => (_pendingBets[option.id] ?? 0) > 0)
          .map((option) {
            final cumulative =
                (option.key.isNotEmpty
                    ? _confirmedBets.byResultKey[option.key]?.amount ?? 0
                    : 0) +
                (_pendingBets[option.id] ?? 0);
            return BaccaratBetSubmissionItem(
              resultId: option.id,
              amount: _pendingBets[option.id]!,
              image: baccaratCoinImageForAmount(cumulative, _chipDenominations),
            );
          })
          .toList(growable: false);
      final result = await _repository.submitBets(
        lastRoundId: lastRoundId,
        bets: bets,
        token: token,
        csrfToken: csrf,
      );
      if (!mounted) return;
      setState(() {
        _confirmedBets = result.confirmedBets;
        _balance = result.remainingBalance;
        _pendingBets = {};
      });
      await _storage.setBalance(result.remainingBalance.toString());
      _showMessage('下注成功');
    } on ApiException catch (error) {
      if (!await _handleAuthError(error)) _showMessage(error.message);
    } on BaccaratActionException catch (error) {
      _showMessage(error.message);
    } on FormatException catch (error) {
      _showMessage(error.message);
    } on TimeoutException {
      _showMessage('下注请求超时，请刷新确认投注状态');
    } on http.ClientException {
      _showMessage('无法连接服务器，请刷新确认投注状态');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelBets() async {
    if (_submitting || _canceling) return;
    if (_pendingBets.isNotEmpty) {
      setState(() => _pendingBets = {});
      return;
    }
    final desk = _desk;
    final token = _token;
    final roundId = desk?.lastRoundId;
    if (!_canCancel || desk == null || token == null || roundId == null) return;
    setState(() => _canceling = true);
    try {
      await _repository.cancelBets(
        lastRoundId: roundId,
        token: token,
        csrfToken: _csrfToken ?? '',
      );
      final results = await Future.wait<Object>([
        _repository.getConfirmedBets(roundId, token),
        _repository.getProfile(token),
      ]);
      if (!mounted) return;
      setState(() {
        _confirmedBets = results[0] as BaccaratConfirmedBets;
        final profile = results[1] as BaccaratMemberProfile;
        _balance = profile.balance;
        _memberLimits = profile.resultRateLimits;
      });
      await _storage.setBalance(_balance.toString());
      _showMessage('已取消投注');
    } on ApiException catch (error) {
      if (!await _handleAuthError(error)) _showMessage(error.message);
    } on BaccaratActionException catch (error) {
      _showMessage(error.message);
    } on FormatException catch (error) {
      _showMessage(error.message);
    } on TimeoutException {
      _showMessage('取消投注请求超时，请刷新确认投注状态');
    } on http.ClientException {
      _showMessage('无法连接服务器，请刷新确认投注状态');
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  Future<void> _showBettingHistory() async {
    final token = _token;
    if (token == null) return;
    final future = _repository.getLedger(token: token, date: DateTime.now());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A27),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '下注记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<BaccaratLedgerEntry>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('加载投注记录失败：${_errorText(snapshot.error!)}'),
                      );
                    }
                    final entries = snapshot.data ?? const [];
                    if (entries.isEmpty) {
                      return const Center(child: Text('暂无投注记录'));
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFF344A5F)),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(
                            '${entry.deskName}  ${entry.result}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(entry.createdAt),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('投注 ${_formatAmount(entry.amount)}'),
                              if (entry.remainingAmount != null)
                                Text(
                                  '余额 ${_formatAmount(entry.remainingAmount!)}',
                                  style: const TextStyle(
                                    color: Color(0xFF9BB2C3),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomerServiceInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('在线客服'),
        content: const Text('参考网站的客服消息仅保存在浏览器本地；现有后端没有移动端客服消息接口。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leaveDetail() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.lobby);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(lobbyPreloadProvider);
    final desk = _desk;
    if (_loading && desk == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF091728),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (desk == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF091728),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? '桌台信息暂不可用', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => unawaited(_loadDetail()),
                    child: const Text('重试'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_leaveDetail()),
                    child: const Text('返回大厅'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final results = _resultsForDesk(snapshot.desks);
    final cameras = _camerasForDesk(snapshot.cameras, desk);
    final camera = cameras.isEmpty
        ? null
        : cameras[_cameraIndex.clamp(0, cameras.length - 1)];
    final streamUri = camera == null
        ? null
        : proxyHlsCameraUri(
            apiBaseUrl: AppConstants.apiBaseUrl,
            camera: camera,
          );
    final availableDesks = _availableBaccaratDesks(snapshot);
    final status = _roundStatus;
    final bettingOpen = _bettingOpen;
    return Scaffold(
      backgroundColor: const Color(0xFF091728),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            BaccaratVideoPanel(
              deskName: '${desk.gameName} ${desk.name}',
              roundLabel: '第 ${desk.lastRoundNo ?? desk.lastRoundId ?? '-'} 局',
              status: status?.status ?? 'active',
              remainingSeconds: status?.remainingSeconds ?? 0,
              ticker: snapshot.setting('web_bet_announcement'),
              streamUri: streamUri,
              cameraLabel: camera == null
                  ? ''
                  : '${camera.cameraNumber.isEmpty ? _cameraIndex + 1 : camera.cameraNumber}'
                        '/${cameras.length}',
              cameraCount: cameras.length,
              onBack: () => unawaited(_leaveDetail()),
              onSwitchTable: () => unawaited(_showTablePicker(availableDesks)),
              onSwitchCamera: () {
                if (cameras.length < 2) return;
                setState(
                  () => _cameraIndex = (_cameraIndex + 1) % cameras.length,
                );
              },
              soundEnabled: _soundEnabled,
              onSoundChanged: (enabled) =>
                  setState(() => _soundEnabled = enabled),
            ),
            if (_error != null)
              _MessageBanner(message: _error!, onRetry: () => _loadDetail()),
            if (_socketError != null)
              _MessageBanner(
                message: '实时连接异常：$_socketError',
                onRetry: () => _token == null
                    ? _loadDetail()
                    : _connectSharedSocket(_token!),
              ),
            if (_betsError != null)
              _MessageBanner(
                message: '当前投注状态读取失败：$_betsError',
                onRetry: () => _token == null
                    ? _loadDetail()
                    : _loadOpenRoundAmounts(_token!, desk.lastRoundId),
              ),
            if (_poolError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  '台面投注汇总暂不可用：$_poolError',
                  style: const TextStyle(
                    color: Color(0xFFFFB8A8),
                    fontSize: 11,
                  ),
                ),
              ),
            if (_chipError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _chipError!,
                  style: const TextStyle(
                    color: Color(0xFFFFB8A8),
                    fontSize: 11,
                  ),
                ),
              ),
            BaccaratBettingPanel(
              options: _options,
              confirmedBets: _confirmedBets.byResultKey,
              confirmedTotalAmount: _confirmedBets.totalAmount,
              pendingBets: _pendingBets,
              chipDenominations: _displayChipDenominations,
              poolTotals: _poolTotals.displayTotals.isEmpty
                  ? _poolTotals.totals
                  : _poolTotals.displayTotals,
              selectedChip: _selectedChip,
              balance: _balance,
              minBet: desk.minBet,
              maxBet: desk.maxBet,
              bettingOpen:
                  bettingOpen &&
                  _betsLoaded &&
                  _betsError == null &&
                  !_loadingBets,
              secondsRemaining: status?.remainingSeconds ?? 0,
              submitting: _submitting,
              canceling: _canceling,
              onSelectChip: (chip) => setState(() => _selectedChip = chip),
              onPlaceBet: _placeBet,
              onSubmit: () => unawaited(_submitBets()),
              onCancel: () => unawaited(_cancelBets()),
              onHistory: () => unawaited(_showBettingHistory()),
              onCustomerService: () => unawaited(_showCustomerServiceInfo()),
            ),
            BaccaratRoadmapPanel(results: results),
          ],
        ),
      ),
    );
  }

  bool get _bettingOpen =>
      _roundStatus?.isBetting == true &&
      (_roundStatus?.remainingSeconds ?? 0) > 0;

  bool get _canCancel =>
      _bettingOpen && (_roundStatus?.remainingSeconds ?? 0) > 5;
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF582E2A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

const _emptyBets = BaccaratConfirmedBets(byResultKey: {}, totalAmount: 0);

const _websiteDefaultChipValues = [100, 1000, 5000, 10000, 50000];

String baccaratCoinImageForAmount(num amount, List<int> denominations) {
  if (denominations.isEmpty) {
    throw StateError('No chip image assets are available');
  }
  var nearest = denominations.first;
  for (final denomination in denominations) {
    if (denomination > amount) break;
    nearest = denomination;
  }
  if (nearest == 100000) nearest = 50000;
  return '/images/coins/${nearest}chip.png';
}

String _formatAmount(num amount) =>
    amount == amount.roundToDouble() ? amount.toInt().toString() : '$amount';

String _errorText(Object error) {
  if (error is ApiException) return error.message;
  if (error is FormatException) return error.message;
  if (error is TimeoutException) return '请求超时';
  if (error is http.ClientException) return '网络请求失败';
  return error.toString();
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
