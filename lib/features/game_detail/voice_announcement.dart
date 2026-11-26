/// One local clip chosen the way the member website chooses it.
class VoiceCue {
  const VoiceCue(this.asset);

  /// Path relative to the Flutter asset bundle, under `assets/`.
  final String asset;
}

const _startBetting = VoiceCue('voices/start-betting.mp3');
const _stopBetting = VoiceCue('voices/stop-betting.mp3');
const _tenSeconds = VoiceCue('voices/betting-10-seconds.mp3');

/// Website `getWinResultVoiceSrc`. The first matching combination wins.
VoiceCue? voiceCueForResult(String gameType, String result) {
  final winners = result
      .split('|')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (winners.isEmpty) return null;
  final type = gameType.toUpperCase();
  if (type == 'LONGHU') {
    if (winners.contains('dragon')) {
      return const VoiceCue('voices/dragon-win.mp3');
    }
    if (winners.contains('tiger')) {
      return const VoiceCue('voices/tiger-win.mp3');
    }
    if (winners.contains('tie')) return const VoiceCue('voices/tie-win.mp3');
    return null;
  }
  if (type != 'BACCARAT') return null;
  final banker = winners.contains('banker');
  final player = winners.contains('player');
  final bankerPair = winners.contains('bankerPair');
  final playerPair = winners.contains('playerPair');
  final tie = winners.contains('tie');
  if (banker) {
    if (bankerPair && playerPair) {
      return const VoiceCue('voices/banker-banker-player-pair-win.mp3');
    }
    if (bankerPair) return const VoiceCue('voices/banker-banker-pair-win.mp3');
    if (playerPair) return const VoiceCue('voices/banker-player-pair-win.mp3');
    return const VoiceCue('voices/banker-win.mp3');
  }
  if (player) {
    if (bankerPair && playerPair) {
      return const VoiceCue('voices/player-banker-player-pair-win.mp3');
    }
    if (playerPair) {
      return const VoiceCue('voices/player-plyaer-pair-win.mp3');
    }
    if (bankerPair) return const VoiceCue('voices/player-banker-pair-win.mp3');
    return const VoiceCue('voices/player-win.mp3');
  }
  if (tie) {
    if (bankerPair && playerPair) {
      return const VoiceCue('voices/tie-banker-player-pair-win.mp3');
    }
    if (bankerPair) return const VoiceCue('voices/tie-banker-pair-win.mp3');
    if (playerPair) return const VoiceCue('voices/tie-player-pair-win.mp3');
    return const VoiceCue('voices/tie-win.mp3');
  }
  return null;
}

/// Remembers the website's "already heard" state for one open table.
///
/// A new clip is returned only when the website would start one. The caller
/// plays it. Nothing is queued here.
class VoiceAnnouncer {
  VoiceAnnouncer({this.enabled = true});

  bool enabled;

  int? _deskId;
  bool _primed = false;
  String? _status;
  int? _previousSeconds;
  bool _tenPlayed = false;
  int? _roundId;
  final Set<int> _announcedRounds = <int>{};

  void bindDesk(int deskId) {
    if (_deskId == deskId) return;
    _deskId = deskId;
    _primed = false;
    _status = null;
    _previousSeconds = null;
    _tenPlayed = false;
    _roundId = null;
    _announcedRounds.clear();
  }

  /// The website clears the 10-second latch and result memory when the
  /// displayed round id changes.
  void onDisplayedRound(int? roundId) {
    if (roundId == _roundId) return;
    _roundId = roundId;
    _previousSeconds = null;
    _tenPlayed = false;
    _announcedRounds.clear();
  }

  VoiceCue? onStatus(String status) {
    if (!_primed) {
      _primed = true;
      _status = status;
      return null;
    }
    final previous = _status;
    _status = status;
    if (!enabled) return null;
    if (status == 'betting' && previous != 'betting') {
      _tenPlayed = false;
      _previousSeconds = null;
      return _startBetting;
    }
    if (status == 'dealing' && previous != 'dealing') return _stopBetting;
    return null;
  }

  VoiceCue? onTimer({required String status, required int seconds}) {
    if (status != 'betting' || !enabled) {
      _previousSeconds = seconds;
      return null;
    }
    final previous = _previousSeconds;
    _previousSeconds = seconds;
    final reachedTen = seconds == 10 && (previous == null || previous > 10);
    if (reachedTen && !_tenPlayed) {
      _tenPlayed = true;
      return _tenSeconds;
    }
    return null;
  }

  VoiceCue? onResult({
    required String gameType,
    required int roundId,
    required String result,
  }) {
    if (_announcedRounds.contains(roundId)) return null;
    // The website returns before remembering the round, so a later repeat
    // after the speaker is turned on can still play. Turning the speaker
    // on does not itself emit this event.
    if (!enabled) return null;
    final cue = voiceCueForResult(gameType, result);
    if (cue == null) return null;
    _announcedRounds.add(roundId);
    return cue;
  }
}
