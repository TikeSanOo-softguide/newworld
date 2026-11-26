/// Badge text from this member's `userNetAmounts.net_amount`.
///
/// The noun is the main result token. The amount is not calculated here.
/// A loss keeps the minus sign. The recordings show wins only, so a loss
/// does not add an unverified verb.
String? memberRoundBadge({
  required String resultKey,
  required int? memberId,
  required Map<int, num> netAmounts,
  required bool longhu,
}) {
  if (memberId == null || !netAmounts.containsKey(memberId)) return null;
  final net = netAmounts[memberId]!;
  if (net == 0) return null;
  final noun = _mainNoun(resultKey, longhu: longhu);
  if (noun == null) return null;
  final amount = _amount(net);
  if (net > 0 && noun != '和') return '$noun赢 $amount';
  return '$noun $amount';
}

String? _mainNoun(String resultKey, {required bool longhu}) {
  const baccarat = {'player': '闲', 'banker': '庄', 'tie': '和'};
  const dragon = {'dragon': '龙', 'tiger': '虎', 'tie': '和'};
  final names = longhu ? dragon : baccarat;
  for (final token in resultKey.split('|')) {
    final noun = names[token.trim()];
    if (noun != null) return noun;
  }
  return null;
}

String _amount(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return '$value';
}
