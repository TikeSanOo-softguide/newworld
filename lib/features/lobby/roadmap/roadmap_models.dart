enum RoadmapType {
  marker,
  big,
  bigEye,
  small,
  cockroach,
  secondBig,
  noLShapeBase,
}

enum RoadmapMarkerColor { red, blue, green, black }

enum RoadmapMarkerShape { ring, solid, slash }

class RoadmapResult {
  const RoadmapResult({required this.key, this.isGuess = false});

  final String key;
  final bool isGuess;

  bool contains(String token) => key.split('|').contains(token);
}

class RoadmapPosition {
  const RoadmapPosition({
    required this.col,
    required this.row,
    this.subCol = 0,
  });

  final int col;
  final int row;
  final int subCol;

  @override
  bool operator ==(Object other) =>
      other is RoadmapPosition &&
      other.col == col &&
      other.row == row &&
      other.subCol == subCol;

  @override
  int get hashCode => Object.hash(col, row, subCol);
}

class RoadmapMarker {
  const RoadmapMarker({
    required this.shape,
    this.color,
    this.tieCountColor,
    this.main,
    this.label,
    this.sourceKey,
    this.tieCount = 0,
    this.isGuess = false,
    this.isBankerPair = false,
    this.isPlayerPair = false,
  });

  final RoadmapMarkerShape shape;
  final RoadmapMarkerColor? color;
  final RoadmapMarkerColor? tieCountColor;
  final String? main;
  final String? label;
  final String? sourceKey;
  final int tieCount;
  final bool isGuess;
  final bool isBankerPair;
  final bool isPlayerPair;

  RoadmapMarker copyWith({int? tieCount}) => RoadmapMarker(
    shape: shape,
    color: color,
    tieCountColor: tieCountColor,
    main: main,
    label: label,
    sourceKey: sourceKey,
    tieCount: tieCount ?? this.tieCount,
    isGuess: isGuess,
    isBankerPair: isBankerPair,
    isPlayerPair: isPlayerPair,
  );
}

class RoadmapGrid {
  RoadmapGrid({
    required this.type,
    required this.rowCount,
    required this.columnCount,
    required Map<RoadmapPosition, RoadmapMarker> markers,
  }) : markers = Map.unmodifiable(markers);

  final RoadmapType type;
  final int rowCount;
  final int columnCount;
  final Map<RoadmapPosition, RoadmapMarker> markers;

  RoadmapMarker? at(int col, int row, {int subCol = 0}) =>
      markers[RoadmapPosition(col: col, row: row, subCol: subCol)];
}
