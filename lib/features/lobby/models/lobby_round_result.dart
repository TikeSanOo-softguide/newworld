class LobbyRoundResult {
  const LobbyRoundResult({
    required this.deskId,
    required this.roundId,
    required this.key,
    this.roundNo,
    this.netAmounts = const {},
  });

  final int deskId;
  final int roundId;
  final String key;
  final int? roundNo;

  /// `user_id` to `net_amount` from a socket result. HTTP history has none.
  /// This is not written into [toApiJson].
  final Map<int, num> netAmounts;

  factory LobbyRoundResult.fromApi(int deskId, Object? value) {
    if (value is! Map) {
      throw const FormatException('Round result must be an object');
    }
    final roundId = _asInt(value['round_id']);
    final key = value['key']?.toString().trim() ?? '';
    if (roundId == null || roundId <= 0 || key.isEmpty) {
      throw const FormatException('Round result is missing round_id or key');
    }
    return LobbyRoundResult(
      deskId: deskId,
      roundId: roundId,
      key: key,
      roundNo: _asInt(value['round_no']),
    );
  }

  factory LobbyRoundResult.fromSocket(int deskId, Object? value) {
    if (value is! Map) {
      throw const FormatException('Socket result must be an object');
    }
    final roundId = _asInt(value['round_id']);
    final result = value['result']?.toString().trim() ?? '';
    if (roundId == null || roundId <= 0 || result.isEmpty) {
      throw const FormatException(
        'Socket result is missing round_id or result',
      );
    }
    return LobbyRoundResult(
      deskId: deskId,
      roundId: roundId,
      key: result,
      netAmounts: _netAmounts(value['userNetAmounts']),
    );
  }

  Map<String, Object?> toApiJson() => {
    'round_id': roundId,
    'key': key,
    if (roundNo != null) 'round_no': roundNo,
  };
}

List<LobbyRoundResult> mergeLobbyRoundResults(
  Iterable<LobbyRoundResult> existing,
  Iterable<LobbyRoundResult> incoming,
) {
  final byRoundId = <int, LobbyRoundResult>{
    for (final result in existing) result.roundId: result,
    for (final result in incoming) result.roundId: result,
  };
  final merged = byRoundId.values.toList()
    ..sort((a, b) => a.roundId.compareTo(b.roundId));
  return List.unmodifiable(merged);
}

Map<int, num> _netAmounts(Object? value) {
  if (value is! List) return const {};
  final amounts = <int, num>{};
  for (final row in value) {
    if (row is! Map) continue;
    final userId = _asInt(row['user_id']);
    final net = row['net_amount'];
    if (userId == null || net is! num) continue;
    amounts[userId] = net;
  }
  return Map.unmodifiable(amounts);
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
