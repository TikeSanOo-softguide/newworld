/// One countdown for a desk.
///
/// Socket ticks are the clock while a round is betting. HTTP replaces that
/// clock after a load or reconnect. A local ticker must not also decrement it.
class DeskBettingClock {
  const DeskBettingClock({
    this.status,
    this.remainingSeconds = 0,
    this.acceptNextTimer = false,
  });

  final String? status;
  final int remainingSeconds;

  /// The next timer after a `betting` status is the new round's countdown.
  final bool acceptNextTimer;

  bool get isBetting => status == 'betting';

  /// [status] `betting` arms the following timer as a round reset.
  /// Any other status clears the countdown.
  DeskBettingClock applyStatus(String status) {
    final betting = status == 'betting';
    return DeskBettingClock(
      status: status,
      remainingSeconds: betting ? remainingSeconds : 0,
      acceptNextTimer: betting,
    );
  }

  /// Returns null when [seconds] must not change the clock.
  ///
  /// Timers are ignored unless the status is `betting`. After the round
  /// reset, a later value higher than the current second is stale.
  DeskBettingClock? applyTimer(int seconds) {
    if (!isBetting) return null;
    final nextSeconds = seconds.clamp(0, 3600);
    if (acceptNextTimer || nextSeconds <= remainingSeconds) {
      return DeskBettingClock(
        status: status,
        remainingSeconds: nextSeconds,
        acceptNextTimer: false,
      );
    }
    return null;
  }

  /// HTTP is the clock after load and reconnect.
  ///
  /// A betting response allows one later upward tick. That covers the
  /// server subtracting elapsed time from the stored countdown. The
  /// following tick is protected by [applyTimer] again.
  DeskBettingClock applyHttp({
    required String status,
    required int remainingSeconds,
  }) {
    final betting = status == 'betting';
    return DeskBettingClock(
      status: status,
      remainingSeconds: betting ? remainingSeconds.clamp(0, 3600) : 0,
      acceptNextTimer: betting,
    );
  }
}

/// One buffered status or timer, in arrival order.
class BufferedClockSignal {
  const BufferedClockSignal.status(this.status) : seconds = null;

  const BufferedClockSignal.timer(this.seconds) : status = null;

  final String? status;
  final int? seconds;
}

/// HTTP `dealing` or `finished` must not be reopened by a buffered `betting`.
bool blocksBufferedBettingRestart(String? status) =>
    status == 'dealing' || status == 'finished';

/// Replays buffered signals onto the HTTP clock.
///
/// A `betting` signal is not applied when [httpClock] is already `dealing`
/// or `finished`. That keeps a stale betting event from reopening the round.
DeskBettingClock replayBufferedClock({
  required DeskBettingClock httpClock,
  required List<BufferedClockSignal> signals,
}) {
  final blockBettingRestart = blocksBufferedBettingRestart(httpClock.status);
  var clock = httpClock;
  for (final signal in signals) {
    final status = signal.status;
    if (status != null) {
      if (status == 'betting' && blockBettingRestart) continue;
      clock = clock.applyStatus(status);
      continue;
    }
    final seconds = signal.seconds;
    if (seconds == null) continue;
    final next = clock.applyTimer(seconds);
    if (next != null) clock = next;
  }
  return clock;
}
