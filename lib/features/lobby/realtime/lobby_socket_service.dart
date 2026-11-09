import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../../core/constants/app_constants.dart';
import '../models/lobby_round_result.dart';

final lobbySocketServiceProvider = Provider<LobbySocketService>((ref) {
  final service = LobbySocketService(apiBaseUrl: AppConstants.apiBaseUrl);
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
      final match = RegExp(r'^desk:(\d+):updateResult$').firstMatch(event);
      if (match == null) return;
      final deskId = int.parse(match.group(1)!);
      if (!_deskIds.contains(deskId)) return;
      try {
        final result = LobbyRoundResult.fromSocket(deskId, payload);
        _debugLog('result received deskId=$deskId roundId=${result.roundId}');
        _results.add(result);
      } on FormatException catch (error) {
        _debugLog(
          'invalid result payload deskId=$deskId error=${error.message}',
        );
        _protocolErrors.add(error.message);
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
