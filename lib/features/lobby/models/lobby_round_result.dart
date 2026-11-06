class LobbyRoundResult {
  const LobbyRoundResult({
    required this.deskId,
    required this.roundId,
    required this.key,
    this.roundNo,
  });

  final int deskId;
  final int roundId;
  final String key;
  final int? roundNo;

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
    return LobbyRoundResult(deskId: deskId, roundId: roundId, key: result);
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

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
