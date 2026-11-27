import 'dart:async';

import 'package:flutter/foundation.dart';

/// One cross-desk result notice. The open desk's badge is a different value.
@immutable
class CrossDeskNotice {
  const CrossDeskNotice({
    required this.deskId,
    required this.roundId,
    required this.label,
    required this.netAmount,
    required this.generation,
  });

  final int deskId;
  final int roundId;
  final String label;
  final num netAmount;
  final int generation;

  CrossDeskBarContent get content =>
      crossDeskBarContent(label, netAmount);
}

/// Three parts of the betting-board bar. A zero net has no 赢额 or 输额.
class CrossDeskBarContent {
  const CrossDeskBarContent({
    required this.deskLabel,
    required this.verdict,
    required this.amount,
    required this.amountTone,
  });

  final String deskLabel;

  /// `赢额`, `输额`, or null when the net is zero.
  final String? verdict;
  final String amount;

  /// `win`, `loss`, or `zero`.
  final String amountTone;
}

/// Website `formatDeskBetResultLabel`: `{game.name}{desk_no}台`.
///
/// `desk_no` is preferred. The desk name is the fallback when a preload row
/// has no desk number. A name that already ends in 台 is not doubled.
String formatCrossDeskDeskLabel(Map<String, dynamic>? desk) {
  if (desk == null) return '台';
  final game = desk['game'];
  final gameName = game is Map ? game['name']?.toString() ?? '' : '';
  final number = (desk['desk_no'] ?? desk['name'])?.toString() ?? '';
  final body = '$gameName$number';
  if (body.isEmpty) return '台';
  return body.endsWith('台') ? body : '$body台';
}

/// Amount text for the bar and the pill. No leading plus.
///
/// Whole values drop the decimal. `47.5` stays `47.5`. The still that shows
/// `-50.00` is not a second rule, because `47.5` is not `47.50`.
String formatDeskResultAmount(num amount) {
  final value = amount.toDouble();
  if (!value.isFinite) return '0';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

CrossDeskBarContent crossDeskBarContent(String label, num netAmount) {
  if (netAmount > 0) {
    return CrossDeskBarContent(
      deskLabel: label,
      verdict: '赢额',
      amount: formatDeskResultAmount(netAmount),
      amountTone: 'win',
    );
  }
  if (netAmount < 0) {
    return CrossDeskBarContent(
      deskLabel: label,
      verdict: '输额',
      amount: formatDeskResultAmount(netAmount),
      amountTone: 'loss',
    );
  }
  return CrossDeskBarContent(
    deskLabel: label,
    verdict: null,
    amount: '0',
    amountTone: 'zero',
  );
}

/// One visible announcement. A newer accepted result replaces it.
///
/// [viewedDeskIds] is the member site's viewed set. This page puts the open
/// desk there. A multi-bet set is excluded the same way: every id in the set
/// is ignored, and an ignored result is not marked as already announced.
class CrossDeskAnnouncements {
  CrossDeskAnnouncements({
    required this.onChanged,
    this.displayDuration = const Duration(seconds: 5),
  });

  final VoidCallback onChanged;
  final Duration displayDuration;
  final Set<String> _seen = {};
  CrossDeskNotice? current;
  int _generation = 0;
  Timer? _timer;

  CrossDeskNotice? accept({
    required int deskId,
    required int roundId,
    required Set<int> viewedDeskIds,
    required int? memberId,
    required Map<int, num> netAmounts,
    required String label,
  }) {
    if (roundId <= 0 || viewedDeskIds.contains(deskId)) return null;
    if (memberId == null || !netAmounts.containsKey(memberId)) return null;
    final dedupeKey = '$deskId:$roundId';
    if (_seen.contains(dedupeKey)) return null;
    _seen.add(dedupeKey);
    final notice = CrossDeskNotice(
      deskId: deskId,
      roundId: roundId,
      label: label,
      netAmount: netAmounts[memberId]!,
      generation: ++_generation,
    );
    current = notice;
    _timer?.cancel();
    final generation = notice.generation;
    _timer = Timer(displayDuration, () {
      if (current?.generation != generation) return;
      current = null;
      onChanged();
    });
    onChanged();
    return notice;
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Confirmed stake totals keyed by desk id.
///
/// A request takes a ticket when it starts. Only the newest ticket for that
/// desk may write. [abandon] gives the ticket back when the request fails and
/// nothing newer has started, so an older read can still land. [clear]
/// invalidates in-flight reads and removes that desk only.
class DeskConfirmedStakeBook {
  final Map<int, num> amounts = {};
  final Map<int, int> _current = {};
  final Map<int, int> _previous = {};
  int _sequence = 0;

  int open(int deskId) {
    final ticket = ++_sequence;
    _previous[deskId] = _current[deskId] ?? 0;
    _current[deskId] = ticket;
    return ticket;
  }

  void abandon(int deskId, int ticket) {
    if (_current[deskId] != ticket) return;
    _current[deskId] = _previous[deskId] ?? 0;
  }

  bool apply(int deskId, num amount, int ticket) {
    if (_current[deskId] != ticket) return false;
    if (amount <= 0) {
      amounts.remove(deskId);
    } else {
      amounts[deskId] = amount;
    }
    return true;
  }

  /// Drops this desk's mark and rejects responses that started earlier.
  bool clear(int deskId) {
    final hadAmount = amounts.containsKey(deskId);
    open(deskId);
    amounts.remove(deskId);
    return hadAmount;
  }
}
