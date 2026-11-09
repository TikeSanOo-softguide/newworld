import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:newsworld/core/network/api_client.dart';
import 'package:newsworld/core/storage/secure_storage.dart';
import 'package:newsworld/features/game_detail/baccarat_game_detail_page.dart';
import 'package:newsworld/features/lobby/realtime/lobby_socket_service.dart';
import 'package:newsworld/features/preload/lobby_preload.dart';

void main() {
  testWidgets('loads the detail page sections without narrow-screen overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeSocket = _FakeSocket();
    final service = LobbySocketService(
      apiBaseUrl: 'https://api.example.test/api',
      socketFactory: (_, _) => fakeSocket,
    );
    final apiClient = _DetailPageClient();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(
              client: apiClient,
              baseUrl: 'https://api.example.test/api',
            ),
          ),
          secureStorageProvider.overrideWithValue(_TestSecureStorage()),
          lobbySocketServiceProvider.overrideWithValue(service),
          lobbyPreloadProvider.overrideWith(_TestPreload.new),
        ],
        child: const MaterialApp(home: BaccaratGameDetailPage(deskId: 4)),
      ),
    );
    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('百家乐 A1'), findsOneWidget);
    expect(find.text('下注记录'), findsOneWidget);
    expect(find.text('闲对'), findsWidgets);
    expect(find.bySemanticsLabel('筹码 100'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 1000'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 5000'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 10000'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 50000'), findsNothing);
    expect(tester.takeException(), isNull);

    fakeSocket.trigger('desk:5:updateResult', {
      'round_id': 9,
      'result': 'player',
    });
    final preload = ProviderScope.containerOf(
      tester.element(find.byType(BaccaratGameDetailPage)),
    ).read(lobbyPreloadProvider);
    final otherDesk = preload.desks.singleWhere((desk) => desk['id'] == 5);
    expect((otherDesk['results'] as List).single['key'], 'player');

    tester.view.physicalSize = const Size(320, 720);
    await tester.pump();
    expect(tester.takeException(), isNull);

    fakeSocket.trigger('desk:4:updateStatus', 'betting');
    fakeSocket.trigger('desk:4:updateTimer', 10);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('下注中 10s'), findsOneWidget);

    fakeSocket.trigger('desk:4:updateTimer', 9);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('下注中 9s'), findsOneWidget);

    fakeSocket.trigger('desk:4:updateStatus', 'dealing');
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('停止下注'), findsWidgets);
    expect(find.text('下注中 9s'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('珠盘路'), findsOneWidget);

    fakeSocket.trigger('connect', null);
    fakeSocket.trigger('disconnect', 'transport close');
    fakeSocket.trigger('connect', null);
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(apiClient.requestCount('/api/user/desks'), 2);
    expect(fakeSocket.anyListenerCount, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(apiClient.requestCount('/api/user/desks'), 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits staged chips and reconciles cancellation from the API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeSocket = _FakeSocket();
    final service = LobbySocketService(
      apiBaseUrl: 'https://api.example.test/api',
      socketFactory: (_, _) => fakeSocket,
    );
    final apiClient = _DetailPageClient();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(
              client: apiClient,
              baseUrl: 'https://api.example.test/api',
            ),
          ),
          secureStorageProvider.overrideWithValue(_TestSecureStorage()),
          lobbySocketServiceProvider.overrideWithValue(service),
          lobbyPreloadProvider.overrideWith(_TestPreload.new),
        ],
        child: const MaterialApp(home: BaccaratGameDetailPage(deskId: 4)),
      ),
    );
    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    fakeSocket.trigger('desk:4:updateStatus', 'betting');
    fakeSocket.trigger('desk:4:updateTimer', 20);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('闲').first);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('下注').first);
    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('下注成功'), findsOneWidget);
    final betRequest = apiClient.requests.singleWhere(
      (request) => request.url.path == '/api/user/bet_results',
    );
    expect(jsonDecode((betRequest as http.Request).body), {
      'last_round': 2,
      'bets': [
        {'result_id': 1, 'amount': 100, 'image': '/images/coins/100chip.png'},
      ],
    });

    await tester.drag(find.byType(ListView).first, const Offset(0, 250));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('取消').first);
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      apiClient.requests.any(
        (request) => request.url.path == '/api/user/cancle_bet_results',
      ),
      isTrue,
    );
    expect(find.text('已取消投注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestSecureStorage extends SecureStorage {
  _TestSecureStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> getAuthToken() async => 'member-jwt';

  @override
  Future<String?> getCsrfToken() async => 'csrf-token';

  @override
  Future<void> setBalance(String? balance) async {}
}

class _TestPreload extends LobbyPreloadNotifier {
  @override
  LobbySnapshot build() => const LobbySnapshot(
    games: [
      {'id': 2, 'type': 'BACCARAT'},
    ],
    desks: [
      {
        'id': 4,
        'game_id': 2,
        'name': 'A1',
        'game': {'type': 'BACCARAT', 'name': '百家乐'},
        'results': [
          {'round_id': 1, 'key': 'banker'},
        ],
      },
      {
        'id': 5,
        'game_id': 2,
        'name': 'A2',
        'game': {'type': 'BACCARAT', 'name': '百家乐'},
        'results': <Map<String, dynamic>>[],
      },
    ],
    cameras: [],
    parameterSettings: [],
    failures: [],
  );
}

class _DetailPageClient extends http.BaseClient {
  final List<String> requestPaths = [];
  final List<http.BaseRequest> requests = [];

  int requestCount(String path) =>
      requestPaths.where((requestPath) => requestPath == path).length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestPaths.add(request.url.path);
    requests.add(request);
    final response = switch ('${request.method} ${request.url.path}') {
      'GET /api/user/desks' => {
        'success': true,
        'data': {
          'desks': [
            {
              'id': 4,
              'game_id': 2,
              'name': 'A1',
              'min_bet': 100,
              'max_bet': 50000,
              'session': {'id': 1},
              'last_round': {'id': 2, 'round_no': 1},
              'game': {'name': '百家乐', 'type': 'BACCARAT'},
              'results': [
                {'round_id': 1, 'key': 'banker'},
              ],
            },
          ],
        },
      },
      'GET /api/user/results_by_desk/4' => {
        'success': true,
        'data': {
          'results': [
            {'id': 1, 'key': 'player', 'name': '闲', 'ratio': 1, 'position': 1},
            {
              'id': 2,
              'key': 'banker',
              'name': '庄',
              'ratio': 0.95,
              'position': 2,
            },
            {'id': 3, 'key': 'tie', 'name': '和', 'ratio': 8, 'position': 3},
            {
              'id': 4,
              'key': 'playerPair',
              'name': '闲对',
              'ratio': 11,
              'position': 4,
            },
            {
              'id': 5,
              'key': 'bankerPair',
              'name': '庄对',
              'ratio': 11,
              'position': 5,
            },
          ],
        },
      },
      'GET /api/user/last_round_status/4' => {
        'success': true,
        'data': {
          'lastRound': {'status': 'active'},
          'remaining_seconds': 0,
        },
      },
      'GET /api/user/profile' => {
        'success': true,
        'data': {
          'user': {'balance': 1000},
        },
      },
      'GET /api/user/confirm_bets/2' => {
        'success': true,
        'data': {'confirmedBets': {}, 'totalBetAmount': 0},
      },
      'GET /api/user/round_pool_totals/2' => {
        'success': true,
        'data': {
          'round_id': 2,
          'pool_type': 'baccarat',
          'totals': {},
          'display_totals': {},
        },
      },
      'PATCH /api/user/room' => {'success': true},
      'POST /api/user/bet_results' => {
        'success': true,
        'data': {
          'totalBetAmount': 100,
          'remainingBalance': 900,
          'confirmedBets': {
            'player': {'result_id': 1, 'amount': 100, 'image': ''},
          },
        },
      },
      'POST /api/user/cancle_bet_results' => {'success': true},
      _ => throw StateError(
        'Unexpected API request: ${request.method} ${request.url}',
      ),
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(response))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FakeSocket implements LobbySocketConnection {
  final List<void Function(String, dynamic)> _anyListeners = [];
  final Map<String, List<void Function(dynamic)>> _eventListeners = {};
  bool _connected = false;

  int get anyListenerCount => _anyListeners.length;

  @override
  bool get connected => _connected;

  @override
  void connect() => _connected = true;

  @override
  void disconnect() => _connected = false;

  @override
  void dispose() {}

  @override
  void on(String event, void Function(dynamic) handler) {
    (_eventListeners[event] ??= []).add(handler);
  }

  @override
  void off(String event, void Function(dynamic) handler) {
    _eventListeners[event]?.remove(handler);
  }

  @override
  void onAny(void Function(String event, dynamic payload) handler) {
    _anyListeners.add(handler);
  }

  @override
  void offAny(void Function(String event, dynamic payload) handler) {
    _anyListeners.remove(handler);
  }

  void trigger(String event, dynamic payload) {
    if (event == 'connect') _connected = true;
    if (event == 'disconnect') _connected = false;
    for (final listener in List.of(_eventListeners[event] ?? const [])) {
      listener(payload);
    }
    for (final listener in List.of(_anyListeners)) {
      listener(event, payload);
    }
  }

  @override
  void onManagerEvent(String event, void Function(dynamic) handler) {}

  @override
  void offManagerEvent(String event, void Function(dynamic) handler) {}
}
