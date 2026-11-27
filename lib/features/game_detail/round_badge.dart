/// Two-line result pill for the open desk.
///
/// The first line is the round outcome. The second line is this member's
/// net when they are in `userNetAmounts`, including zero. Absence means
/// they had no bet on the round.
class RoundResultPill {
  const RoundResultPill({
    required this.outcome,
    required this.detail,
    required this.detailIsNote,
  });

  final String outcome;
  final String detail;

  /// `本局未下注` is white. A numeric net is green.
  final bool detailIsNote;
}

const currentRoundNoBetNote = '本局未下注';

/// Outcome from the result key, then this member's net or [currentRoundNoBetNote].
///
/// A missing member id cannot tell absence from a not-yet-loaded profile,
/// so the pill waits. A present net of zero is shown as `0`.
RoundResultPill? memberRoundBadge({
  required String resultKey,
  required int? memberId,
  required Map<int, num> netAmounts,
  required bool longhu,
}) {
  final noun = _mainNoun(resultKey, longhu: longhu);
  if (noun == null || memberId == null) return null;
  final outcome = noun == '和' ? noun : '$noun赢';
  if (!netAmounts.containsKey(memberId)) {
    return RoundResultPill(
      outcome: outcome,
      detail: currentRoundNoBetNote,
      detailIsNote: true,
    );
  }
  return RoundResultPill(
    outcome: outcome,
    detail: _amount(netAmounts[memberId]!),
    detailIsNote: false,
  );
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
