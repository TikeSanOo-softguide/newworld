import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/game_detail/baccarat_bet_validation.dart';
import 'package:newsworld/features/game_detail/baccarat_detail_models.dart';

void main() {
  const desk = BaccaratDeskDetail(
    id: 4,
    gameId: 2,
    name: 'A1',
    gameName: '百家乐',
    minBet: 1000,
    maxBet: 50000,
    sessionId: 1,
    lastRoundId: 12,
    lastRoundNo: 7,
    singleCamera: false,
    rateLimitEnabled: false,
    deskResultRateLimits: {},
    results: [],
  );
  const options = [
    BaccaratResultOption(
      id: 31,
      key: 'banker',
      name: '庄',
      ratio: 0.95,
      position: 1,
    ),
    BaccaratResultOption(
      id: 32,
      key: 'player',
      name: '闲',
      ratio: 1,
      position: 2,
    ),
    BaccaratResultOption(id: 33, key: 'tie', name: '和', ratio: 8, position: 3),
  ];

  test('does not treat table range minimum as a per-position minimum', () {
    final error = validateBaccaratBetBatch(
      desk: desk,
      options: options,
      confirmedBets: const {},
      pendingBets: const {31: 100},
      memberLimits: const {},
      roundPoolTotals: const {},
      roundPoolTotalsAvailable: false,
      balance: 1000,
    );

    expect(error, isNull);
  });

  test('enforces member min/max against pending plus confirmed bets', () {
    final limits = {31: const BaccaratBetLimit(minBet: 200, maxBet: 500)};
    final tooSmall = validateBaccaratBetBatch(
      desk: desk,
      options: options,
      confirmedBets: const {},
      pendingBets: const {31: 100},
      memberLimits: limits,
      roundPoolTotals: const {},
      roundPoolTotalsAvailable: false,
      balance: 1000,
    );
    final tooLarge = validateBaccaratBetBatch(
      desk: desk,
      options: options,
      confirmedBets: const {
        'banker': BaccaratConfirmedBet(resultId: 31, amount: 400, image: ''),
      },
      pendingBets: const {31: 200},
      memberLimits: limits,
      roundPoolTotals: const {},
      roundPoolTotalsAvailable: false,
      balance: 1000,
    );

    expect(tooSmall, '超过用户限额，下注失败');
    expect(tooLarge, '超过用户限额，下注失败');
  });

  test(
    'validates pool exposure using confirmed pool totals and pending bets',
    () {
      final deskWithLimits = BaccaratDeskDetail(
        id: desk.id,
        gameId: desk.gameId,
        name: desk.name,
        gameName: desk.gameName,
        minBet: desk.minBet,
        maxBet: desk.maxBet,
        sessionId: desk.sessionId,
        lastRoundId: desk.lastRoundId,
        lastRoundNo: desk.lastRoundNo,
        singleCamera: desk.singleCamera,
        rateLimitEnabled: true,
        deskResultRateLimits: const {
          31: BaccaratBetLimit(minBet: 0, maxBet: 500),
          32: BaccaratBetLimit(minBet: 0, maxBet: 500),
          33: BaccaratBetLimit(minBet: 0, maxBet: 500),
        },
        results: desk.results,
      );

      final guestLimitError = validateBaccaratBetBatch(
        desk: deskWithLimits,
        options: options,
        confirmedBets: const {},
        pendingBets: const {31: 600},
        memberLimits: const {},
        roundPoolTotals: const {'banker': 5000, 'player': 4900},
        roundPoolTotalsAvailable: true,
        balance: 10000,
      );
      final stalePoolResult = validateBaccaratBetBatch(
        desk: deskWithLimits,
        options: options,
        confirmedBets: const {},
        pendingBets: const {31: 600},
        memberLimits: const {},
        roundPoolTotals: const {},
        roundPoolTotalsAvailable: false,
        balance: 10000,
      );

      expect(guestLimitError, '超过台面限额，下注失败');
      expect(stalePoolResult, isNull);
    },
  );

  test('rejects batches exceeding balance or desk-wide maximum', () {
    expect(
      validateBaccaratBetBatch(
        desk: desk,
        options: options,
        confirmedBets: const {},
        pendingBets: const {31: 1200},
        memberLimits: const {},
        roundPoolTotals: const {},
        roundPoolTotalsAvailable: false,
        balance: 1000,
      ),
      '余额不足，下注失败',
    );

    expect(
      validateBaccaratBetBatch(
        desk: desk,
        options: options,
        confirmedBets: const {},
        pendingBets: const {31: 20000},
        memberLimits: const {},
        roundPoolTotals: const {'player': 35000},
        roundPoolTotalsAvailable: true,
        balance: 50000,
      ),
      '超过台面限额，下注失败',
    );
  });

  test(
    'does not use a previous round pool total after synchronization failed',
    () {
      final validationDesk = BaccaratDeskDetail(
        id: desk.id,
        gameId: desk.gameId,
        name: desk.name,
        gameName: desk.gameName,
        minBet: desk.minBet,
        maxBet: desk.maxBet,
        sessionId: desk.sessionId,
        lastRoundId: desk.lastRoundId,
        lastRoundNo: desk.lastRoundNo,
        singleCamera: desk.singleCamera,
        rateLimitEnabled: false,
        deskResultRateLimits: const {},
        results: desk.results,
      );
      final confirmed = {
        'player': const BaccaratConfirmedBet(
          resultId: 32,
          amount: 100,
          image: '',
        ),
      };

      expect(
        validateBaccaratBetBatch(
          desk: validationDesk,
          options: options,
          confirmedBets: confirmed,
          pendingBets: const {31: 100},
          memberLimits: const {},
          roundPoolTotals: const {'banker': 50000, 'player': 50000},
          roundPoolTotalsAvailable: false,
          balance: 1000,
        ),
        isNull,
      );
    },
  );
}
