import 'package:flutter/painting.dart';

/// How long a status phrase stays on the roadmap bar.
///
/// The plan calls these toasts and does not record a measured duration.
/// Two seconds keeps the phrase readable without leaving it up for the
/// rest of the phase. `试玩中` is not part of this and is never replaced.
const detailStatusPhraseHold = Duration(seconds: 2);

/// Red used for every phrase except `开始押注`.
const detailStatusPhraseColor = Color(0xFFE02020);

/// Green used only for `开始押注`.
const detailStatusStartPhraseColor = Color(0xFF3DDC6A);

/// Green measured on `下注成功` in LONGHU_detail.mp4 at 94.0s.
/// `成功取消下注` uses the same green on the Baccarat recording at 00:28.
const detailBetSuccessPhraseColor = Color(0xFF25BD55);

/// 续投 refusals on the 2026-11-25 10:26 recording.
///
/// Both sit on the same roadmap band as the status phrases, in white, and
/// stay up for about three seconds. `开始押注` and `下注成功` keep their colors.
const alreadyBetRepeatNotice = '您已投注，不能续投';
const noPreviousBetNotice = '没有上一局的投注信息';
const detailRepeatNoticeColor = Color(0xFFFFFFFF);
const detailRepeatNoticeHold = Duration(seconds: 3);

bool detailRepeatNotice(String? phrase) =>
    phrase == alreadyBetRepeatNotice || phrase == noPreviousBetNotice;

Color detailStatusPhraseInk(String? phrase) {
  if (detailRepeatNotice(phrase)) return detailRepeatNoticeColor;
  if (phrase == '开始押注') return detailStatusStartPhraseColor;
  if (phrase == '下注成功' || phrase == '成功取消下注') {
    return detailBetSuccessPhraseColor;
  }
  return detailStatusPhraseColor;
}

/// Phrases for the committed HTTP clock and later live transitions.
///
/// The first successful HTTP commit presents the current status. A later
/// reload of that same phase, and a repeated socket event, do not present
/// it again. `最后10秒` is only the timer value 10, once per betting round.
class DetailStatusPhrases {
  String? _status;
  int? _roundId;
  bool _seen = false;
  bool _announcedTen = false;

  /// [seconds] is the committed clock. Status and seconds are read together.
  String? onHttp({required String status, required int seconds, int? roundId}) {
    final roundChanged =
        _seen && roundId != null && _roundId != null && roundId != _roundId;
    if (roundId != null) _roundId = roundId;
    if (!_seen) {
      _seen = true;
      return _present(status, seconds);
    }
    if (roundChanged && status == 'betting') {
      return _present(status, seconds);
    }
    if (status == _status) return null;
    return _present(status, seconds);
  }

  /// [awaitingCountdown] is true while this betting round has been armed
  /// and its first countdown tick has not arrived yet. Another `betting`
  /// event in that window is a repeat. A `betting` event after the
  /// countdown has started is the next round.
  String? onStatus(String status, {required bool awaitingCountdown}) {
    if (_seen && status == _status) {
      if (status == 'betting' && !awaitingCountdown) {
        _announcedTen = false;
        return '开始押注';
      }
      return null;
    }
    _seen = true;
    return _present(status, null);
  }

  /// [seconds] is an accepted betting tick. 11, 9, and 0 emit nothing.
  String? onTimer(int seconds) {
    if (_status != 'betting' || seconds != 10 || _announcedTen) return null;
    _announcedTen = true;
    return '最后10秒';
  }

  /// A null [seconds] is a live status event. Betting then says `开始押注`
  /// because the countdown tick has not been applied yet. Zero seconds on
  /// a committed clock adds no phrase.
  String? _present(String status, int? seconds) {
    _status = status;
    if (status == 'betting') {
      _announcedTen = false;
      if (seconds == 0) return null;
      if (seconds == 10) {
        _announcedTen = true;
        return '最后10秒';
      }
      return '开始押注';
    }
    if (status == 'dealing') return '停止下注';
    if (status == 'finished' || status == 'active') return '等待发牌';
    if (status.isEmpty) return null;
    return status;
  }
}

/// Trial accounts keep this stamp for the whole visit.
String? detailRoadStamp({required bool trial}) => trial ? '试玩中' : null;
