import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../../core/config/app_config.dart';
import '../models/lobby_round_result.dart';
import 'live_table_events.dart';

final lobbySocketServiceProvider = Provider<LobbySocketService>((ref) {
  final service = LobbySocketService(apiBaseUrl: AppConfig.apiBaseUrl);
  ref.onDispose(service.dispose);
  return service;
});

typedef LobbySocketFactory = LobbySocketConnection Function(
  String url,
  Map<String, dynamic> options,
);

abstract interface class LobbySocketConnection {
  bool get connected;

  void connect();

  void disconnect();

  void dispose();

  void on(String event, void Function(dynamic) handler);

  void off(String event, void Function(dynamic) handler);

  void onAny(void Function(String event, dynamic payload) handler);

  void offAny(void Function(String event, dynamic payload) handler);

  void onManagerEvent(String event, void Function(dynamic) handler);

  void offManagerEvent(String event, void Function(dynamic) handler);
}

class LobbySocketStatus {
  const LobbySocketStatus({
    required this.connected,
    this.error,
    this.authenticationFailed = false,
  });

  final bool connected;
  final String? error;
  final bool authenticationFailed;
}

sealed class LobbyDeskUpdate {
  const LobbyDeskUpdate({required this.deskId});

  final int deskId;
}

class LobbyDeskTimerUpdate extends LobbyDeskUpdate {
  const LobbyDeskTimerUpdate({
    required super.deskId,
    required this.remainingSeconds,
  });

  final int remainingSeconds;
}

class LobbyDeskStatusUpdate extends LobbyDeskUpdate {
  const LobbyDeskStatusUpdate({required super.deskId, required this.status});

  final String status;
}

class LobbyDeskPoolTotalsUpdate extends LobbyDeskUpdate {
  const LobbyDeskPoolTotalsUpdate({
    required super.deskId,
    required this.roundId,
    required this.poolType,
    required this.totals,
    required this.displayTotals,
  });

  final int roundId;
  final String poolType;
  final Map<String, num> totals;
  final Map<String, num> displayTotals;
}

class LobbyDeskSessionFinished extends LobbyDeskUpdate {
  const LobbyDeskSessionFinished({required super.deskId});
}

class LobbySocketService {
  LobbySocketService({
    required this.apiBaseUrl,
    LobbySocketFactory? socketFactory,
  }) : _socketFactory = socketFactory ?? _createSocket;

  final String apiBaseUrl;
  final LobbySocketFactory _socketFactory;
  final _results = StreamController<LobbyRoundResult>.broadcast(sync: true);
  final _statuses = StreamController<LobbySocketStatus>.broadcast(sync: true);
  final _protocolErrors = StreamController<String>.broadcast(sync: true);
  final _deskUpdates = StreamController<LobbyDeskUpdate>.broadcast(sync: true);
  final _cards = StreamController<DeskCardSnapshot>.broadcast(sync: true);
  final _balances = StreamController<MemberBalanceChange>.broadcast(sync: true);
  final _forceLogouts = StreamController<MemberForceLogout>.broadcast(
    sync: true,
  );
  final Map<int, DeskCardSnapshot> _cardsByDesk = {};
  MemberForceLogout? _unclaimedForceLogout;

  LobbySocketConnection? _socket;
  String? _token;
  Set<int> _deskIds = {};
  bool _connectionStarted = false;
  void Function(dynamic)? _onConnect;
  void Function(dynamic)? _onDisconnect;
  void Function(dynamic)? _onConnectError;
  void Function(String, dynamic)? _onAny;
  final Map<String, void Function(dynamic)> _managerListeners = {};

  Stream<LobbyRoundResult> get results => _results.stream;
  Stream<LobbySocketStatus> get statuses => _statuses.stream;
  Stream<String> get protocolErrors => _protocolErrors.stream;
  Stream<LobbyDeskUpdate> get deskUpdates => _deskUpdates.stream;
  Stream<DeskCardSnapshot> get cardSnapshots => _cards.stream;
  Stream<MemberBalanceChange> get balanceChanges => _balances.stream;
  Stream<MemberForceLogout> get forceLogouts => _forceLogouts.stream;
  bool get connected => _socket?.connected ?? false;

  DeskCardSnapshot? cardSnapshotFor(int deskId) => _cardsByDesk[deskId];

  /// Drops the cached hand without emitting. Used when the open round changed
  /// and the cached cards must not be replayed as a live snapshot.
  void dropCardSnapshot(int deskId) {
    _cardsByDesk.remove(deskId);
  }

  /// Drops the hand for [deskId] and emits an empty snapshot.
  void forgetCardSnapshot(int deskId) {
    _cardsByDesk.remove(deskId);
    if (_cards.isClosed) return;
    _cards.add(DeskCardSnapshot.empty(deskId));
  }

  /// The first listener to claim [event] handles logout. Later listeners no-op.
  bool claimForceLogout(MemberForceLogout event) {
    if (!identical(_unclaimedForceLogout, event)) return false;
    _unclaimedForceLogout = null;
    return true;
  }

  void connect({required String token, required Iterable<int> deskIds}) {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'Must not be empty');
    }
    if (_socket != null && _token != token) {
      disconnect();
    }
    updateDeskIds(deskIds);
    if (_socket == null) {
      _token = token;
      final url = socketServerUrl(apiBaseUrl);
      final options = socketOptions(token);
      _debugLog(
        'creating connection url=$url path=/socket.io '
        'transport=${(options['transports'] as List).join(',')} '
        'timeoutMs=10000 '
        'reconnectDelayMs=1000..3000 deskCount=${_deskIds.length} '
        'tokenPresent=true',
      );
      _socket = _socketFactory(url, options);
      _attachListeners(_socket!);
    }

    if (!_socket!.connected && !_connectionStarted) {
      _connectionStarted = true;
      _debugLog('connect requested');
      _statuses.add(const LobbySocketStatus(connected: false));
      _socket!.connect();
    }
  }

  void updateDeskIds(Iterable<int> deskIds) {
    _deskIds = deskIds.where((id) => id > 0).toSet();
  }

  void disconnect({bool resetSession = true}) {
    final socket = _socket;
    if (socket == null) return;
    _debugLog('disconnect requested resetSession=$resetSession');
    if (resetSession) {
      _detachListeners(socket);
      _socket = null;
      _token = null;
      _deskIds = {};
      _connectionStarted = false;
      socket.disconnect();
      socket.dispose();
    } else {
      _connectionStarted = false;
      socket.disconnect();
    }
    _statuses.add(const LobbySocketStatus(connected: false));
  }

  void dispose() {
    disconnect();
    unawaited(_results.close());
    unawaited(_statuses.close());
    unawaited(_protocolErrors.close());
    unawaited(_deskUpdates.close());
    unawaited(_cards.close());
    unawaited(_balances.close());
    unawaited(_forceLogouts.close());
  }

  void _attachListeners(LobbySocketConnection socket) {
    _onConnect = (_) {
      _connectionStarted = true;
      _debugLog('connected');
      _statuses.add(const LobbySocketStatus(connected: true));
    };
    _onDisconnect = (reason) {
      _debugLog('disconnected reason=${_safeLogText(_errorMessage(reason))}');
      _statuses.add(
        LobbySocketStatus(
          connected: false,
          error: reason?.toString() ?? 'Socket.IO disconnected',
        ),
      );
      if (reason?.toString() == 'io server disconnect') {
        _connectionStarted = false;
        scheduleMicrotask(() {
          if (identical(_socket, socket) &&
              !_socket!.connected &&
              !_connectionStarted) {
            _connectionStarted = true;
            socket.connect();
          }
        });
      }
    };
    _onConnectError = (error) {
      _connectionStarted = false;
      final message = _errorMessage(error);
      final authenticationFailed = _isAuthenticationError(message);
      _debugLog(
        'connect_error type=${error.runtimeType} '
        'authenticationRejected=$authenticationFailed '
        'message=${_safeLogText(message)}',
      );
      _statuses.add(
        LobbySocketStatus(
          connected: false,
          error: message,
          authenticationFailed: authenticationFailed,
        ),
      );
    };
    _onAny = (event, payload) {
      if (event == 'member_balance:change') {
        _emitBalance(payload);
        return;
      }
      if (event == 'online_player:force_logout') {
        _emitForceLogout(payload);
        return;
      }
      final match = RegExp(
        r'^desk:(\d+):(updateResult|updateTimer|updateStatus|roundPoolTotals|finish-session|finish_session|dealCard|deleteLastCard)$',
      ).firstMatch(event);
      if (match == null) return;
      final deskId = int.parse(match.group(1)!);
      if (!_deskIds.contains(deskId)) return;
      switch (match.group(2)) {
        case 'updateResult':
          try {
            final result = LobbyRoundResult.fromSocket(deskId, payload);
            _debugLog(
              'result received deskId=$deskId roundId=${result.roundId}',
            );
            _results.add(result);
          } on FormatException catch (error) {
            _debugLog(
              'invalid result payload deskId=$deskId error=${error.message}',
            );
            _protocolErrors.add(error.message);
          }
        case 'updateTimer':
          final seconds = _asInt(payload);
          if (seconds == null) {
            _invalidDeskUpdate(deskId, 'updateTimer');
            return;
          }
          _deskUpdates.add(
            LobbyDeskTimerUpdate(deskId: deskId, remainingSeconds: seconds),
          );
        case 'updateStatus':
          final status = payload is String
              ? payload
              : payload is Map
              ? payload['status']?.toString()
              : null;
          if (status == null || status.isEmpty) {
            _invalidDeskUpdate(deskId, 'updateStatus');
            return;
          }
          _deskUpdates.add(
            LobbyDeskStatusUpdate(deskId: deskId, status: status),
          );
        case 'roundPoolTotals':
          try {
            _deskUpdates.add(_poolTotalsUpdate(deskId, payload));
          } on FormatException catch (error) {
            _debugLog(
              'invalid pool totals deskId=$deskId error=${error.message}',
            );
            _protocolErrors.add(error.message);
          }
        case 'finish-session':
        case 'finish_session':
          _deskUpdates.add(LobbyDeskSessionFinished(deskId: deskId));
        case 'dealCard':
          _emitDealCard(deskId, payload);
        case 'deleteLastCard':
          _emitDeleteLastCard(deskId, payload);
      }
    };

    socket
      ..on('connect', _onConnect!)
      ..on('disconnect', _onDisconnect!)
      ..on('connect_error', _onConnectError!)
      ..onAny(_onAny!);

    for (final event in const [
      'reconnect_attempt',
      'reconnect',
      'reconnect_error',
      'reconnect_failed',
    ]) {
      void handler(dynamic value) {
        _debugLog(
          'manager event=$event '
          'details=${_safeLogText(_errorMessage(value))}',
        );
      }

      _managerListeners[event] = handler;
      socket.onManagerEvent(event, handler);
    }
  }

  void _emitBalance(Object? payload) {
    try {
      _balances.add(MemberBalanceChange.fromPayload(payload));
    } on FormatException catch (error) {
      _debugLog('invalid balance payload error=${error.message}');
      _protocolErrors.add(error.message);
    }
  }

  void _emitForceLogout(Object? payload) {
    try {
      final logout = MemberForceLogout.fromPayload(payload);
      _unclaimedForceLogout = logout;
      _forceLogouts.add(logout);
    } on FormatException catch (error) {
      _debugLog('invalid force logout payload error=${error.message}');
      _protocolErrors.add(error.message);
    }
  }

  void _emitDealCard(int deskId, Object? payload) {
    try {
      final snapshot = DeskCardSnapshot.fromDeal(deskId, payload);
      _cardsByDesk[deskId] = snapshot;
      _cards.add(snapshot);
    } on FormatException catch (error) {
      _debugLog('invalid dealCard deskId=$deskId error=${error.message}');
      _protocolErrors.add(error.message);
    }
  }

  void _emitDeleteLastCard(int deskId, Object? payload) {
    final current = _cardsByDesk[deskId];
    if (current == null || current.kind != DeskCardKind.baccarat) return;
    final position = payload is Map ? payload['position']?.toString() : null;
    try {
      final snapshot = current.deleteLast(position);
      _cardsByDesk[deskId] = snapshot;
      _cards.add(snapshot);
    } on FormatException catch (error) {
      _debugLog('invalid deleteLastCard deskId=$deskId error=${error.message}');
      _protocolErrors.add(error.message);
    }
  }

  void _invalidDeskUpdate(int deskId, String event) {
    final message = 'Invalid $event payload for desk $deskId';
    _debugLog(message);
    _protocolErrors.add(message);
  }

  void _detachListeners(LobbySocketConnection socket) {
    final onConnect = _onConnect;
    final onDisconnect = _onDisconnect;
    final onConnectError = _onConnectError;
    final onAny = _onAny;
    if (onConnect != null) socket.off('connect', onConnect);
    if (onDisconnect != null) socket.off('disconnect', onDisconnect);
    if (onConnectError != null) socket.off('connect_error', onConnectError);
    if (onAny != null) socket.offAny(onAny);
    for (final entry in _managerListeners.entries) {
      socket.offManagerEvent(entry.key, entry.value);
    }
    _managerListeners.clear();
    _onConnect = null;
    _onDisconnect = null;
    _onConnectError = null;
    _onAny = null;
  }

  static LobbySocketConnection _createSocket(
    String url,
    Map<String, dynamic> options,
  ) {
    return _SocketIoConnection(socket_io.io(url, options));
  }
}

class _SocketIoConnection implements LobbySocketConnection {
  _SocketIoConnection(this._socket);

  final socket_io.Socket _socket;

  @override
  bool get connected => _socket.connected;

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void dispose() => _socket.dispose();

  @override
  void on(String event, void Function(dynamic) handler) {
    _socket.on(event, handler);
  }

  @override
  void off(String event, void Function(dynamic) handler) {
    _socket.off(event, handler);
  }

  @override
  void onAny(void Function(String event, dynamic payload) handler) {
    _socket.onAny(handler);
  }

  @override
  void offAny(void Function(String event, dynamic payload) handler) {
    _socket.offAny(handler);
  }

  @override
  void onManagerEvent(String event, void Function(dynamic) handler) {
    _socket.io.on(event, handler);
  }

  @override
  void offManagerEvent(String event, void Function(dynamic) handler) {
    _socket.io.off(event, handler);
  }
}

Map<String, dynamic> socketOptions(String token, {bool isWeb = kIsWeb}) =>
    socket_io.OptionBuilder()
        .setPath('/socket.io')
        .setTransports(isWeb ? ['polling', 'websocket'] : ['websocket'])
        .setTimeout(10000)
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(3000)
        .enableWithCredentials()
        .enableReconnection()
        .disableAutoConnect()
        .setAuth({'token': token, 'audience': 'member'})
        .build();

String socketServerUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  final path = uri.path.replaceFirst(RegExp(r'/api/?$'), '');
  return uri.replace(path: path, query: null, fragment: null).toString();
}

String _errorMessage(Object? error) {
  if (error is Map && error['message'] != null) {
    return error['message'].toString();
  }
  return error?.toString() ?? 'Socket.IO connection failed';
}

bool _isAuthenticationError(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('authentication required') ||
      normalized.contains('invalid token') ||
      normalized.contains('token invalid') ||
      normalized.contains('tokenexpired') ||
      normalized.contains('user not found');
}

LobbyDeskPoolTotalsUpdate _poolTotalsUpdate(int deskId, Object? payload) {
  if (payload is! Map) {
    throw const FormatException('Pool totals payload must be an object');
  }
  final roundId = _asInt(payload['round_id']);
  final poolType = payload['pool_type']?.toString();
  final totals = _numericMap(payload['totals']);
  final displayTotals = _numericMap(payload['display_totals']);
  if (roundId == null ||
      poolType == null ||
      totals == null ||
      displayTotals == null) {
    throw const FormatException('Pool totals payload is missing required data');
  }
  return LobbyDeskPoolTotalsUpdate(
    deskId: deskId,
    roundId: roundId,
    poolType: poolType,
    totals: totals,
    displayTotals: displayTotals,
  );
}

Map<String, num>? _numericMap(Object? value) {
  if (value is! Map) return null;
  final output = <String, num>{};
  for (final entry in value.entries) {
    final number = entry.value;
    if (number is num) {
      output[entry.key.toString()] = number;
    } else {
      final parsed = num.tryParse(number?.toString() ?? '');
      if (parsed == null) return null;
      output[entry.key.toString()] = parsed;
    }
  }
  return output;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

void _debugLog(String message) {
  if (kDebugMode) debugPrint('[LobbySocket] $message');
}

String _safeLogText(String message) {
  return message
      .replaceAll(
        RegExp(r'Bearer\s+\S+', caseSensitive: false),
        'Bearer <redacted>',
      )
      .replaceAll(RegExp(r'\beyJ[\w-]+\.[\w-]+\.[\w-]+\b'), '<redacted-jwt>');
}
