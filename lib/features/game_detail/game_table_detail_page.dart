import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../auth/auth_service.dart';
import '../lobby/lobby_repository.dart';
import '../lobby/models/lobby_round_result.dart';
import '../lobby/realtime/desk_betting_clock.dart';
import '../lobby/realtime/live_table_events.dart';
import '../lobby/realtime/lobby_socket_service.dart';
import 'desk_result_indicators.dart';
import 'detail_status_notice.dart';
import 'detail_sync_buffer.dart';
import 'detail_amount_format.dart';
import 'round_badge.dart';
import '../preload/lobby_preload.dart';
import 'baccarat_detail_models.dart';
import 'game_table_profile.dart';
import 'selected_chip.dart';
import 'baccarat_detail_repository.dart';
import 'repeat_bet.dart';
import 'baccarat_bet_validation.dart';
import 'camera_playback.dart';
import 'camera_views.dart';
import 'detail_orientation.dart';
import 'whep_playback.dart';
import 'voice_announcement.dart';
import 'voice_playback.dart';
import 'widgets/baccarat_betting_panel.dart';
import 'widgets/baccarat_roadmap_panel.dart';
import 'widgets/cross_desk_result_overlay.dart';
import 'widgets/table_switch_panel.dart';
import 'widgets/baccarat_video_panel.dart';

const _settlementAttempts = 3;
const _settlementRetryDelay = Duration(milliseconds: 400);

class _SettlementWait {
  _SettlementWait(Duration delay) {
    timer = Timer(delay, complete);
  }

  late final Timer timer;
  final completer = Completer<void>();

  void complete() {
    if (!completer.isCompleted) completer.complete();
  }

  void cancel() {
    timer.cancel();
    complete();
  }
}

class GameTableDetailPage extends ConsumerStatefulWidget {
  const GameTableDetailPage({super.key, required this.deskId});

  final int deskId;

  @override
  ConsumerState<GameTableDetailPage> createState() =>
      _GameTableDetailPageState();
}

class _GameTableDetailPageState extends ConsumerState<GameTableDetailPage>
    with WidgetsBindingObserver {
  GameTableProfile get _gameProfile {
    final type = _desk?.gameType;
    if (type == null) return GameTableProfile.baccarat;
    return GameTableProfile.forType(type);
  }

  late final BaccaratDetailRepository _repository;
  late final LobbySocketService _socket;
  late final ApiClient _api;
  late final LobbyRepository _lobby;
  late final MemberWhepPlayback _whep;
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
  int? _pendingRoundId;
  bool _repeating = false;
  final Map<int, _StakeMemory> _stakeMemory = {};
  bool _cameraMenuOpen = false;
  DeskCameraView _cameraView = DeskCameraView.fullTable;
  bool _videoFullscreen = false;
  bool _landscapeVideo = false;
  bool _tablePanelOpen = false;
  int? _switchingDeskId;
  String? _switchingLabel;
  final Map<int, _PanelClock> _panelClocks = {};
  final DetailOrientationLock _orientation = DetailOrientationLock();
  final GlobalKey _cameraSurfaceKey = GlobalKey();
  bool _soundEnabled = true;
  final VoiceAnnouncer _voices = VoiceAnnouncer();
  final VoicePlayback _voicePlayback = VoicePlayback();
  bool _trial = false;
  final DetailStatusPhrases _phrases = DetailStatusPhrases();
  String? _statusPhrase;
  Timer? _statusPhraseTimer;
  RoundResultPill? _roundPill;
  final DeskConfirmedStakeBook _stakeBook = DeskConfirmedStakeBook();
  late final CrossDeskAnnouncements _crossDesk = CrossDeskAnnouncements(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  bool _limitsOpen = false;
  bool _loading = true;
  bool _loadingBets = false;
  bool _submitting = false;
  int? _submittingResultId;
  bool _canceling = false;
  bool _betsLoaded = false;
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
  StreamSubscription<DeskCardSnapshot>? _cardSubscription;
  StreamSubscription<MemberBalanceChange>? _balanceSubscription;
  StreamSubscription<MemberForceLogout>? _forceLogoutSubscription;
  DeskBettingClock _clock = const DeskBettingClock();

  /// Latest hand for this desk. Phase 4C draws it. This phase only stores it.
  // ignore: unused_field
  DeskCardSnapshot? _cardSnapshot;
  final DetailSyncGate _syncGate = DetailSyncGate();
  final DetailSyncBuffer _syncBuffer = DetailSyncBuffer();
  bool _blockBettingRestart = false;
  bool _shoeReload = false;
  int? _memberUserId;
  final Set<String> _settlementInFlight = {};
  final Set<String> _settlementDone = {};
  final Set<String> _settlementExhausted = {};
  final Map<String, String> _settlementSignal = {};
  int _balanceRevision = 0;
  int _profileRead = 0;
  int _profileReadsInFlight = 0;
  final Map<String, String> _settlementResultKey = {};
  _SettlementWait? _settlementWait;

  bool get _holdLiveEvents => _syncBuffer.holdLiveEvents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deskId = widget.deskId;
    _voices.bindDesk(_deskId);
    _voices.enabled = _soundEnabled;
    unawaited(_loadVoicePreference());
    _api = ref.read(apiClientProvider);
    _lobby = ref.read(lobbyRepositoryProvider);
    _whep = MemberWhepPlayback(api: _api, memberToken: () => _token);
    _storage = ref.read(secureStorageProvider);
    _repository = BaccaratDetailRepository(_api);
    _socket = ref.read(lobbySocketServiceProvider);
    _resultSubscription = _socket.results.listen(_onResult);
    _statusSubscription = _socket.statuses.listen(_onSocketStatus);
    _deskUpdateSubscription = _socket.deskUpdates.listen(_onDeskUpdate);
    _cardSubscription = _socket.cardSnapshots.listen(_onCardSnapshot);
    _balanceSubscription = _socket.balanceChanges.listen(_onBalanceChange);
    _forceLogoutSubscription = _socket.forceLogouts.listen(_onForceLogout);
    unawaited(_loadChipDenominations());
    unawaited(_loadDetail());
  }

  @override
  void dispose() {
    if (_orientation.landscape) unawaited(_orientation.restorePortrait());
    _statusPhraseTimer?.cancel();
    _crossDesk.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_resultSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_deskUpdateSubscription?.cancel());
    unawaited(_cardSubscription?.cancel());
    unawaited(_balanceSubscription?.cancel());
    unawaited(_forceLogoutSubscription?.cancel());
    unawaited(_setRoom('home'));
    unawaited(_voicePlayback.dispose());
    super.dispose();
  }

  Future<void> _loadDetail({
    bool showLoading = true,
    int? switchToDeskId,
  }) async {
    final requestedDeskId = switchToDeskId ?? _deskId;
    final switching = switchToDeskId != null && switchToDeskId != _deskId;
    final generation = _syncGate.begin();
    _settlementWait?.cancel();
    _syncBuffer.gating = true;
    var committed = false;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _betsError = null;
        _poolError = null;
      });
    }

    var releaseProfileRead = false;
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
      int? userId = _memberUserId;
      try {
        userId = int.tryParse((await _storage.getUserId()) ?? '');
      } catch (_) {
        userId = _memberUserId;
      }
      if (!mounted || !_syncGate.isCurrent(generation)) return;
      _memberUserId = userId;

      final profileRead = ++_profileRead;
      final balanceRevisionAtLoad = _balanceRevision;
      _profileReadsInFlight++;
      releaseProfileRead = true;
      void releaseLoadProfileRead() {
        if (!releaseProfileRead) return;
        releaseProfileRead = false;
        _profileReadsInFlight--;
      }

      final loaded = await Future.wait<Object>([
        _repository.getDesk(requestedDeskId, token),
        _repository.getResultOptions(requestedDeskId, token),
        _repository.getRoundStatus(requestedDeskId, token),
        _repository.getProfile(token),
      ]);
      if (!mounted || !_syncGate.isCurrent(generation)) {
        releaseLoadProfileRead();
        return;
      }
      _syncBuffer.markProfileReady(generation);
      final desk = loaded[0] as BaccaratDeskDetail;
      final options = loaded[1] as List<BaccaratResultOption>;
      final status = loaded[2] as BaccaratRoundStatus;
      final profile = loaded[3] as BaccaratMemberProfile;
      final applyLoadedBalance =
          profileRead == _profileRead &&
          balanceRevisionAtLoad == _balanceRevision;
      final previousRoundId = _desk?.lastRoundId;
      final keepCards = keepDisplayedCards(
        httpCommitted: true,
        sameRound: cardsBelongToDisplayedRound(
          hasDisplayedRound: _desk != null,
          displayedSessionId: _desk?.sessionId,
          displayedRoundId: _desk?.lastRoundId,
          httpSessionId: desk.sessionId,
          httpRoundId: desk.lastRoundId,
        ),
      );
      if (!mounted || !_syncGate.isCurrent(generation)) {
        releaseLoadProfileRead();
        return;
      }

      if (switching) {
        _settlementWait?.cancel();
        unawaited(_voicePlayback.stop());
        if (_orientation.landscape) unawaited(_orientation.restorePortrait());
      }
      _clock = _clock.applyHttp(
        status: status.status,
        remainingSeconds: status.remainingSeconds,
      );
      final phrase = _phrases.onHttp(
        status: _clock.status ?? status.status,
        seconds: _clock.remainingSeconds,
        roundId: desk.lastRoundId,
      );
      _blockBettingRestart = blocksBufferedBettingRestart(_clock.status);
      final countdownOpen = _clock.isBetting && _clock.remainingSeconds > 0;
      final showHand = !switching && keepCards && !countdownOpen;
      if (!keepCards || switching) _socket.dropCardSnapshot(_deskId);
      setState(() {
        if (switching) {
          _rememberCurrentStake();
          _voices.bindDesk(requestedDeskId);
          _deskId = requestedDeskId;
          _cardSnapshot = null;
          _confirmedBets = _emptyBets;
          _poolTotals = BaccaratPoolTotals.empty;
          _clearStagedBets();
          _submittingResultId = null;
          _betsLoaded = false;
          _roundPill = null;
          _cameraMenuOpen = false;
          _cameraView = DeskCameraView.fullTable;
          _videoFullscreen = false;
          _landscapeVideo = false;
          _switchingDeskId = null;
          _switchingLabel = null;
        }
        _token = token;
        _csrfToken = csrfToken;
        _memberUserId = userId;
        _desk = desk;
        _options = options;
        _roundStatus = BaccaratRoundStatus(
          status: _clock.status ?? status.status,
          remainingSeconds: _clock.remainingSeconds,
        );
        if (!showHand) _cardSnapshot = null;
        if (applyLoadedBalance) {
          _balance = profile.balance;
          _balanceRevision++;
        }
        _memberLimits = profile.resultRateLimits;
        _loading = false;
        _betsLoaded = false;
        if (previousRoundId != desk.lastRoundId) {
          _rememberCurrentStake(roundId: previousRoundId);
          _confirmedBets = _emptyBets;
          _poolTotals = BaccaratPoolTotals.empty;
          _roundPill = null;
        }
        if (phrase != null) _statusPhrase = phrase;
        if (previousRoundId != null && previousRoundId != desk.lastRoundId) {
          _clearStagedBets();
        }
      });
      if (phrase != null) _armStatusPhrase();
      _announceLoadedClock(
        status: _clock.status ?? status.status,
        seconds: _clock.remainingSeconds,
        roundId: desk.lastRoundId,
      );
      releaseLoadProfileRead();
      _traceBalance(
        applyLoadedBalance
            ? 'table load applied profile'
            : 'table load kept newer balance',
        next: profile.balance,
      );
      ref
          .read(lobbyPreloadProvider.notifier)
          .synchronizeDeskResults(
            histories: {_deskId: desk.results},
            sessionIds: {_deskId: desk.sessionId},
          );
      unawaited(_setRoom('$_deskId'));
      unawaited(_loadTrialFlag());
      _connectSharedSocket(token);
      await _loadOpenRoundAmounts(
        token,
        desk.lastRoundId,
        generation: generation,
      );
      if (!mounted || !_syncGate.isCurrent(generation)) return;
      _drainBuffered(keepCards: showHand, generation: generation);
      committed = true;
    } on ApiException catch (error) {
      if (!_syncGate.isCurrent(generation)) return;
      if (!await _handleAuthError(error)) _showLoadError(error.message);
    } on FormatException catch (error) {
      if (!_syncGate.isCurrent(generation)) return;
      _showLoadError(error.message);
    } on TimeoutException {
      if (!_syncGate.isCurrent(generation)) return;
      _showLoadError('加载桌台信息超时');
    } on http.ClientException {
      if (!_syncGate.isCurrent(generation)) return;
      _showLoadError('无法连接服务器，请稍后重试');
    } finally {
      if (releaseProfileRead) {
        releaseProfileRead = false;
        _profileReadsInFlight--;
      }
      if (_syncGate.isCurrent(generation)) {
        if (!committed && mounted) {
          _blockBettingRestart = blocksBufferedBettingRestart(_clock.status);
          if (switching) {
            setState(() {
              _switchingDeskId = null;
              _switchingLabel = null;
            });
          }
          _drainBuffered(
            keepCards: keepDisplayedCards(
              httpCommitted: false,
              sameRound: false,
            ),
            generation: generation,
          );
        }
        _syncBuffer.gating = false;
        if (_shoeReload && mounted) {
          _shoeReload = false;
          unawaited(_loadDetail(showLoading: false));
        }
      }
    }
  }

  Future<void> _loadOpenRoundAmounts(
    String token,
    int? roundId, {
    int? generation,
  }) async {
    final activeGeneration = generation ?? _syncGate.newest;
    if (!mounted || !_syncGate.isCurrent(activeGeneration)) return;
    final deskId = _deskId;
    final ticket = _stakeBook.open(deskId);
    var stakeSettled = false;
    void keepStake(num amount) {
      if (stakeSettled) return;
      stakeSettled = true;
      _stakeBook.apply(deskId, amount, ticket);
    }

    void dropStake() {
      if (stakeSettled) return;
      stakeSettled = true;
      _stakeBook.abandon(deskId, ticket);
    }

    setState(() => _loadingBets = true);
    try {
      final confirmed = await _repository.getConfirmedBets(roundId, token);
      if (!mounted || !_syncGate.isCurrent(activeGeneration)) {
        dropStake();
        return;
      }
      setState(() {
        if (_deskId == deskId) {
          _confirmedBets = confirmed;
          _betsLoaded = true;
          _betsError = null;
        }
        keepStake(confirmed.totalAmount);
      });
      if (_deskId == deskId) _rememberCurrentStake();
    } on ApiException catch (error) {
      dropStake();
      if (_syncGate.isCurrent(activeGeneration) &&
          !await _handleAuthError(error) &&
          mounted &&
          _deskId == deskId) {
        setState(() => _betsError = error.message);
      }
    } on FormatException catch (error) {
      dropStake();
      if (mounted && _syncGate.isCurrent(activeGeneration) && _deskId == deskId) {
        setState(() => _betsError = error.message);
      }
    } on TimeoutException {
      dropStake();
      if (mounted && _syncGate.isCurrent(activeGeneration) && _deskId == deskId) {
        setState(() => _betsError = '读取本局投注超时');
      }
    } on http.ClientException {
      dropStake();
      if (mounted && _syncGate.isCurrent(activeGeneration) && _deskId == deskId) {
        setState(() => _betsError = '无法读取本局投注');
      }
    } finally {
      if (mounted && _syncGate.isCurrent(activeGeneration)) {
        setState(() => _loadingBets = false);
      }
    }

    try {
      final totals = await _repository.getPoolTotals(roundId, token);
      if (mounted && _syncGate.isCurrent(activeGeneration)) {
        setState(() {
          _poolTotals = totals;
          _poolError = null;
        });
      }
    } on ApiException catch (error) {
      if (_syncGate.isCurrent(activeGeneration) &&
          !await _handleAuthError(error) &&
          mounted) {
        setState(() => _poolError = error.message);
      }
    } on FormatException catch (error) {
      if (mounted && _syncGate.isCurrent(activeGeneration)) {
        setState(() => _poolError = error.message);
      }
    } on TimeoutException {
      if (mounted && _syncGate.isCurrent(activeGeneration)) {
        setState(() => _poolError = '读取台面投注汇总超时');
      }
    } on http.ClientException {
      if (mounted && _syncGate.isCurrent(activeGeneration)) {
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
      if (id != null && (gameType == 'BACCARAT' || gameType == 'LONGHU')) {
        deskIds.add(id);
      }
    }
    _socket.connect(token: token, deskIds: deskIds);
  }

  void _onResult(LobbyRoundResult result) {
    if (!mounted) return;
    if (result.deskId != _deskId) {
      ref.read(lobbyPreloadProvider.notifier).upsertResult(result);
      _announceOtherDesk(result);
      return;
    }
    if (_holdLiveEvents) {
      _syncBuffer.addResult(result);
      return;
    }
    _applyOpenDeskResult(result);
  }

  /// A result that arrived for some other desk. The open desk's badge is
  /// left alone. The same desk and round cannot announce twice.
  void _announceOtherDesk(LobbyRoundResult result) {
    _crossDesk.accept(
      deskId: result.deskId,
      roundId: result.roundId,
      viewedDeskIds: {_deskId},
      memberId: _memberUserId,
      netAmounts: result.netAmounts,
      label: _crossDeskLabel(result.deskId),
    );
  }

  String _crossDeskLabel(int deskId) {
    final snapshot = ref.read(lobbyPreloadProvider);
    for (final desk in snapshot.desks) {
      if (_asInt(desk['id']) == deskId) return formatCrossDeskDeskLabel(desk);
    }
    final open = _desk;
    if (open != null && open.id == deskId) {
      return formatCrossDeskDeskLabel({
        'name': open.name,
        'game': {'name': open.gameName},
      });
    }
    return '台';
  }

  void _applyOpenDeskResult(LobbyRoundResult result) {
    if (!mounted) return;
    // A result buffered for the desk we just left must not speak, merge, or
    // badge as the desk that is open now. It also must not become a
    // cross-desk notice: it arrived while that desk was the one on screen.
    if (result.deskId != _deskId) {
      ref.read(lobbyPreloadProvider.notifier).upsertResult(result);
      return;
    }
    final gameType = _desk?.gameType;
    if (gameType != null) {
      _playVoice(
        _voices.onResult(
          gameType: gameType,
          roundId: result.roundId,
          result: result.key,
        ),
      );
    }
    final table = _gameProfile;
    final resultKeys = result.key.split('|');
    if (resultKeys.any((key) => !table.allowedResultKeys.contains(key)) ||
        !resultKeys.any(table.mainResultKeys.contains)) {
      debugPrint(
        '[BaccaratDetail] ignoring invalid result '
        'deskId=${result.deskId} roundId=${result.roundId}',
      );
      return;
    }
    final current = _desk?.results ?? const <LobbyRoundResult>[];
    final merged = reconcileResults(base: current, incoming: [result]);
    final badge = memberRoundBadge(
      resultKey: result.key,
      memberId: _memberUserId,
      netAmounts: result.netAmounts,
      longhu: _gameProfile.longhu,
    );
    if (identical(merged, current)) {
      if (badge != null) setState(() => _roundPill = badge);
      _onSettlementResult(result);
      return;
    }
    ref.read(lobbyPreloadProvider.notifier).upsertResult(result);
    if (result.deskId != _deskId) return;
    setState(() {
      _clearStagedIfNewerRound(result.roundId);
      if (_desk != null) {
        _desk = BaccaratDeskDetail(
          id: _desk!.id,
          gameId: _desk!.gameId,
          name: _desk!.name,
          gameName: _desk!.gameName,
          gameType: _desk!.gameType,
          minBet: _desk!.minBet,
          maxBet: _desk!.maxBet,
          sessionId: _desk!.sessionId,
          sessionNo: _desk!.sessionNo,
          lastRoundId: _desk!.lastRoundId,
          lastRoundNo: _desk!.lastRoundNo,
          singleCamera: _desk!.singleCamera,
          deskType: _desk!.deskType,
          rateLimitEnabled: _desk!.rateLimitEnabled,
          deskResultRateLimits: _desk!.deskResultRateLimits,
          results: merged,
        );
        _roundPill = badge;
      }
    });
    _onSettlementResult(result);
  }

  /// Bets follow the open round. The profile follows this member's result
  /// even when that round is no longer open.
  void _onSettlementResult(LobbyRoundResult result) {
    if (result.deskId != _deskId) return;
    _traceBalance(
      'result',
      roundId: result.roundId,
      result: result.key,
      nets: result.netAmounts,
    );
    // The member site reloads the user on the result itself. That wallet
    // read is not gated on confirm_bets or on this member appearing in
    // userNetAmounts. A tie can omit the member and still refund the stake.
    _scheduleProfileRefresh(
      result.deskId,
      result.roundId,
      signal: 'result',
      resultKey: result.key,
    );
    if (result.roundId == _desk?.lastRoundId) {
      _scheduleSettlementForOpenRound(
        result.deskId,
        result.roundId,
        signal: 'result',
        resultKey: result.key,
      );
    }
  }

  /// Retries until `confirm_bets` reports `Round finished`, then clears the
  /// stake list. The wallet is refreshed separately.
  void _scheduleSettlementForOpenRound(
    int deskId,
    int roundId, {
    required String signal,
    String? resultKey,
  }) {
    if (deskId != _deskId || _desk?.lastRoundId != roundId) return;
    final key = 'bets:$deskId:$roundId';
    _allowCorrectedResult(key, resultKey);
    if (!_beginSettlement(key, signal)) return;
    final generation = _syncGate.newest;
    unawaited(_syncOpenRound(deskId, roundId, generation, key));
  }

  void _scheduleProfileRefresh(
    int deskId,
    int roundId, {
    required String signal,
    String? resultKey,
  }) {
    if (deskId != _deskId) return;
    final key = 'profile:$deskId:$roundId';
    _allowCorrectedResult(key, resultKey);
    if (!_beginSettlement(key, signal)) return;
    final generation = _syncGate.newest;
    unawaited(_syncProfile(deskId, roundId, generation, key));
  }

  /// A repeated result is ignored. A different result string for that round
  /// is a correction and may read the profile again.
  void _allowCorrectedResult(String key, String? resultKey) {
    if (resultKey == null) return;
    final previous = _settlementResultKey[key];
    if (previous != null && previous != resultKey) {
      _settlementDone.remove(key);
      _settlementExhausted.remove(key);
    }
    _settlementResultKey[key] = resultKey;
  }

  /// Settlement profile reads share one chain so two of them cannot be in
  /// flight together. A duplicate of the same round never enters the chain.
  Future<void>? _profileTail;

  Future<({BaccaratMemberProfile profile, int read})> _queuedGetProfile(
    String token,
  ) {
    final previous = _profileTail ?? Future<void>.value();
    final result = previous.then((_) async {
      final read = ++_profileRead;
      _profileReadsInFlight++;
      try {
        final profile = await _repository.getProfile(token);
        return (profile: profile, read: read);
      } finally {
        _profileReadsInFlight--;
      }
    });
    _profileTail = result.then((_) {}, onError: (_, _) {});
    return result;
  }

  bool _beginSettlement(String key, String signal) {
    if (_settlementInFlight.contains(key) || _settlementDone.contains(key)) {
      return false;
    }
    if (_settlementExhausted.contains(key) &&
        _settlementSignal[key] == signal) {
      return false;
    }
    _settlementExhausted.remove(key);
    _settlementSignal[key] = signal;
    _settlementInFlight.add(key);
    return true;
  }

  Future<void> _syncOpenRound(
    int deskId,
    int roundId,
    int generation,
    String key,
  ) async {
    var completed = false;
    var attempts = 0;
    try {
      final token = _token ?? await _storage.getAuthToken();
      if (token == null || token.isEmpty) return;
      while (attempts < _settlementAttempts) {
        if (!_settlementStillCurrent(deskId, roundId, generation)) return;
        attempts++;
        try {
          final confirmed = await _repository.getConfirmedBets(roundId, token);
          if (!_settlementStillCurrent(deskId, roundId, generation)) {
            _noteUnappliedSettlement(deskId, roundId);
            return;
          }
          if (!confirmedBetsReflectSettlement(confirmed)) {
            if (attempts >= _settlementAttempts) return;
            await _delaySettlementRetry();
            continue;
          }
          if (!mounted) return;
          if (!_settlementStillCurrent(deskId, roundId, generation)) {
            _noteUnappliedSettlement(deskId, roundId);
            return;
          }
          _rememberCurrentStake();
          setState(() {
            _confirmedBets = confirmed;
            _betsLoaded = true;
            _betsError = null;
          });
          _settlementDone.add(key);
          completed = true;
          return;
        } on ApiException catch (error) {
          if (await _handleAuthError(error)) return;
          _logSettlementFailure(deskId, roundId, error.message);
        } on FormatException catch (error) {
          _logSettlementFailure(deskId, roundId, error.message);
        } on TimeoutException {
          _logSettlementFailure(deskId, roundId, 'timed out');
        } on http.ClientException {
          _logSettlementFailure(deskId, roundId, 'could not connect');
        }
        if (attempts >= _settlementAttempts) return;
        await _delaySettlementRetry();
      }
    } finally {
      _settlementInFlight.remove(key);
      if (!completed &&
          attempts >= _settlementAttempts &&
          _deskId == deskId &&
          _desk?.lastRoundId == roundId) {
        _settlementExhausted.add(key);
      }
    }
  }

  Future<void> _syncProfile(
    int deskId,
    int roundId,
    int generation,
    String key,
  ) async {
    var completed = false;
    var attempts = 0;
    try {
      final token = _token ?? await _storage.getAuthToken();
      if (token == null || token.isEmpty) return;
      while (attempts < _settlementAttempts) {
        if (!_profileStillCurrent(deskId, generation)) return;
        attempts++;
        try {
          final revisionAtRead = _balanceRevision;
          final fetched = await _queuedGetProfile(token);
          if (!mounted || fetched.read != _profileRead) return;
          if (!_profileStillCurrent(deskId, generation)) return;
          if (revisionAtRead != _balanceRevision) {
            _traceBalance(
              'previous-round settlement kept newer balance',
              roundId: roundId,
              next: fetched.profile.balance,
            );
            _settlementDone.add(key);
            completed = true;
            return;
          }
          _applyBalance(
            fetched.profile.balance,
            stage: 'previous-round settlement profile',
          );
          _settlementDone.add(key);
          completed = true;
          return;
        } on ApiException catch (error) {
          if (await _handleAuthError(error)) return;
          _logSettlementFailure(deskId, roundId, error.message);
        } on FormatException catch (error) {
          _logSettlementFailure(deskId, roundId, error.message);
        } on TimeoutException {
          _logSettlementFailure(deskId, roundId, 'timed out');
        } on http.ClientException {
          _logSettlementFailure(deskId, roundId, 'could not connect');
        }
        if (attempts >= _settlementAttempts) return;
        await _delaySettlementRetry();
      }
    } finally {
      _settlementInFlight.remove(key);
      if (!completed && attempts >= _settlementAttempts && _deskId == deskId) {
        _settlementExhausted.add(key);
      }
    }
  }

  Future<void> _delaySettlementRetry() {
    _settlementWait?.cancel();
    final wait = _SettlementWait(_settlementRetryDelay);
    _settlementWait = wait;
    return wait.completer.future.whenComplete(() {
      if (identical(_settlementWait, wait)) _settlementWait = null;
    });
  }

  void _logSettlementFailure(int deskId, int roundId, String message) {
    debugPrint(
      '[BaccaratDetail] settlement sync failed for desk $deskId '
      'round $roundId: $message',
    );
  }

  bool _settlementStillCurrent(int deskId, int roundId, int generation) {
    return mounted &&
        _syncGate.isCurrent(generation) &&
        _deskId == deskId &&
        _desk?.lastRoundId == roundId;
  }

  bool _profileStillCurrent(int deskId, int generation) {
    return mounted && _syncGate.isCurrent(generation) && _deskId == deskId;
  }

  void _noteUnappliedSettlement(int deskId, int roundId) {
    if (!mounted || (_deskId == deskId && _desk?.lastRoundId == roundId)) {
      return;
    }
    debugPrint(
      '[BaccaratDetail] settlement for desk $deskId round $roundId '
      'was not applied to desk $_deskId round ${_desk?.lastRoundId}',
    );
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
    if (!mounted) return;
    _clearStakeMarkOnDeskSignal(update);
    if (update.deskId != _deskId) {
      _rememberPanelClock(update);
      if (_tablePanelOpen) setState(() {});
      return;
    }
    if (_holdLiveEvents) {
      if (update is LobbyDeskTimerUpdate) {
        _syncBuffer.addTimer(update.remainingSeconds);
      } else if (update is LobbyDeskStatusUpdate) {
        _syncBuffer.addStatus(update.status);
      } else if (update is LobbyDeskPoolTotalsUpdate) {
        _syncBuffer.addPool(update);
      } else if (update is LobbyDeskSessionFinished) {
        _syncBuffer.addShoeFinished();
      }
      return;
    }
    _applyDeskUpdate(update);
  }

  void _applyDeskUpdate(LobbyDeskUpdate update) {
    if (update is LobbyDeskTimerUpdate) {
      final countdownStarting =
          _clock.acceptNextTimer && update.remainingSeconds > 0;
      final next = _clock.applyTimer(update.remainingSeconds);
      if (next == null) return;
      final phrase = _phrases.onTimer(next.remainingSeconds);
      final reachedZero = next.remainingSeconds == 0;
      if (reachedZero) _statusPhraseTimer?.cancel();
      setState(() {
        _clock = next;
        _roundStatus = BaccaratRoundStatus(
          status: next.status ?? 'betting',
          remainingSeconds: next.remainingSeconds,
        );
        if (reachedZero) {
          _statusPhrase = null;
        } else if (phrase != null) {
          _statusPhrase = phrase;
        }
        if (countdownStarting && next.remainingSeconds > 0) {
          _cardSnapshot = null;
        }
      });
      if (phrase != null && !reachedZero) _armStatusPhrase();
      _playVoice(
        _voices.onTimer(
          status: next.status ?? 'betting',
          seconds: next.remainingSeconds,
        ),
      );
    } else if (update is LobbyDeskStatusUpdate) {
      final previousStatus = _clock.status ?? _roundStatus?.status;
      final awaitingCountdown = _clock.isBetting && _clock.acceptNextTimer;
      final next = _clock.applyStatus(update.status);
      final phrase = _phrases.onStatus(
        update.status,
        awaitingCountdown: awaitingCountdown,
      );
      setState(() {
        _clock = next;
        _roundStatus = BaccaratRoundStatus(
          status: next.status ?? update.status,
          remainingSeconds: next.remainingSeconds,
        );
        if (phrase != null) _statusPhrase = phrase;
        if (update.status == 'betting') _roundPill = null;
      });
      if (update.status == 'finished') {
        final roundId = _desk?.lastRoundId;
        if (roundId != null) {
          _scheduleProfileRefresh(_deskId, roundId, signal: 'finished');
          _scheduleSettlementForOpenRound(_deskId, roundId, signal: 'finished');
        }
      }
      // The next countdown does not carry the new round id. The member site
      // reloads desks when betting starts so the next bet uses that id.
      if (update.status == 'betting' &&
          (previousStatus == 'finished' || previousStatus == 'dealing')) {
        unawaited(_loadDetail(showLoading: false));
      }
      if (phrase != null) _armStatusPhrase();
      _playVoice(_voices.onStatus(next.status ?? update.status));
    } else if (update is LobbyDeskPoolTotalsUpdate) {
      final newerRound = _stagedRoundIsOlderThan(update.roundId);
      final sameOpenRound = _desk?.lastRoundId == update.roundId;
      if (!newerRound && !sameOpenRound) return;
      setState(() {
        if (newerRound) _clearStagedBets();
        if (sameOpenRound) {
          _poolTotals = BaccaratPoolTotals.fromSocket(update);
          _poolError = null;
        }
      });
    } else if (update is LobbyDeskSessionFinished) {
      unawaited(_loadDetail(showLoading: false));
    }
  }

  void _onCardSnapshot(DeskCardSnapshot snapshot) {
    if (!mounted || snapshot.deskId != _deskId) return;
    if (_holdLiveEvents) {
      _syncBuffer.addCards(snapshot);
      return;
    }
    setState(() => _cardSnapshot = snapshot);
  }

  void _onBalanceChange(MemberBalanceChange change) {
    if (!mounted || change.userId != _memberUserId) return;
    if (_holdLiveEvents) {
      _syncBuffer.addBalance(change);
      return;
    }
    _applyBalance(change.balance, stage: 'socket');
  }

  void _applyBalance(num balance, {required String stage}) {
    _balanceRevision++;
    setState(() => _balance = balance);
    unawaited(_storage.setBalance(balance.toString()));
    _traceBalance(stage, next: balance);
  }

  void _traceBalance(
    String stage, {
    int? roundId,
    String? result,
    num? next,
    Map<int, num>? nets,
  }) {
    debugPrint(
      '[BaccaratDetail] balance stage=$stage '
      'desk=$_deskId round=${roundId ?? _desk?.lastRoundId} '
      'shown=$_balance revision=$_balanceRevision '
      'next=$next result=$result nets=$nets '
      'at=${DateTime.now().toIso8601String()}',
    );
  }

  void _drainBuffered({required bool keepCards, required int generation}) {
    _syncBuffer.drain((event) {
      switch (event.kind) {
        case SyncEventKind.result:
          final result = event.result;
          if (result != null) _applyOpenDeskResult(result);
        case SyncEventKind.cards:
          if (!keepCards) return;
          final cards = event.cards;
          if (cards == null || !mounted) return;
          setState(() => _cardSnapshot = cards);
        case SyncEventKind.balance:
          final change = event.balance;
          if (change == null || !event.profilesReady.contains(generation)) {
            return;
          }
          if (change.userId != _memberUserId || !mounted) return;
          _applyBalance(change.balance, stage: 'socket');
        case SyncEventKind.timer:
          final seconds = event.seconds;
          if (seconds == null) return;
          _applyDeskUpdate(
            LobbyDeskTimerUpdate(deskId: _deskId, remainingSeconds: seconds),
          );
        case SyncEventKind.status:
          final status = event.status;
          if (status == null) return;
          if (status == 'betting' && _blockBettingRestart) return;
          _applyDeskUpdate(
            LobbyDeskStatusUpdate(deskId: _deskId, status: status),
          );
        case SyncEventKind.pool:
          final pool = event.pool;
          if (pool != null) _applyDeskUpdate(pool);
        case SyncEventKind.shoe:
          _shoeReload = true;
      }
    });
  }

  void _onForceLogout(MemberForceLogout logout) {
    if (!mounted || logout.userId != _memberUserId) return;
    if (!_socket.claimForceLogout(logout)) return;
    unawaited(_leaveAfterForceLogout());
  }

  Future<void> _leaveAfterForceLogout() async {
    await ref.read(authServiceProvider).logout();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_voicePlayback.stop());
    }
    if (state != AppLifecycleState.resumed || _token == null) return;
    if (!_socket.connected) _connectSharedSocket(_token!);
    unawaited(_refreshLiveData());
  }

  Future<void> _refreshLiveData() async {
    if (!mounted || _refreshingLiveData || _token == null) return;
    _refreshingLiveData = true;
    try {
      await _loadDetail(showLoading: false);
      await _refreshOtherStakeMarks();
    } finally {
      _refreshingLiveData = false;
    }
  }

  /// Re-reads confirmed stakes for desks that are not on screen.
  ///
  /// The open desk is already loaded by [_loadDetail]. A missed betting-start
  /// or shoe end while the socket was down is replaced by the server total.
  /// A failed read leaves the mark that was already accepted.
  Future<void> _refreshOtherStakeMarks() async {
    final token = _token;
    if (token == null || !mounted) return;
    final deskIds = List<int>.of(_stakeBook.amounts.keys);
    for (final deskId in deskIds) {
      if (!mounted || deskId == _deskId) continue;
      final roundId = _roundIdForDesk(deskId);
      final ticket = _stakeBook.open(deskId);
      if (roundId == null) {
        setState(() => _stakeBook.apply(deskId, 0, ticket));
        continue;
      }
      try {
        final confirmed = await _repository.getConfirmedBets(roundId, token);
        if (!mounted) return;
        setState(() => _stakeBook.apply(deskId, confirmed.totalAmount, ticket));
      } catch (_) {
        _stakeBook.abandon(deskId, ticket);
      }
    }
  }

  int? _roundIdForDesk(int deskId) {
    if (deskId == _deskId) return _desk?.lastRoundId;
    final snapshot = ref.read(lobbyPreloadProvider);
    for (final desk in snapshot.desks) {
      if (_asInt(desk['id']) != deskId) continue;
      final round = desk['last_round'];
      if (round is Map) return _asInt(round['id']);
    }
    return null;
  }

  void _clearStakeMarkOnDeskSignal(LobbyDeskUpdate update) {
    final bettingStarted =
        update is LobbyDeskStatusUpdate && update.status == 'betting';
    final shoeFinished = update is LobbyDeskSessionFinished;
    if (!bettingStarted && !shoeFinished) return;
    final removed = _stakeBook.clear(update.deskId);
    if (removed && mounted) setState(() {});
  }

  Future<void> _setRoom(String room) async {
    final token = _token ?? await _storage.getAuthToken();
    if (token == null || token.isEmpty) return;
    final csrf = _csrfToken ?? await _storage.getCsrfToken();
    try {
      await _lobby.updateRoom(token: token, csrfToken: csrf, room: room);
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
      _switchingDeskId = null;
      _switchingLabel = null;
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
          return (type == 'BACCARAT' || type == 'LONGHU') &&
              _asInt(desk['id']) != null;
        })
        .toList(growable: false);
  }

  void _rememberPanelClock(LobbyDeskUpdate update) {
    final clock = _panelClocks.putIfAbsent(update.deskId, _PanelClock.new);
    if (update is LobbyDeskTimerUpdate) {
      final seconds = update.remainingSeconds.clamp(0, 3600);
      clock.status ??= 'betting';
      if (seconds > clock.window) clock.window = seconds;
      clock.seconds = seconds;
    } else if (update is LobbyDeskStatusUpdate) {
      clock.status = update.status;
      if (update.status != 'betting') {
        clock.seconds = 0;
        clock.window = 0;
      }
    }
  }

  DeskListClock? _clockForDesk(int id) {
    if (id == _deskId) {
      final status = _roundStatus?.status;
      final seconds = _roundStatus?.remainingSeconds ?? 0;
      final window = _desk?.bettingSeconds ?? 0;
      return DeskListClock(
        status: status,
        remainingSeconds: seconds,
        bettingSeconds: window > 0 ? window : seconds,
      );
    }
    final clock = _panelClocks[id];
    if (clock == null) return null;
    return DeskListClock(
      status: clock.status,
      remainingSeconds: clock.seconds,
      bettingSeconds: clock.window,
    );
  }

  void _openTablePanel() {
    if (_switchingDeskId != null) return;
    setState(() => _tablePanelOpen = true);
  }

  Future<void> _selectDesk(Map<String, dynamic> desk) async {
    final choice = decideDeskSwitch(
      selectedId: _asInt(desk['id']),
      currentId: _deskId,
      switching: _switchingDeskId != null,
    );
    if (choice == DeskSwitchChoice.ignore) return;
    if (choice == DeskSwitchChoice.stay) {
      setState(() => _tablePanelOpen = false);
      return;
    }
    final id = _asInt(desk['id'])!;
    setState(() {
      _tablePanelOpen = false;
      _switchingDeskId = id;
      _switchingLabel = deskSwitchName(desk);
    });
    await _loadDetail(showLoading: false, switchToDeskId: id);
  }

  void _placeBet(BaccaratResultOption option) {
    final selectedChip = ref.read(selectedChipProvider);
    if (!_bettingOpen || selectedChip == null) return;
    if (_submittingResultId == option.id) return;
    final roundId = _desk?.lastRoundId;
    if (_pendingRoundId != null &&
        roundId != null &&
        roundId != _pendingRoundId) {
      return;
    }
    setState(() {
      _pendingRoundId ??= roundId;
      _pendingBets = Map.of(_pendingBets)
        ..update(
          option.id,
          (amount) => amount + selectedChip,
          ifAbsent: () => selectedChip,
        );
    });
  }

  void _cancelStaged(BaccaratResultOption option) {
    if (_submittingResultId == option.id) return;
    if ((_pendingBets[option.id] ?? 0) <= 0) return;
    setState(() {
      _pendingBets = Map.of(_pendingBets)..remove(option.id);
      if (_pendingBets.isEmpty) _pendingRoundId = null;
    });
  }

  /// Staged chips belong to one open round. A higher id is a new round.
  /// The same id is a replay, reconnect, or duplicate event.
  bool _stagedRoundIsOlderThan(int? roundId) {
    final stagedRound = _pendingRoundId;
    return stagedRound != null &&
        roundId != null &&
        _pendingBets.isNotEmpty &&
        roundId > stagedRound;
  }

  void _clearStagedIfNewerRound(int? roundId) {
    if (_stagedRoundIsOlderThan(roundId)) _clearStagedBets();
  }

  void _clearStagedBets() {
    _pendingBets = {};
    _pendingRoundId = null;
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
      final displayed = [
        ..._chipStripOrder.where(denominations.contains),
        ...denominations.where(
          (value) => value != 100000 && !_chipStripOrder.contains(value),
        ),
      ];
      if (displayed.isEmpty) {
        throw const FormatException('筹码资源与网站默认筹码配置不匹配');
      }
      setState(() {
        _chipDenominations = List.unmodifiable(denominations);
        _displayChipDenominations = List.unmodifiable(displayed);
        _chipError = null;
      });
      // Chip images can finish loading during the first build. The default
      // is applied on the next frame so it does not write the provider then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedChipProvider.notifier).useDefaultIfUnset(displayed);
      });
    } on FormatException catch (error) {
      debugPrint('[BaccaratDetail] chip assets invalid: ${error.message}');
      if (mounted) setState(() => _chipError = error.message);
    } on FlutterError catch (error) {
      debugPrint('[BaccaratDetail] failed to load chip assets: $error');
      if (mounted) setState(() => _chipError = '筹码图片资源加载失败');
    }
  }

  Future<void> _confirmStaged(BaccaratResultOption option) async {
    if (_submitting || _canceling || !_betsLoaded) return;
    final amount = _pendingBets[option.id] ?? 0;
    if (amount <= 0) return;
    if (!_bettingOpen) {
      _showMessage(_bettingClosedNotice());
      return;
    }
    final desk = _desk;
    final token = _token;
    final lastRoundId = desk?.lastRoundId;
    if (desk == null || token == null || lastRoundId == null) return;
    if (_pendingRoundId != null && _pendingRoundId != lastRoundId) {
      setState(_clearStagedBets);
      return;
    }

    final validationError = validateBaccaratBetBatch(
      desk: desk,
      options: _options,
      confirmedBets: _confirmedBets.byResultKey,
      pendingBets: {option.id: amount},
      memberLimits: _memberLimits,
      roundPoolTotals: _poolTotals.totals,
      roundPoolTotalsAvailable: _poolTotals.roundId == lastRoundId,
      balance: _balance,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    final deskId = _deskId;
    final stakeTicket = _stakeBook.open(deskId);
    var stakeSettled = false;
    void keepStake(num amount) {
      if (stakeSettled) return;
      stakeSettled = true;
      _stakeBook.apply(deskId, amount, stakeTicket);
    }

    void dropStake() {
      if (stakeSettled) return;
      stakeSettled = true;
      _stakeBook.abandon(deskId, stakeTicket);
    }

    bool responseMatchesOpenTable() =>
        mounted && _deskId == deskId && _desk?.lastRoundId == lastRoundId;
    void noteUnappliedResponse() {
      if (!mounted || responseMatchesOpenTable()) return;
      debugPrint(
        '[BaccaratDetail] bet response for desk $deskId round $lastRoundId '
        'stays on that round and was not applied to desk $_deskId '
        'round ${_desk?.lastRoundId}',
      );
    }

    final cumulative =
        (option.key.isNotEmpty
            ? _confirmedBets.byResultKey[option.key]?.amount ?? 0
            : 0) +
        amount;
    final balanceRevisionAtSubmit = _balanceRevision;
    setState(() {
      _submitting = true;
      _submittingResultId = option.id;
    });
    try {
      final result = await _repository.submitBets(
        lastRoundId: lastRoundId,
        bets: [
          BaccaratBetSubmissionItem(
            resultId: option.id,
            amount: amount,
            image: baccaratCoinImageForAmount(cumulative, _chipDenominations),
          ),
        ],
        token: token,
        csrfToken: _csrfToken ?? '',
      );
      if (!mounted) {
        dropStake();
        return;
      }
      if (!responseMatchesOpenTable()) {
        setState(() => keepStake(result.totalBetAmount));
        noteUnappliedResponse();
        return;
      }
      // remainingBalance is the wallet after the stake is taken and before
      // settlement. A profile read already in flight, or any balance applied
      // since this request started, is newer than that snapshot.
      final roundAlreadySettled = _settlementDone.contains(
        'bets:$_deskId:$lastRoundId',
      );
      final applyRemaining =
          !roundAlreadySettled &&
          _balanceRevision == balanceRevisionAtSubmit &&
          _profileReadsInFlight == 0;
      setState(() {
        if (!roundAlreadySettled) _confirmedBets = result.confirmedBets;
        keepStake(result.totalBetAmount);
        _rememberCurrentStake();
        if (applyRemaining) {
          _balance = result.remainingBalance;
          _balanceRevision++;
        }
        _pendingBets = Map.of(_pendingBets)..remove(option.id);
        if (_pendingBets.isEmpty) _pendingRoundId = null;
      });
      if (applyRemaining) {
        await _storage.setBalance(result.remainingBalance.toString());
      }
      _traceBalance(
        applyRemaining
            ? 'bet accepted'
            : 'bet accepted without replacing newer balance',
        roundId: lastRoundId,
        next: result.remainingBalance,
      );
      _showMessage('下注成功');
    } on ApiException catch (error) {
      dropStake();
      if (!mounted) return;
      if (await _handleAuthError(error)) return;
      if (responseMatchesOpenTable()) {
        _showMessage(error.message);
      } else {
        noteUnappliedResponse();
      }
    } on BaccaratActionException catch (error) {
      dropStake();
      if (responseMatchesOpenTable()) {
        _showMessage(error.message);
      } else {
        noteUnappliedResponse();
      }
    } on FormatException catch (error) {
      dropStake();
      if (responseMatchesOpenTable()) {
        _showMessage(error.message);
      } else {
        noteUnappliedResponse();
      }
    } on TimeoutException {
      dropStake();
      if (responseMatchesOpenTable()) {
        _showMessage('下注请求超时，请刷新确认投注状态');
      } else {
        noteUnappliedResponse();
      }
    } on http.ClientException {
      dropStake();
      if (responseMatchesOpenTable()) {
        _showMessage('无法连接服务器，请刷新确认投注状态');
      } else {
        noteUnappliedResponse();
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submittingResultId = null;
        });
      }
    }
  }

  void _rememberCurrentStake({int? roundId}) {
    final stakeRound = roundId ?? _desk?.lastRoundId;
    if (stakeRound == null || _confirmedBets.totalAmount <= 0) return;
    final amounts = <int, num>{
      for (final bet in _confirmedBets.byResultKey.values)
        if (bet.amount > 0) bet.resultId: bet.amount,
    };
    if (amounts.isEmpty) return;
    final memory = _stakeMemory.putIfAbsent(_deskId, _StakeMemory.new);
    if (memory.latestRoundId == stakeRound) {
      memory.latest = amounts;
      return;
    }
    memory.previousRoundId = memory.latestRoundId;
    memory.previous = memory.latest;
    memory.latestRoundId = stakeRound;
    memory.latest = amounts;
  }

  Map<int, num>? _rememberedPreviousStake(int? currentRoundId) {
    final memory = _stakeMemory[_deskId];
    if (memory == null) return null;
    if (memory.latestRoundId != null &&
        memory.latestRoundId != currentRoundId &&
        memory.latest != null) {
      return memory.latest;
    }
    if (memory.previousRoundId != null &&
        memory.previousRoundId != currentRoundId &&
        memory.previous != null) {
      return memory.previous;
    }
    return null;
  }

  /// A cancelled round is no longer a stake this desk can repeat.
  void _forgetOpenStake(int? roundId) {
    if (roundId == null) return;
    final memory = _stakeMemory[_deskId];
    if (memory == null) return;
    if (memory.latestRoundId == roundId) memory.latest = null;
    if (memory.previousRoundId == roundId) memory.previous = null;
  }

  bool _sameStake(Map<int, num> current, Map<int, num> next) {
    if (current.length != next.length) return false;
    for (final entry in next.entries) {
      if (current[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> _repeatLastBet() async {
    if (_repeating || _submitting || _canceling) return;
    if (!_betsLoaded) return;
    final desk = _desk;
    final token = _token;
    if (desk == null || token == null) return;
    if (_confirmedBets.totalAmount > 0) {
      _showMessage(alreadyBetRepeatNotice);
      return;
    }

    // A new shoe has no GameRound. The header shows that as round 0 while
    // the stage stays active (等待). The lookup and empty notice still run.
    final deskId = _deskId;
    final lastRoundId = desk.lastRoundId;
    setState(() => _repeating = true);
    try {
      Map<int, num>? amounts;
      try {
        final rows = await _repository.recentDeskStakes(
          token: token,
          deskId: deskId,
        );
        if (!mounted || _deskId != deskId) return;
        amounts = repeatAmountsForDesk(
          rows: rows,
          deskName: desk.name,
          sessionNo: desk.sessionNo,
          roundNo: desk.lastRoundNo,
          options: _options,
        );
      } on ApiException catch (error) {
        if (!mounted) return;
        if (await _handleAuthError(error)) return;
        amounts = _rememberedPreviousStake(lastRoundId);
        if (amounts == null) {
          _showMessage(error.message);
          return;
        }
      } on FormatException catch (error) {
        amounts = _rememberedPreviousStake(lastRoundId);
        if (amounts == null) {
          _showMessage(error.message);
          return;
        }
      } on TimeoutException {
        amounts = _rememberedPreviousStake(lastRoundId);
        if (amounts == null) {
          _showMessage('下注请求超时，请刷新确认投注状态');
          return;
        }
      } on http.ClientException {
        amounts = _rememberedPreviousStake(lastRoundId);
        if (amounts == null) {
          _showMessage('无法连接服务器，请刷新确认投注状态');
          return;
        }
      }
      amounts ??= _rememberedPreviousStake(lastRoundId);
      if (amounts == null || amounts.isEmpty) {
        _showMessage(noPreviousBetNotice);
        return;
      }
      if (!mounted || _deskId != deskId || _desk?.lastRoundId != lastRoundId) {
        return;
      }
      final staged = amounts;
      if (_sameStake(_pendingBets, staged)) return;
      setState(() {
        _pendingRoundId = lastRoundId;
        _pendingBets = Map<int, num>.from(staged);
      });
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  Future<void> _cancelBets() async {
    if (_submitting || _canceling) return;
    final desk = _desk;
    final token = _token;
    final roundId = desk?.lastRoundId;
    if (!_canCancel || desk == null || token == null || roundId == null) return;
    final deskId = desk.id;
    final stakeTicket = _stakeBook.open(deskId);
    var stakeSettled = false;
    void keepStake(num amount) {
      if (stakeSettled) return;
      stakeSettled = true;
      _stakeBook.apply(deskId, amount, stakeTicket);
    }

    void dropStake() {
      if (stakeSettled) return;
      stakeSettled = true;
      _stakeBook.abandon(deskId, stakeTicket);
    }

    setState(() => _canceling = true);
    try {
      await _repository.cancelBets(
        lastRoundId: roundId,
        token: token,
        csrfToken: _csrfToken ?? '',
      );
      final profileRead = ++_profileRead;
      final balanceRevisionAtCancel = _balanceRevision;
      _profileReadsInFlight++;
      final BaccaratMemberProfile profile;
      final BaccaratConfirmedBets confirmed;
      try {
        final results = await Future.wait<Object>([
          _repository.getConfirmedBets(roundId, token),
          _repository.getProfile(token),
        ]);
        confirmed = results[0] as BaccaratConfirmedBets;
        profile = results[1] as BaccaratMemberProfile;
      } finally {
        _profileReadsInFlight--;
      }
      if (!mounted) {
        dropStake();
        return;
      }
      final applyBalance =
          profileRead == _profileRead &&
          balanceRevisionAtCancel == _balanceRevision;
      final stillThisDesk = _deskId == deskId && _desk?.lastRoundId == roundId;
      setState(() {
        keepStake(confirmed.totalAmount);
        if (stillThisDesk) {
          _confirmedBets = confirmed;
          _rememberCurrentStake();
          if (confirmed.totalAmount <= 0) _forgetOpenStake(roundId);
          if (applyBalance) {
            _balance = profile.balance;
            _balanceRevision++;
          }
          _memberLimits = profile.resultRateLimits;
        }
      });
      if (stillThisDesk && applyBalance) {
        await _storage.setBalance(_balance.toString());
      }
      if (stillThisDesk) {
        _traceBalance(
          applyBalance ? 'cancel applied profile' : 'cancel kept newer balance',
          roundId: roundId,
          next: profile.balance,
        );
        _showMessage('成功取消下注');
      }
    } on ApiException catch (error) {
      dropStake();
      if (!await _handleAuthError(error)) _showMessage(error.message);
    } on BaccaratActionException catch (error) {
      dropStake();
      _showMessage(error.message);
    } on FormatException catch (error) {
      dropStake();
      _showMessage(error.message);
    } on TimeoutException {
      dropStake();
      _showMessage('取消投注请求超时，请刷新确认投注状态');
    } on http.ClientException {
      dropStake();
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
    setState(() => _statusPhrase = message);
    _armStatusPhrase(
      detailRepeatNotice(message) ? detailRepeatNoticeHold : null,
    );
  }

  void _selectCameraOption(String label) {
    final view = cameraViewForLabel(label);
    if (view == null) return;
    if (view == DeskCameraView.fullscreen) {
      unawaited(_enterLandscapeVideo());
      return;
    }
    setState(() => _cameraView = view);
  }

  Future<void> _enterLandscapeVideo() async {
    if (_landscapeVideo) return;
    setState(() {
      _landscapeVideo = true;
      _videoFullscreen = false;
      _cameraMenuOpen = false;
    });
    await _orientation.enterLandscape();
  }

  Future<void> _exitLandscapeVideo() async {
    final leaving = _landscapeVideo || _orientation.landscape;
    if (mounted && leaving) {
      setState(() {
        _landscapeVideo = false;
        _videoFullscreen = false;
        _cameraMenuOpen = false;
      });
    }
    if (_orientation.landscape) await _orientation.restorePortrait();
  }

  Future<void> _leaveDetail() async {
    if (_landscapeVideo || _orientation.landscape) {
      await _exitLandscapeVideo();
    }
    if (!mounted) return;
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
    final camera = cameraForDeskView(
      cameras: snapshot.cameras,
      deskId: desk.id,
      view: _cameraView,
    );
    final playback = camera == null
        ? const CameraPlayback.none()
        : resolveCameraPlayback(
            apiBaseUrl: AppConfig.apiBaseUrl,
            camera: camera,
          );
    final availableDesks = _availableBaccaratDesks(snapshot);
    final status = _roundStatus;
    final bettingOpen = _bettingOpen;
    final videoPanel = BaccaratVideoPanel(
      deskName: '${desk.gameName}${desk.name}台',
      roundLabel: '${desk.sessionNo ?? '0'}靴-${desk.lastRoundNo ?? '0'}局',
      status: status?.status ?? 'active',
      remainingSeconds: status?.remainingSeconds ?? 0,
      countdownSeconds: desk.bettingSeconds,
      ticker: snapshot.setting('web_bet_announcement'),
      limitsOpen: _limitsOpen,
      limitLines: _limitLines(desk),
      onToggleLimits: () => setState(() => _limitsOpen = !_limitsOpen),
      playback: playback,
      whep: _whep,
      cameraLabel: '切换画面',
      cameraCount: 2,
      cameraMenuOpen: _cameraMenuOpen,
      cameraOptions: cameraOptionLabels(desk.deskType),
      onSelectCameraOption: _selectCameraOption,
      cameraSurfaceKey: _cameraSurfaceKey,
      landscape: _landscapeVideo,
      trialStamp: _roadStamp(),
      trialStampColor: _roadStampColor(),
      statusText: _statusPhrase,
      badgeText: _roundPill?.outcome,
      badgeDetail: _roundPill?.detail,
      badgeDetailIsNote: _roundPill?.detailIsNote ?? false,
      onVideoTap: () => unawaited(
        _landscapeVideo ? _exitLandscapeVideo() : _enterLandscapeVideo(),
      ),
      onBack: () {
        if (_landscapeVideo) {
          unawaited(_exitLandscapeVideo());
          return;
        }
        if (_videoFullscreen) {
          setState(() => _videoFullscreen = false);
          return;
        }
        unawaited(_leaveDetail());
      },
      onSwitchTable: _openTablePanel,
      onSwitchCamera: () => setState(() => _cameraMenuOpen = !_cameraMenuOpen),
      soundEnabled: _soundEnabled,
      onSoundChanged: _setVoiceEnabled,
    );
    return PopScope(
      canPop: !_landscapeVideo && !_tablePanelOpen && _switchingDeskId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_landscapeVideo) {
          unawaited(_exitLandscapeVideo());
          return;
        }
        if (_tablePanelOpen) setState(() => _tablePanelOpen = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _landscapeVideo
                ? videoPanel
                : SafeArea(
                    child: LayoutBuilder(
                      builder: (context, _) {
                        // Reference 1800x2880 content, below the status bar: the
                        // video is 1074px and the betting panel is 1118px. They
                        // share whatever space the roadmap does not use, so a
                        // shorter painted road cannot leave the extra pixels in
                        // the video.
                        return Column(
                          children: [
                            Expanded(
                              flex: _videoFullscreen ? 1 : 1074,
                              child: videoPanel,
                            ),
                            if (!_videoFullscreen) ...[
                              if (_error != null)
                                _MessageBanner(
                                  message: _error!,
                                  onRetry: () => _loadDetail(),
                                ),
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
                                      : _loadOpenRoundAmounts(
                                          _token!,
                                          desk.lastRoundId,
                                        ),
                                ),
                              if (_poolError != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    12,
                                    0,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    _chipError!,
                                    style: const TextStyle(
                                      color: Color(0xFFFFB8A8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              Expanded(
                                flex: 1118,
                                child: Stack(
                                  children: [
                                    BaccaratBettingPanel(
                                      deskId: desk.id,
                                      longhu: _gameProfile.longhu,
                                      cards: _switchingDeskId == null
                                          ? _cardSnapshot
                                          : null,
                                      options: _options,
                                      confirmedBets: _confirmedBets.byResultKey,
                                      confirmedTotalAmount:
                                          _confirmedBets.totalAmount,
                                      pendingBets: _pendingBets,
                                      chipDenominations:
                                          _displayChipDenominations,
                                      poolTotals:
                                          _poolTotals.displayTotals.isEmpty
                                          ? _poolTotals.totals
                                          : _poolTotals.displayTotals,
                                      selectedChip: ref.watch(
                                        selectedChipProvider,
                                      ),
                                      balance: _balance,
                                      minBet: desk.minBet,
                                      maxBet: desk.maxBet,
                                      bettingOpen:
                                          bettingOpen &&
                                          _betsLoaded &&
                                          _betsError == null &&
                                          !_loadingBets,
                                      secondsRemaining:
                                          status?.remainingSeconds ?? 0,
                                      submitting: _submitting,
                                      submittingResultId: _submittingResultId,
                                      canceling: _canceling,
                                      onSelectChip: (chip) => ref
                                          .read(selectedChipProvider.notifier)
                                          .select(chip),
                                      onPlaceBet: _placeBet,
                                      onConfirmZone: (option) =>
                                          unawaited(_confirmStaged(option)),
                                      onCancelZone: _cancelStaged,
                                      onCancel: () => unawaited(_cancelBets()),
                                      onRepeat: () =>
                                          unawaited(_repeatLastBet()),
                                      repeating: _repeating,
                                      onHistory: () =>
                                          unawaited(_showBettingHistory()),
                                      onCustomerService: () =>
                                          unawaited(_showCustomerServiceInfo()),
                                      boardBanner: _crossDesk.current == null
                                          ? null
                                          : CrossDeskResultBar(
                                              content:
                                                  _crossDesk.current!.content,
                                            ),
                                    ),
                                    if (_roundPill != null)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Center(
                                            child: _WinBadge(pill: _roundPill!),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              BaccaratRoadmapPanel(
                                longhu: _gameProfile.longhu,
                                results: results,
                                stamp: _roadStamp(),
                                stampColor: _roadStampColor(),
                                statusText: _statusPhrase,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
            if (_tablePanelOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('table-switch-scrim'),
                  onTap: () => setState(() => _tablePanelOpen = false),
                  behavior: HitTestBehavior.opaque,
                ),
              ),
            if (_tablePanelOpen)
              Positioned(
                // The video title strip stays visible above the list.
                top: _landscapeVideo
                    ? 0
                    : MediaQuery.paddingOf(context).top + 27,
                right: 0,
                bottom: 0,
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ),
                  duration: const Duration(milliseconds: 220),
                  builder: (context, offset, child) {
                    return FractionalTranslation(
                      translation: offset,
                      child: child,
                    );
                  },
                  child: TableSwitchPanel(
                    desks: availableDesks,
                    currentDeskId: _deskId,
                    initialType: _gameProfile.gameType,
                    trial: _trial,
                    clockFor: _clockForDesk,
                    confirmedBetAmountByDesk: Map<int, num>.of(
                      _stakeBook.amounts,
                    ),
                    onSelect: (desk) => unawaited(_selectDesk(desk)),
                  ),
                ),
              ),
            if (_tablePanelOpen && !_landscapeVideo)
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: MediaQuery.sizeOf(context).width * (94 / 600),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: MediaQuery.sizeOf(context).width * (2 / 600),
                    ),
                    child: TableSwitchEdgeButton(
                      onPressed: () => setState(() => _tablePanelOpen = false),
                    ),
                  ),
                ),
              ),
            if (_switchingLabel != null)
              Positioned.fill(
                child: DeskSwitchOverlay(deskName: _switchingLabel!),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTrialFlag() async {
    final trial = await _readTrial();
    if (!mounted || _trial == trial) return;
    setState(() => _trial = trial);
  }

  Future<bool> _readTrial() async {
    try {
      return await _storage.getTrialUser();
    } catch (_) {
      return false;
    }
  }

  List<String> _limitLines(BaccaratDeskDetail desk) {
    final order = GameTableProfile.forType(desk.gameType).limitKeyOrder;
    final lines = <String>[];
    for (final key in order) {
      BaccaratResultOption? option;
      for (final candidate in _options) {
        if (candidate.key == key) {
          option = candidate;
          break;
        }
      }
      if (option == null) continue;
      final limit =
          desk.deskResultRateLimits[option.id] ?? _memberLimits[option.id];
      final minimum = limit?.minBet ?? desk.minBet;
      final maximum = limit?.maxBet ?? desk.maxBet;
      lines.add(
        '${option.name}:${_formatAmount(minimum)}-${_formatAmount(maximum)}',
      );
    }
    return lines;
  }

  String? _roadStamp() => detailRoadStamp(trial: _trial);

  void _playVoice(VoiceCue? cue) {
    if (cue == null) return;
    debugPrint('[Voice] cue ${cue.asset}');
    unawaited(_voicePlayback.play(cue));
  }

  void _announceLoadedClock({
    required String status,
    required int seconds,
    required int? roundId,
  }) {
    _voices.onDisplayedRound(roundId);
    _playVoice(_voices.onStatus(status));
    _playVoice(_voices.onTimer(status: status, seconds: seconds));
  }

  Future<void> _loadVoicePreference() async {
    try {
      final enabled = LocalStorage(await SharedPreferences.getInstance())
          .gameVoiceEnabled;
      if (!mounted) return;
      _voices.enabled = enabled;
      if (enabled != _soundEnabled) setState(() => _soundEnabled = enabled);
    } catch (_) {
      // Tests have no preferences plugin. The speaker stays on.
    }
  }

  Future<void> _storeVoiceEnabled(bool enabled) async {
    try {
      await LocalStorage(await SharedPreferences.getInstance())
          .setGameVoiceEnabled(enabled);
    } catch (_) {}
  }

  void _setVoiceEnabled(bool enabled) {
    setState(() => _soundEnabled = enabled);
    _voices.enabled = enabled;
    if (!enabled) unawaited(_voicePlayback.stop());
    unawaited(_storeVoiceEnabled(enabled));
  }

  void _armStatusPhrase([Duration? hold]) {
    _statusPhraseTimer?.cancel();
    _statusPhraseTimer = Timer(hold ?? detailStatusPhraseHold, () {
      if (!mounted) return;
      setState(() => _statusPhrase = null);
    });
  }

  Color _roadStampColor() => const Color(0xE6E02028);

  bool get _bettingOpen =>
      _roundStatus?.isBetting == true &&
      (_roundStatus?.remainingSeconds ?? 0) > 0;

  /// Preview chips can be restored in any phase. Submission still uses
  /// the phrases already shown for a closed table.
  String _bettingClosedNotice() {
    final status = _roundStatus?.status;
    if (status == 'finished' || status == 'active') return '等待发牌';
    return '停止下注';
  }

  bool get _canCancel =>
      _bettingOpen && (_roundStatus?.remainingSeconds ?? 0) > 5;
}

class _PanelClock {
  String? status;
  int seconds = 0;
  int window = 0;
}

class _StakeMemory {
  int? latestRoundId;
  Map<int, num>? latest;
  int? previousRoundId;
  Map<int, num>? previous;
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

class _WinBadge extends StatelessWidget {
  const _WinBadge({required this.pill});

  final RoundResultPill pill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('current-desk-result-pill'),
      decoration: BoxDecoration(
        color: const Color(0xE6222222),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pill.outcome,
              style: const TextStyle(
                color: crossDeskDeskInk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pill.detail,
              style: TextStyle(
                color: pill.detailIsNote
                    ? crossDeskZeroInk
                    : crossDeskDeskInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _chipStripOrder = [1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000];

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

String _formatAmount(num amount) => formatDetailAmount(amount);

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
