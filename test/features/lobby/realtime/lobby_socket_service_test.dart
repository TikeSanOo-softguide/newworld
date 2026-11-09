import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/lobby/models/lobby_round_result.dart';
import 'package:newsworld/features/lobby/realtime/lobby_socket_service.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_calculations.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_models.dart';
import 'package:newsworld/features/preload/lobby_preload.dart';

void main() {
  group('LobbySocketService', () {
    test('uses the member JWT and exact server connection configuration', () {
      expect(
        socketServerUrl('https://api.example.test/api'),
        'https://api.example.test',
      );
      expect(
        socketServerUrl('http://localhost:3001/api/'),
        'http://localhost:3001',
      );
      final options = socketOptions('member-jwt');

      expect(options['path'], '/socket.io');
      expect(options['transports'], ['websocket']);
      expect(options['timeout'], 10000);
      expect(options['reconnection'], isNot(false));
      expect(options['reconnectionDelay'], 1000);
      expect(options['reconnectionDelayMax'], 3000);
      expect(options['auth'], {'token': 'member-jwt', 'audience': 'member'});
      expect(socketOptions('member-jwt', isWeb: true)['transports'], [
        'polling',
        'websocket',
      ]);
    });

    test(
      'reuses one connection and one global listener across result events',
      () async {
        final fake = _FakeSocket();
        var factoryCalls = 0;
        final service = LobbySocketService(
          apiBaseUrl: 'https://api.example.test/api',
          socketFactory: (url, options) {
            factoryCalls++;
            expect(url, 'https://api.example.test');
            expect(options['auth'], {
              'token': 'member-jwt',
              'audience': 'member',
            });
            return fake;
          },
        );
        final received = <LobbyRoundResult>[];
        final subscription = service.results.listen(received.add);

        service.connect(token: 'member-jwt', deskIds: [4]);
        service.connect(token: 'member-jwt', deskIds: [4, 4]);
        expect(factoryCalls, 1);
        expect(fake.connectCalls, 1);
        expect(fake.anyListenerCount, 1);

        fake.trigger('connect');
        fake.trigger('desk:4:updateResult', {
          'round_id': 9,
          'result': 'banker|bankerPair',
          'userNetAmounts': const [],
        });
        fake.trigger('desk:4:updateResult', {
          'round_id': 10,
          'result': 'player',
        });
        fake.trigger('desk:5:updateResult', {'round_id': 11, 'result': 'tie'});
        fake.trigger('desk:4:updateResult', {'round_id': 12});

        expect(received.map((result) => result.roundId), [9, 10]);
        expect(fake.anyListenerCount, 1);

        await subscription.cancel();
        service.dispose();
        expect(fake.disposeCalls, 1);
        expect(fake.anyListenerCount, 0);
      },
    );

    test(
      'surfaces authentication and connection errors, then reconnects',
      () async {
        final fake = _FakeSocket();
        final service = LobbySocketService(
          apiBaseUrl: 'https://api.example.test/api',
          socketFactory: (_, _) => fake,
        );
        final statuses = <LobbySocketStatus>[];
        final subscription = service.statuses.listen(statuses.add);

        service.connect(token: 'member-jwt', deskIds: [4]);
        fake.trigger('connect_error', 'Authentication required');
        expect(statuses.last.authenticationFailed, isTrue);

        fake.trigger('connect_error', 'timeout');
        expect(statuses.last.authenticationFailed, isFalse);
        expect(statuses.last.error, 'timeout');

        service.connect(token: 'member-jwt', deskIds: [4]);
        expect(fake.connectCalls, 2);

        fake.trigger('connect');
        fake.trigger('disconnect', 'transport close');
        fake.trigger('connect');
        expect(statuses.where((status) => status.connected), hasLength(2));
        expect(fake.anyListenerCount, 1);

        fake.trigger('disconnect', 'io server disconnect');
        await Future<void>.delayed(Duration.zero);
        expect(fake.connectCalls, 3);

        service.disconnect(resetSession: false);
        service.connect(token: 'member-jwt', deskIds: [4]);
        expect(fake.connectCalls, 4);
        expect(fake.anyListenerCount, 1);

        service.disconnect();
        expect(fake.disposeCalls, 1);
        await subscription.cancel();
        service.dispose();
      },
    );

    test(
      'socket results update provider history and all six roadmaps',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(lobbyPreloadProvider.notifier);
        notifier.replace(
          const LobbySnapshot(
            games: [],
            desks: [
              {
                'id': 4,
                'session': {'id': 1},
                'results': [
                  {'round_id': 1, 'key': 'banker', 'round_no': 1},
                ],
              },
            ],
            cameras: [],
            parameterSettings: [],
            failures: [],
          ),
        );

        final fake = _FakeSocket();
        final service = LobbySocketService(
          apiBaseUrl: 'https://api.example.test/api',
          socketFactory: (_, _) => fake,
        );
        final subscription = service.results.listen(notifier.upsertResult);
        service.connect(token: 'member-jwt', deskIds: [4]);
        fake.trigger('desk:4:updateResult', {'round_id': 3, 'result': 'tie'});
        fake.trigger('desk:4:updateResult', {
          'round_id': 2,
          'result': 'player',
        });
        fake.trigger('desk:4:updateResult', {
          'round_id': 2,
          'result': 'player',
        });

        final results =
            (container.read(lobbyPreloadProvider).desks.single['results']
                    as List)
                .map((result) => LobbyRoundResult.fromApi(4, result))
                .toList();
        final roadmapResults = results
            .map((result) => RoadmapResult(key: result.key))
            .toList();
        final roads = [
          calculateMarkerRoad(roadmapResults),
          calculateBigRoad(roadmapResults),
          calculateBigEyeRoad(roadmapResults),
          calculateSmallRoad(roadmapResults),
          calculateCockroachRoad(roadmapResults),
          calculateSecondBigRoad(roadmapResults),
        ];

        expect(results.map((result) => result.roundId), [1, 2, 3]);
        expect(roads.map((road) => road.type), [
          RoadmapType.marker,
          RoadmapType.big,
          RoadmapType.bigEye,
          RoadmapType.small,
          RoadmapType.cockroach,
          RoadmapType.secondBig,
        ]);
        expect(roads.first.markers, hasLength(3));
        expect(roads.last.markers, hasLength(2));

        await subscription.cancel();
        service.dispose();
      },
    );

    test('reconnect history replaces old-session results and merges same-session results', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(lobbyPreloadProvider.notifier);
      notifier.replace(
        const LobbySnapshot(
          games: [],
          desks: [
            {
              'id': 4,
              'session': {'id': 1},
              'results': [
                {'round_id': 1, 'key': 'banker'},
                {'round_id': 3, 'key': 'tie'},
              ],
            },
          ],
          cameras: [],
          parameterSettings: [],
          failures: [],
        ),
      );

      notifier.synchronizeDeskResults(
        histories: {
          4: const [
            LobbyRoundResult(deskId: 4, roundId: 1, key: 'banker'),
            LobbyRoundResult(deskId: 4, roundId: 2, key: 'player'),
          ],
        },
        sessionIds: {4: 1},
      );
      final sameSession =
          container.read(lobbyPreloadProvider).desks.single['results'] as List;
      expect(sameSession, hasLength(3));

      notifier.synchronizeDeskResults(
        histories: {
          4: const [LobbyRoundResult(deskId: 4, roundId: 10, key: 'player')],
        },
        sessionIds: {4: 2},
      );
      final newSession =
          container.read(lobbyPreloadProvider).desks.single['results'] as List;
      expect(newSession, hasLength(1));
      expect(newSession.single['round_id'], 10);
      expect(
        (container.read(lobbyPreloadProvider).desks.single['session']
            as Map)['id'],
        2,
      );
    });
  });
}

class _FakeSocket implements LobbySocketConnection {
  final Map<String, List<void Function(dynamic)>> _listeners = {};
  final List<void Function(String, dynamic)> _anyListeners = [];

  @override
  bool connected = false;
  int connectCalls = 0;
  int disposeCalls = 0;

  int get anyListenerCount => _anyListeners.length;

  @override
  void connect() => connectCalls++;

  @override
  void disconnect() => connected = false;

  @override
  void dispose() => disposeCalls++;

  @override
  void on(String event, void Function(dynamic) handler) {
    _listeners.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void off(String event, void Function(dynamic) handler) {
    _listeners[event]?.remove(handler);
  }

  @override
  void onAny(void Function(String event, dynamic payload) handler) {
    _anyListeners.add(handler);
  }

  @override
  void offAny(void Function(String event, dynamic payload) handler) {
    _anyListeners.remove(handler);
  }

  @override
  void onManagerEvent(String event, void Function(dynamic) handler) {
    on(event, handler);
  }

  @override
  void offManagerEvent(String event, void Function(dynamic) handler) {
    off(event, handler);
  }

  void trigger(String event, [dynamic payload]) {
    if (event == 'connect') connected = true;
    if (event == 'disconnect') connected = false;
    for (final listener in List.of(_listeners[event] ?? [])) {
      listener(payload);
    }
    for (final listener in List.of(_anyListeners)) {
      listener(event, payload);
    }
  }
}
