import '../lobby/models/lobby_round_result.dart';
import '../lobby/realtime/live_table_events.dart';
import '../lobby/realtime/lobby_socket_service.dart';

/// Events that arrive while a detail-page HTTP load is in progress.
///
/// Only the newest load may mark them consumed. A superseded load leaves
/// them in the buffer for that newer load.
class DetailSyncBuffer {
  final List<SyncBufferedEvent> _events = [];
  final Set<int> _profilesReady = {};
  int _nextId = 0;
  bool gating = false;
  bool replaying = false;

  bool get holdLiveEvents => gating || replaying;

  bool get hasUnconsumed => _events.any((event) => !event.consumed);

  void markProfileReady(int generation) {
    _profilesReady.add(generation);
  }

  bool profileReady(int generation) => _profilesReady.contains(generation);

  void addResult(LobbyRoundResult result) => _add(
    SyncBufferedEvent.result(id: _nextId++, result: result),
  );

  void addCards(DeskCardSnapshot snapshot) => _add(
    SyncBufferedEvent.cards(id: _nextId++, snapshot: snapshot),
  );

  void addBalance(MemberBalanceChange change) => _add(
    SyncBufferedEvent.balance(
      id: _nextId++,
      change: change,
      profilesReady: Set<int>.of(_profilesReady),
    ),
  );

  void addTimer(int seconds) => _add(
    SyncBufferedEvent.timer(id: _nextId++, seconds: seconds),
  );

  void addStatus(String status) => _add(
    SyncBufferedEvent.status(id: _nextId++, status: status),
  );

  void addPool(LobbyDeskPoolTotalsUpdate update) => _add(
    SyncBufferedEvent.pool(id: _nextId++, pool: update),
  );

  void addShoeFinished() => _add(SyncBufferedEvent.shoe(id: _nextId++));

  void _add(SyncBufferedEvent event) {
    _events.add(event);
  }

  /// Applies each unconsumed event once. Events added by [apply] are drained
  /// in later passes and are not treated as live input.
  void drain(void Function(SyncBufferedEvent event) apply) {
    replaying = true;
    try {
      while (true) {
        final batch = _events.where((event) => !event.consumed).toList();
        if (batch.isEmpty) return;
        for (final event in batch) {
          event.consumed = true;
          apply(event);
        }
      }
    } finally {
      replaying = false;
    }
  }
}

class SyncBufferedEvent {
  SyncBufferedEvent.result({required this.id, required this.result})
    : kind = SyncEventKind.result,
      cards = null,
      balance = null,
      profilesReady = const {},
      seconds = null,
      status = null,
      pool = null;

  SyncBufferedEvent.cards({
    required this.id,
    required DeskCardSnapshot snapshot,
  }) : kind = SyncEventKind.cards,
       result = null,
       cards = snapshot,
       balance = null,
       profilesReady = const {},
       seconds = null,
       status = null,
       pool = null;

  SyncBufferedEvent.balance({
    required this.id,
    required MemberBalanceChange change,
    required Set<int> profilesReady,
  }) : kind = SyncEventKind.balance,
       result = null,
       cards = null,
       balance = change,
       profilesReady = Set<int>.unmodifiable(profilesReady),
       seconds = null,
       status = null,
       pool = null;

  SyncBufferedEvent.timer({required this.id, required this.seconds})
    : kind = SyncEventKind.timer,
      result = null,
      cards = null,
      balance = null,
      profilesReady = const {},
      status = null,
      pool = null;

  SyncBufferedEvent.status({required this.id, required this.status})
    : kind = SyncEventKind.status,
      result = null,
      cards = null,
      balance = null,
      profilesReady = const {},
      seconds = null,
      pool = null;

  SyncBufferedEvent.pool({required this.id, required this.pool})
    : kind = SyncEventKind.pool,
      result = null,
      cards = null,
      balance = null,
      profilesReady = const {},
      seconds = null,
      status = null;

  SyncBufferedEvent.shoe({required this.id})
    : kind = SyncEventKind.shoe,
      result = null,
      cards = null,
      balance = null,
      profilesReady = const {},
      seconds = null,
      status = null,
      pool = null;

  final int id;
  final SyncEventKind kind;
  final LobbyRoundResult? result;
  final DeskCardSnapshot? cards;
  final MemberBalanceChange? balance;

  /// Profile generations that had already completed when this balance arrived.
  final Set<int> profilesReady;
  final int? seconds;
  final String? status;
  final LobbyDeskPoolTotalsUpdate? pool;
  bool consumed = false;
}

enum SyncEventKind { result, cards, balance, timer, status, pool, shoe }

/// Newest-load gate. An older generation cannot close the gate or commit.
class DetailSyncGate {
  int _newest = 0;

  int get newest => _newest;

  int begin() {
    _newest += 1;
    return _newest;
  }

  bool isCurrent(int generation) => generation == _newest;
}

/// A failed load keeps the hand already on screen. A successful load keeps
/// it only when the session and round are still the same.
bool keepDisplayedCards({
  required bool httpCommitted,
  required bool sameRound,
}) {
  if (!httpCommitted) return true;
  return sameRound;
}

/// Whether buffered cards belong to the hand already on screen.
///
/// Card payloads have no round id. A changed session or round means those
/// events cannot be attached safely, so they must not be shown.
bool cardsBelongToDisplayedRound({
  required bool hasDisplayedRound,
  required int? displayedSessionId,
  required int? displayedRoundId,
  required int? httpSessionId,
  required int? httpRoundId,
}) {
  if (!hasDisplayedRound) return true;
  return displayedSessionId == httpSessionId && displayedRoundId == httpRoundId;
}

/// Applies buffered results after [base]. Identical round and result is skipped.
List<LobbyRoundResult> reconcileResults({
  required List<LobbyRoundResult> base,
  required List<LobbyRoundResult> incoming,
}) {
  var results = base;
  for (final result in incoming) {
    final same = results.where((existing) => existing.roundId == result.roundId);
    if (same.length == 1 && same.first.key == result.key) continue;
    results = mergeLobbyRoundResults(results, [result]);
  }
  return results;
}
