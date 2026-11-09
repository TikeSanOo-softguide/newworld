import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/game_detail/baccarat_detail_models.dart';
import 'package:newsworld/features/game_detail/camera_playback.dart';

void main() {
  test('parses a Baccarat desk and its initial results', () {
    final desk = BaccaratDeskDetail.fromJson({
      'id': 4,
      'game_id': 2,
      'name': 'A1',
      'min_bet': 100,
      'max_bet': 50000,
      'single_camera_flg': 1,
      'session': {'id': 8},
      'last_round': {'id': 12, 'status': 'betting'},
      'game': {'name': '百家乐', 'type': 'BACCARAT'},
      'results': [
        {'round_id': 9, 'key': 'banker', 'round_no': 9},
      ],
    });

    expect(desk.id, 4);
    expect(desk.gameId, 2);
    expect(desk.sessionId, 8);
    expect(desk.lastRoundId, 12);
    expect(desk.singleCamera, isTrue);
    expect(desk.results.single.key, 'banker');
  });

  test('parses actual result ids and ratios from the backend', () {
    final option = BaccaratResultOption.fromJson({
      'id': 31,
      'key': 'banker',
      'name': '庄',
      'ratio': '0.95',
      'position': 1,
    });

    expect(option.id, 31);
    expect(option.key, 'banker');
    expect(option.ratio, 0.95);
  });

  test('parses round status and confirmed bets from API envelopes', () {
    final status = BaccaratRoundStatus.fromApi({
      'data': {
        'lastRound': {'status': 'betting'},
        'remaining_seconds': 24,
      },
    });
    final bets = BaccaratConfirmedBets.fromApi({
      'data': {
        'confirmedBets': {
          'banker': {'result_id': 31, 'amount': 100, 'image': '/coin.png'},
        },
        'totalBetAmount': 100,
      },
    });

    expect(status.isBetting, isTrue);
    expect(status.remainingSeconds, 24);
    expect(bets.totalAmount, 100);
    expect(bets.byResultKey['banker']?.resultId, 31);
  });

  test('parses member and desk result limits from verified API fields', () {
    final profile = BaccaratMemberProfile.fromApi({
      'data': {
        'user': {
          'balance': 900,
          'userRateLimits': [
            {
              'resultRateLimit': {
                'result_id': 31,
                'min_bet': 100,
                'max_bet': 10000,
              },
            },
          ],
        },
      },
    });
    final desk = BaccaratDeskDetail.fromJson({
      'id': 4,
      'game_id': 2,
      'name': 'A1',
      'rate_limit_flg': true,
      'deskResultRateLimits': [
        {
          'result_id': 31,
          'status': 'online_betting_limit',
          'min_bet': 200,
          'max_bet': 5000,
        },
        {
          'result_id': 31,
          'status': 'phone_bet_limit',
          'min_bet': 500,
          'max_bet': 1000,
        },
      ],
      'last_round': {'id': 12, 'round_no': 7},
      'game': {'type': 'BACCARAT'},
    });

    expect(profile.balance, 900);
    expect(profile.resultRateLimits[31]?.minBet, 100);
    expect(profile.resultRateLimits[31]?.maxBet, 10000);
    expect(desk.lastRoundNo, 7);
    expect(desk.rateLimitEnabled, isTrue);
    expect(desk.deskResultRateLimits, hasLength(1));
    expect(desk.deskResultRateLimits[31]?.maxBet, 5000);
  });

  test('projects ledger rows using backend field names', () {
    final entry = BaccaratLedgerEntry.fromJson({
      'id': 7,
      'desk_name': 'A1',
      'actual_round_results': '庄',
      'bet_name': '庄',
      'betting_amount': 500,
      'betting_time': '2026-11-06 10:00:00',
      'remaining_amount': 1500,
    });

    expect(entry.deskName, 'A1');
    expect(entry.result, '庄');
    expect(entry.amount, 500);
    expect(entry.remainingAmount, 1500);
    expect(entry.createdAt, '2026-11-06 10:00:00');
  });

  test('creates an approved camera proxy URL without forwarding user info', () {
    final camera = BaccaratCameraFeed.fromJson({
      'id': 2,
      'desk_id': 4,
      'camera_no': 'A',
      'position': 1,
      'url': 'http://camera-user:camera-pass@camera.example.test:8080/hls/live/index.m3u8?channel=1',
      'account': 'must-not-be-used',
      'password': 'must-not-be-used',
    });

    final proxy = proxyHlsCameraUri(
      apiBaseUrl: 'https://api.example.test/api',
      camera: camera,
    );

    expect(
      proxy.toString(),
      'https://api.example.test/api/public/user/camera-proxy/http/'
      'camera.example.test%3A8080/hls/live/index.m3u8?channel=1',
    );
    expect(proxy?.userInfo, isEmpty);
  });

  test('does not proxy unsupported camera protocols or paths', () {
    final camera = BaccaratCameraFeed.fromJson({
      'id': 2,
      'desk_id': 4,
      'url': 'rtsp://camera.example.test/stream',
    });

    expect(
      proxyHlsCameraUri(
        apiBaseUrl: 'https://api.example.test/api',
        camera: camera,
      ),
      isNull,
    );
  });
}
