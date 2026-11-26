/// Card and account events already emitted by the backend.
///
/// Baccarat `dealCard` is `{cards:{player:{p1,p2,p3}, banker:{b1,b2,b3}}}`.
/// LONGHU `dealCard` is `{dragon, tiger}`. Empty slots are null.
/// Baccarat `deleteLastCard` is `{position}` with `p1`..`b3`.
class DeskCardSnapshot {
  const DeskCardSnapshot({
    required this.deskId,
    required this.kind,
    required this.slots,
  });

  const DeskCardSnapshot.empty(this.deskId)
    : kind = DeskCardKind.empty,
      slots = const {};

  final int deskId;
  final DeskCardKind kind;
  final Map<String, String?> slots;

  String? operator [](String slot) => slots[slot];

  /// Replaces the whole hand. Slots from the previous snapshot are not kept.
  factory DeskCardSnapshot.fromDeal(int deskId, Object? payload) {
    if (payload is! Map) {
      throw const FormatException('dealCard payload must be an object');
    }
    if (payload.containsKey('cards')) {
      final cards = payload['cards'];
      if (cards is! Map) {
        throw const FormatException('dealCard cards must be an object');
      }
      final player = cards['player'] is Map ? cards['player'] as Map : const {};
      final banker = cards['banker'] is Map ? cards['banker'] as Map : const {};
      return DeskCardSnapshot(
        deskId: deskId,
        kind: DeskCardKind.baccarat,
        slots: {
          'p1': _cardCode(player['p1']),
          'p2': _cardCode(player['p2']),
          'p3': _cardCode(player['p3']),
          'b1': _cardCode(banker['b1']),
          'b2': _cardCode(banker['b2']),
          'b3': _cardCode(banker['b3']),
        },
      );
    }
    if (payload.containsKey('dragon') || payload.containsKey('tiger')) {
      return DeskCardSnapshot(
        deskId: deskId,
        kind: DeskCardKind.longhu,
        slots: {
          'dragon': _cardCode(payload['dragon']),
          'tiger': _cardCode(payload['tiger']),
        },
      );
    }
    throw const FormatException('dealCard payload is missing cards');
  }

  /// Clears one Baccarat slot. LONGHU undo is a new `dealCard`, not this event.
  DeskCardSnapshot deleteLast(String? position) {
    const slots = {'p1', 'p2', 'p3', 'b1', 'b2', 'b3'};
    if (position == null || !slots.contains(position)) {
      throw FormatException('deleteLastCard position is invalid: $position');
    }
    if (kind != DeskCardKind.baccarat) return this;
    return DeskCardSnapshot(
      deskId: deskId,
      kind: kind,
      slots: {...this.slots, position: null},
    );
  }
}

enum DeskCardKind { empty, baccarat, longhu }

class MemberBalanceChange {
  const MemberBalanceChange({required this.userId, required this.balance});

  final int userId;
  final num balance;

  factory MemberBalanceChange.fromPayload(Object? payload) {
    if (payload is! Map) {
      throw const FormatException('member_balance:change payload must be an object');
    }
    final userId = _asInt(payload['userId']);
    final balance = _asNum(payload['balance']);
    if (userId == null || balance == null) {
      throw const FormatException(
        'member_balance:change payload is missing userId or balance',
      );
    }
    return MemberBalanceChange(userId: userId, balance: balance);
  }
}

class MemberForceLogout {
  const MemberForceLogout({
    required this.userId,
    this.reason,
    this.supersededIp,
    this.tokenVersion,
  });

  final int userId;
  final String? reason;
  final String? supersededIp;
  final int? tokenVersion;

  factory MemberForceLogout.fromPayload(Object? payload) {
    if (payload is Map) {
      final userId = _asInt(payload['userId']);
      if (userId == null) {
        throw const FormatException(
          'online_player:force_logout payload is missing userId',
        );
      }
      return MemberForceLogout(
        userId: userId,
        reason: payload['reason']?.toString(),
        supersededIp: payload['supersededIp']?.toString(),
        tokenVersion: _asInt(payload['tokenVersion']),
      );
    }
    final userId = _asInt(payload);
    if (userId == null) {
      throw const FormatException(
        'online_player:force_logout payload is missing userId',
      );
    }
    return MemberForceLogout(userId: userId);
  }
}

String? _cardCode(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return text;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}
