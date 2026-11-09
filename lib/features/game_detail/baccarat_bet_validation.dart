import 'baccarat_detail_models.dart';

String? validateBaccaratBetBatch({
  required BaccaratDeskDetail desk,
  required List<BaccaratResultOption> options,
  required Map<String, BaccaratConfirmedBet> confirmedBets,
  required Map<int, num> pendingBets,
  required Map<int, BaccaratBetLimit> memberLimits,
  required Map<String, num> roundPoolTotals,
  required bool roundPoolTotalsAvailable,
  required num balance,
}) {
  final pendingTotal = pendingBets.values.fold<num>(0, (a, b) => a + b);
  if (pendingTotal > balance) return '余额不足，下注失败';

  final optionsById = {for (final option in options) option.id: option};
  final optionsByKey = {for (final option in options) option.key: option};
  for (final entry in pendingBets.entries) {
    final option = optionsById[entry.key];
    if (option == null) return '投注选项已失效，请刷新后重试';
    final limit = memberLimits[option.id];
    if (limit == null) continue;

    final totalForResult =
        entry.value + (confirmedBets[option.key]?.amount ?? 0);
    if (totalForResult < limit.minBet || totalForResult > limit.maxBet) {
      return '超过用户限额，下注失败';
    }
  }

  if (roundPoolTotalsAvailable && desk.rateLimitEnabled) {
    final merged = Map<String, num>.of(roundPoolTotals);
    for (final entry in pendingBets.entries) {
      final option = optionsById[entry.key]!;
      merged.update(
        option.key,
        (amount) => amount + entry.value,
        ifAbsent: () => entry.value,
      );
    }

    const guestPartners = {'player': 'banker', 'banker': 'player'};
    final checkedGuestPairs = <String>{};
    for (final entry in pendingBets.entries) {
      final option = optionsById[entry.key]!;
      final partner = guestPartners[option.key];
      if (partner != null) {
        final pair = [option.key, partner]..sort();
        final pairKey = pair.join('|');
        if (!checkedGuestPairs.add(pairKey)) continue;
        final resultId = optionsByKey[pair.first]?.id;
        final partnerId = optionsByKey[pair.last]?.id;
        final limit =
            desk.deskResultRateLimits[resultId] ??
            desk.deskResultRateLimits[partnerId];
        if (limit != null &&
            ((merged[option.key] ?? 0) - (merged[partner] ?? 0)).abs() >
                limit.maxBet) {
          return '超过台面限额，下注失败';
        }
      } else if (const {
        'tie',
        'playerPair',
        'bankerPair',
      }.contains(option.key)) {
        final limit = desk.deskResultRateLimits[option.id];
        if (limit != null && (merged[option.key] ?? 0) > limit.maxBet) {
          return '超过台面限额，下注失败';
        }
      }
    }
  }

  if (desk.maxBet > 0) {
    final confirmedRoundAmount = roundPoolTotalsAvailable
        ? roundPoolTotals.values.fold<num>(0, (a, b) => a + b)
        : confirmedBets.values.fold<num>(0, (a, bet) => a + bet.amount);
    final totalRoundAmount = confirmedRoundAmount + pendingTotal;
    if (totalRoundAmount > desk.maxBet) return '超过台面限额，下注失败';
  }
  return null;
}
