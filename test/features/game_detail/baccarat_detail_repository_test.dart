import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:newsworld/core/network/api_client.dart';
import 'package:newsworld/features/game_detail/baccarat_detail_repository.dart';

void main() {
  test(
    'uses the existing authenticated detail and betting API contracts',
    () async {
      final client = _BackendFixtureClient();
      final repository = BaccaratDetailRepository(
        ApiClient(client: client, baseUrl: 'https://api.example.test/api'),
      );

      final desk = await repository.getDesk(4, 'member-jwt');
      final options = await repository.getResultOptions(4, 'member-jwt');
      final status = await repository.getRoundStatus(4, 'member-jwt');
      final confirmed = await repository.getConfirmedBets(12, 'member-jwt');
      final pools = await repository.getPoolTotals(12, 'member-jwt');
      final profile = await repository.getProfile('member-jwt');
      final ledger = await repository.getLedger(
        token: 'member-jwt',
        date: DateTime(2026, 11, 6),
      );
      final submitted = await repository.submitBets(
        lastRoundId: 12,
        bets: const [
          BaccaratBetSubmissionItem(
            resultId: 31,
            amount: 100,
            image: '/images/coins/100chip.png',
          ),
        ],
        token: 'member-jwt',
        csrfToken: 'csrf-token',
      );
      await repository.cancelBets(
        lastRoundId: 12,
        token: 'member-jwt',
        csrfToken: 'csrf-token',
      );

      expect(desk.id, 4);
      expect(options.single.ratio, 0.95);
      expect(status.remainingSeconds, 20);
      expect(confirmed.totalAmount, 100);
      expect(pools.displayTotals['banker'], 300);
      expect(profile.balance, 900);
      expect(ledger.single.amount, 100);
      expect(submitted.remainingBalance, 800);

      final requests = client.requests;
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'GET /api/user/desks',
          'GET /api/user/results_by_desk/4',
          'GET /api/user/last_round_status/4',
          'GET /api/user/confirm_bets/12',
          'GET /api/user/round_pool_totals/12',
          'GET /api/user/profile',
          'GET /api/user/member_ledger',
          'POST /api/user/bet_results',
          'POST /api/user/cancle_bet_results',
        ],
      );
      expect(requests.first.url.queryParameters, {'site_name': 'user'});
      expect(requests[6].url.queryParameters, {
        'startDate': '2026-11-06',
        'endDate': '2026-11-06',
        'page': '1',
        'limit': '20',
      });
      final betBody = jsonDecode((requests[7] as http.Request).body) as Map;
      expect(betBody['last_round'], 12);
      expect(betBody['bets'], [
        {'result_id': 31, 'amount': 100, 'image': '/images/coins/100chip.png'},
      ]);
      expect(
        (requests[7] as http.Request).headers['x-csrf-token'],
        'csrf-token',
      );
      expect(jsonDecode((requests[8] as http.Request).body), {
        'last_round': 12,
      });
    },
  );

  test('does not treat an unsuccessful HTTP 200 bet response as success', () {
    final repository = BaccaratDetailRepository(
      ApiClient(
        client: _FailedActionClient(),
        baseUrl: 'https://api.example.test/api',
      ),
    );

    expect(
      repository.submitBets(
        lastRoundId: 12,
        bets: const [
          BaccaratBetSubmissionItem(
            resultId: 31,
            amount: 100,
            image: '/images/coins/100chip.png',
          ),
        ],
        token: 'member-jwt',
        csrfToken: 'csrf-token',
      ),
      throwsA(
        isA<BaccaratActionException>().having(
          (error) => error.message,
          'message',
          'Bet was rejected',
        ),
      ),
    );
  });
}

class _BackendFixtureClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = switch (request.url.path) {
      '/api/user/desks' => {
        'data': {
          'desks': [
            {
              'id': 4,
              'game_id': 2,
              'name': 'A1',
              'min_bet': 100,
              'max_bet': 50000,
              'last_round': {'id': 12},
              'session': {'id': 3},
              'game': {'type': 'BACCARAT', 'name': '百家乐'},
              'results': [
                {'round_id': 10, 'key': 'banker'},
              ],
            },
          ],
        },
      },
      '/api/user/results_by_desk/4' => {
        'data': {
          'results': [
            {
              'id': 31,
              'key': 'banker',
              'name': '庄',
              'ratio': '0.95',
              'position': 1,
            },
          ],
        },
      },
      '/api/user/last_round_status/4' => {
        'data': {
          'lastRound': {'status': 'betting'},
          'remaining_seconds': 20,
        },
      },
      '/api/user/confirm_bets/12' => {
        'data': {
          'confirmedBets': {
            'banker': {'result_id': 31, 'amount': 100},
          },
          'totalBetAmount': 100,
        },
      },
      '/api/user/round_pool_totals/12' => {
        'data': {
          'round_id': 12,
          'pool_type': 'baccarat',
          'totals': {'banker': 300},
          'display_totals': {'banker': 300},
        },
      },
      '/api/user/profile' => {
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
      },
      '/api/user/member_ledger' => {
        'data': {
          'memberReports': [
            {
              'id': 1,
              'desk_name': 'A1',
              'betting_amount': 100,
              'actual_round_results': '庄',
              'betting_time': '2026-11-06 10:00:00',
              'remaining_amount': 900,
            },
          ],
        },
      },
      '/api/user/bet_results' => {
        'success': true,
        'data': {
          'totalBetAmount': 200,
          'remainingBalance': 800,
          'confirmedBets': {
            'banker': {'result_id': 31, 'amount': 200},
          },
        },
      },
      '/api/user/cancle_bet_results' => {'success': true},
      _ => throw StateError('Unexpected API request: ${request.url}'),
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FailedActionClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode(
            jsonEncode({'success': false, 'message': 'Bet was rejected'}),
          ),
        ),
        200,
        headers: const {'content-type': 'application/json'},
      );
}
