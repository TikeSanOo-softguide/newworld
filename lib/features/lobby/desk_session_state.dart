/// Whether the list page should keep the 洗牌中... overlay.
///
/// `GET /api/user/desks` returns `last_round` as the latest [GameRound] row
/// (`id`, `session_id`, `round_no`, `status`, `cards`). Outcome history is the
/// sibling `results` array (`round_id`, `key`, `round_no`), built from
/// RoundResult rows. That array is not nested inside `last_round`.
///
/// An active session stays shuffling until `results` has a recorded outcome.
/// A round id by itself does not remove the overlay.
bool deskIsShuffling(Object? desk) {
  if (desk is! Map) return false;
  final session = desk['session'];
  if (session is! Map) return false;

  final round = desk['last_round'];
  if (round is! Map) return true;

  final roundId = _asInt(round['id']);
  if (roundId == null || roundId <= 0) return true;

  final sessionId = _asInt(session['id']);
  final roundSessionId = _asInt(round['session_id']);
  if (sessionId != null &&
      roundSessionId != null &&
      roundSessionId != sessionId) {
    return true;
  }

  return !_hasRecordedResults(desk['results']);
}

/// Desk-level outcomes only. A `results` field on `last_round` is not part of
/// the desks response and is ignored.
bool _hasRecordedResults(Object? results) {
  if (results is! List) return false;
  for (final item in results) {
    if (item is! Map) continue;
    final key = item['key']?.toString().trim() ?? '';
    if (key.isNotEmpty) return true;
  }
  return false;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
