/// Static Baccarat or Longhu table configuration.
///
/// This holds labels and key lists only. Countdown, balance, chips, bets,
/// and the socket stay on the shared detail session.
class GameTableProfile {
  const GameTableProfile({
    required this.gameType,
    required this.allowedResultKeys,
    required this.mainResultKeys,
    required this.limitKeyOrder,
    required this.footerLabels,
    required this.askRoadLabels,
    required this.board,
    required this.boardResultKeys,
  });

  final String gameType;
  final Set<String> allowedResultKeys;
  final Set<String> mainResultKeys;
  final List<String> limitKeyOrder;
  final List<GameTableFooterLabel> footerLabels;
  final List<GameTableAskLabel> askRoadLabels;
  final GameTableBoard board;

  /// Result keys read by the current board, in the order that board places them.
  final List<String> boardResultKeys;

  bool get longhu => board == GameTableBoard.longhu;

  static const baccarat = GameTableProfile(
    gameType: 'BACCARAT',
    allowedResultKeys: {'banker', 'player', 'tie', 'bankerPair', 'playerPair'},
    mainResultKeys: {'banker', 'player', 'tie'},
    limitKeyOrder: ['player', 'banker', 'tie', 'bankerPair', 'playerPair'],
    footerLabels: [
      GameTableFooterLabel(resultKey: 'banker', label: '庄'),
      GameTableFooterLabel(resultKey: 'player', label: '闲'),
      GameTableFooterLabel(resultKey: 'tie', label: '和'),
      GameTableFooterLabel(resultKey: 'bankerPair', label: '庄对'),
      GameTableFooterLabel(resultKey: 'playerPair', label: '闲对'),
    ],
    askRoadLabels: [
      GameTableAskLabel(label: '庄问路'),
      GameTableAskLabel(label: '闲问路'),
    ],
    board: GameTableBoard.baccarat,
    boardResultKeys: ['player', 'playerPair', 'bankerPair', 'tie', 'banker'],
  );

  static const longhuTable = GameTableProfile(
    gameType: 'LONGHU',
    allowedResultKeys: {'dragon', 'tiger', 'tie'},
    mainResultKeys: {'dragon', 'tiger', 'tie'},
    limitKeyOrder: ['dragon', 'tiger', 'tie'],
    footerLabels: [
      GameTableFooterLabel(resultKey: 'dragon', label: '龙'),
      GameTableFooterLabel(resultKey: 'tiger', label: '虎'),
      GameTableFooterLabel(resultKey: 'tie', label: '和'),
    ],
    askRoadLabels: [
      GameTableAskLabel(label: '龙问路', secondMarker: true),
      GameTableAskLabel(label: '虎问路', secondMarker: true),
    ],
    board: GameTableBoard.longhu,
    boardResultKeys: ['dragon', 'tie', 'tiger'],
  );

  /// Returns the profile for [type].
  ///
  /// [type] is matched without regard to case. Null, blank, and any other
  /// value are rejected. They are not treated as Baccarat.
  factory GameTableProfile.forType(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'BACCARAT':
        return baccarat;
      case 'LONGHU':
        return longhuTable;
      default:
        throw FormatException('不支持的游戏类型: ${type ?? ''}');
    }
  }
}

enum GameTableBoard { baccarat, longhu }

class GameTableFooterLabel {
  const GameTableFooterLabel({required this.resultKey, required this.label});

  final String resultKey;
  final String label;
}

class GameTableAskLabel {
  const GameTableAskLabel({required this.label, this.secondMarker = false});

  final String label;

  /// Longhu draws a second circle beside the ask-road label.
  final bool secondMarker;
}
