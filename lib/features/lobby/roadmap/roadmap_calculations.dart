import 'roadmap_models.dart';

const int _roadRows = 6;
const int _markerRoadVisibleColumns = 8;
const int _bigRoadMaxColUsed = 30;
const int _bigEyeMinColumns = 16;
const int _smallRoadMinColumns = 16;
const int _cockroachMinColumns = 15;
const int _secondBigRoadMinColumns = 15;

RoadmapGrid calculateMarkerRoad(List<RoadmapResult> results) {
  final markers = <RoadmapPosition, RoadmapMarker>{};
  for (var index = 0; index < results.length; index++) {
    final result = results[index];
    final row = index % _roadRows;
    final col = index ~/ _roadRows;
    final display = _formatResult(result.key);
    markers[RoadmapPosition(col: col, row: row)] = RoadmapMarker(
      shape: RoadmapMarkerShape.ring,
      color: display.color,
      label: display.label,
      sourceKey: result.key,
      isGuess: result.isGuess,
      isBankerPair: result.key.contains('bankerPair'),
      isPlayerPair: result.key.contains('playerPair'),
    );
  }

  final dataColumns = (results.length + _roadRows - 1) ~/ _roadRows;
  return RoadmapGrid(
    type: RoadmapType.marker,
    rowCount: _roadRows,
    columnCount: dataColumns < _markerRoadVisibleColumns
        ? _markerRoadVisibleColumns
        : dataColumns,
    markers: markers,
  );
}

RoadmapGrid calculateBigRoad(List<RoadmapResult> results) {
  final cells = <RoadmapPosition, RoadmapMarker>{};
  var lastCol = 0;
  var lastRow = -1;
  var previousGroup = '';
  var maxColUsed = _bigRoadMaxColUsed;
  var horizontalMode = false;

  for (final result in results) {
    final isTie = result.contains('tie');
    final main = _mainResult(result.key);
    final group = _displayGroup(main);

    if (isTie) {
      _incrementTie(cells, lastCol, lastRow);
      continue;
    }

    late final int nextCol;
    late final int nextRow;
    if (group != previousGroup) {
      var searchCol = 0;
      while (cells.containsKey(RoadmapPosition(col: searchCol, row: 0))) {
        searchCol++;
      }
      nextCol = searchCol;
      nextRow = 0;
      horizontalMode = false;
    } else {
      final rowBelow = lastRow + 1;
      if (rowBelow >= _roadRows ||
          cells.containsKey(RoadmapPosition(col: lastCol, row: rowBelow))) {
        horizontalMode = true;
      }
      if (horizontalMode) {
        nextCol = lastCol + 1;
        nextRow = lastRow;
      } else {
        nextCol = lastCol;
        nextRow = rowBelow;
      }
    }

    cells[RoadmapPosition(col: nextCol, row: nextRow)] = _mainMarker(
      result,
      main,
      shape: RoadmapMarkerShape.ring,
    );
    lastCol = nextCol;
    lastRow = nextRow;
    previousGroup = group;
    if (nextCol > maxColUsed) maxColUsed = nextCol;
  }

  return RoadmapGrid(
    type: RoadmapType.big,
    rowCount: _roadRows,
    columnCount: maxColUsed + 1,
    markers: cells,
  );
}

/// React's generateBigRoadWithNoLShape helper, used as the input topology for
/// Big Eye Boy, Small Road, and Cockroach Road.
RoadmapGrid calculateNoLShapeBigRoad(List<RoadmapResult> results) {
  final cells = <RoadmapPosition, RoadmapMarker>{};
  var lastCol = 0;
  var lastRow = -1;
  var previousGroup = '';

  for (final result in results) {
    final isTie = result.contains('tie');
    final main = _mainResult(result.key);
    final group = _displayGroup(main);

    if (isTie) {
      _incrementTie(cells, lastCol, lastRow);
      continue;
    }

    late final int nextCol;
    late final int nextRow;
    if (group != previousGroup) {
      var searchCol = 0;
      while (cells.containsKey(RoadmapPosition(col: searchCol, row: 0))) {
        searchCol++;
      }
      nextCol = searchCol;
      nextRow = 0;
    } else {
      nextCol = lastCol;
      nextRow = lastRow + 1;
    }

    cells[RoadmapPosition(col: nextCol, row: nextRow)] = _baseRoadMarker(main);
    lastCol = nextCol;
    lastRow = nextRow;
    previousGroup = group;
  }

  var rowCount = 0;
  var columnCount = 0;
  for (final position in cells.keys) {
    if (position.row + 1 > rowCount) rowCount = position.row + 1;
    if (position.col + 1 > columnCount) columnCount = position.col + 1;
  }
  return RoadmapGrid(
    type: RoadmapType.noLShapeBase,
    rowCount: rowCount,
    columnCount: columnCount,
    markers: cells,
  );
}

RoadmapGrid calculateBigEyeRoad(List<RoadmapResult> results) =>
    _calculateDerivedRoad(results, _DerivedRoadConfig.bigEye);

RoadmapGrid calculateSmallRoad(List<RoadmapResult> results) =>
    _calculateDerivedRoad(results, _DerivedRoadConfig.small);

RoadmapGrid calculateCockroachRoad(List<RoadmapResult> results) =>
    _calculateDerivedRoad(results, _DerivedRoadConfig.cockroach);

RoadmapGrid calculateSecondBigRoad(List<RoadmapResult> results) {
  final compact = <RoadmapMarker>[];
  var lastRealIndex = -1;

  for (final result in results) {
    final tokens = result.key.split('|');
    final main = _secondBigRoadMain(tokens);
    if (tokens.contains('tie')) {
      if (lastRealIndex >= 0) {
        compact[lastRealIndex] = compact[lastRealIndex].copyWith(
          tieCount: compact[lastRealIndex].tieCount + 1,
        );
      }
      continue;
    }

    compact.add(
      _mainMarker(
        result,
        main,
        shape: RoadmapMarkerShape.ring,
        secondBigRoad: true,
      ),
    );
    lastRealIndex = compact.length - 1;
  }

  final cells = <RoadmapPosition, RoadmapMarker>{};
  for (var index = 0; index < compact.length; index++) {
    cells[RoadmapPosition(col: index ~/ 3, row: index % 3)] = compact[index];
  }
  final dataColumns = (compact.length + 2) ~/ 3;
  return RoadmapGrid(
    type: RoadmapType.secondBig,
    rowCount: 3,
    columnCount: dataColumns < _secondBigRoadMinColumns
        ? _secondBigRoadMinColumns
        : dataColumns,
    markers: cells,
  );
}

RoadmapGrid _calculateDerivedRoad(
  List<RoadmapResult> results,
  _DerivedRoadConfig config,
) {
  final base = calculateNoLShapeBigRoad(results);
  final columns = _buildBaseColumns(base);
  final empty = RoadmapGrid(
    type: config.type,
    rowCount: _roadRows,
    columnCount: config.minimumDisplayColumns,
    markers: const {},
  );
  if (columns.length < config.minimumBaseColumns) return empty;

  var startCol = config.startCol;
  var startEntry = 1;
  if (columns[startCol].length == 1) {
    startCol++;
    startEntry = 0;
  }
  if (startCol >= columns.length) return empty;

  final nonTieResults = results.where((result) => !result.contains('tie'));
  final nonTieList = nonTieResults.toList(growable: false);
  var resultIndex = 0;
  for (var col = 0; col < startCol; col++) {
    resultIndex += columns[col].length;
  }
  resultIndex += startEntry;

  final cells = <RoadmapPosition, RoadmapMarker>{};
  var lastCol = 0;
  var lastRow = -1;
  var lastSubCol = -1;
  RoadmapMarkerColor? previousColor;
  var horizontalMode = false;

  for (var colIndex = startCol; colIndex < columns.length; colIndex++) {
    final firstEntry = colIndex == startCol ? startEntry : 0;
    for (
      var entryIndex = firstEntry;
      entryIndex < columns[colIndex].length;
      entryIndex++
    ) {
      final isNewColumn = entryIndex == 0;
      final bool isRed;
      if (isNewColumn) {
        final currentDepth = columns[colIndex - 1].length;
        final previousDepth = columns[colIndex - config.depthOffset].length;
        isRed = currentDepth == previousDepth;
      } else {
        final currentRow = columns[colIndex][entryIndex];
        final comparisonColumn = columns[colIndex - config.rowComparisonOffset];
        final aboveExists = comparisonColumn.contains(currentRow - 1);
        final sameRowExists = comparisonColumn.contains(currentRow);
        isRed = aboveExists == sameRowExists;
      }

      final color = isRed ? RoadmapMarkerColor.red : RoadmapMarkerColor.blue;
      final isGuess = resultIndex < nonTieList.length
          ? nonTieList[resultIndex].isGuess
          : false;
      resultIndex++;

      late final int nextCol;
      late final int nextRow;
      late final int nextSubCol;
      if (previousColor == null || color != previousColor) {
        var searchCol = 0;
        var searchSubCol = 0;
        while (cells.containsKey(
          RoadmapPosition(col: searchCol, row: 0, subCol: searchSubCol),
        )) {
          searchSubCol++;
          if (searchSubCol >= 2) {
            searchSubCol = 0;
            searchCol++;
          }
        }
        nextCol = searchCol;
        nextRow = 0;
        nextSubCol = searchSubCol;
        horizontalMode = false;
      } else {
        final rowBelow = lastRow + 1;
        if (rowBelow >= _roadRows ||
            cells.containsKey(
              RoadmapPosition(col: lastCol, row: rowBelow, subCol: lastSubCol),
            )) {
          horizontalMode = true;
        }
        if (horizontalMode) {
          var newSubCol = lastSubCol + 1;
          var newCol = lastCol;
          if (newSubCol >= 2) {
            newSubCol = 0;
            newCol++;
          }
          nextCol = newCol;
          nextRow = lastRow;
          nextSubCol = newSubCol;
        } else {
          nextCol = lastCol;
          nextRow = rowBelow;
          nextSubCol = lastSubCol;
        }
      }

      cells[RoadmapPosition(col: nextCol, row: nextRow, subCol: nextSubCol)] =
          RoadmapMarker(shape: config.shape, color: color, isGuess: isGuess);
      lastCol = nextCol;
      lastRow = nextRow;
      lastSubCol = nextSubCol;
      previousColor = color;
    }
  }

  var maxColUsed = 0;
  for (final position in cells.keys) {
    if (position.col > maxColUsed) maxColUsed = position.col;
  }
  final dataColumns = maxColUsed + 1;
  return RoadmapGrid(
    type: config.type,
    rowCount: _roadRows,
    columnCount: dataColumns < config.minimumDisplayColumns
        ? config.minimumDisplayColumns
        : dataColumns,
    markers: cells,
  );
}

List<List<int>> _buildBaseColumns(RoadmapGrid base) {
  if (base.markers.isEmpty) return const [];
  final maximumColumn = base.markers.keys
      .map((position) => position.col)
      .reduce((a, b) => a > b ? a : b);
  final columns = <List<int>>[];
  for (var col = 0; col <= maximumColumn; col++) {
    final rows =
        base.markers.keys
            .where((position) => position.col == col)
            .map((position) => position.row)
            .toList()
          ..sort();
    if (rows.isNotEmpty) columns.add(rows);
  }
  return columns;
}

void _incrementTie(
  Map<RoadmapPosition, RoadmapMarker> cells,
  int col,
  int row,
) {
  final position = RoadmapPosition(col: col, row: row);
  final marker = cells[position];
  if (marker == null) return;
  cells[position] = marker.copyWith(tieCount: marker.tieCount + 1);
}

RoadmapMarker _mainMarker(
  RoadmapResult result,
  String main, {
  required RoadmapMarkerShape shape,
  bool secondBigRoad = false,
}) {
  final color = _mainColor(main, emptyDefaultsToBlue: !secondBigRoad);
  return RoadmapMarker(
    shape: shape,
    color: color,
    tieCountColor: secondBigRoad
        ? _secondBigRoadTieColor(main)
        : _tieColor(main),
    main: main,
    sourceKey: result.key,
    isGuess: result.isGuess,
    isBankerPair: result.key.split('|').contains('bankerPair'),
    isPlayerPair: result.key.split('|').contains('playerPair'),
  );
}

String _mainResult(String key) {
  final tokens = key.split('|');
  if (tokens.contains('banker')) return 'banker';
  if (tokens.contains('player')) return 'player';
  if (tokens.contains('tiger')) return 'tiger';
  if (tokens.contains('dragon')) return 'dragon';
  return '';
}

String _displayGroup(String main) =>
    const {'banker', 'supertwoSix', 'superthreeSix'}.contains(main)
    ? 'banker-group'
    : main;

String _secondBigRoadMain(List<String> tokens) {
  if (tokens.contains('banker') ||
      tokens.contains('supertwoSix') ||
      tokens.contains('superthreeSix')) {
    return 'banker';
  }
  if (tokens.contains('player')) return 'player';
  if (tokens.contains('dragon')) return 'dragon';
  if (tokens.contains('tiger')) return 'tiger';
  return '';
}

_RoadDisplay _formatResult(String key) {
  final tokens = key.split('|');
  if (key.contains('supertwoSix') || key.contains('superthreeSix')) {
    return const _RoadDisplay('6', RoadmapMarkerColor.red);
  }
  if (tokens.contains('banker')) {
    return const _RoadDisplay('庄', RoadmapMarkerColor.red);
  }
  if (tokens.contains('player')) {
    return const _RoadDisplay('闲', RoadmapMarkerColor.blue);
  }
  if (tokens.contains('tie')) {
    return const _RoadDisplay('和', RoadmapMarkerColor.green);
  }
  if (tokens.contains('dragon')) {
    return const _RoadDisplay('龙', RoadmapMarkerColor.red);
  }
  if (tokens.contains('tiger')) {
    return const _RoadDisplay('虎', RoadmapMarkerColor.blue);
  }
  return const _RoadDisplay('', null);
}

RoadmapMarkerColor? _mainColor(
  String main, {
  required bool emptyDefaultsToBlue,
}) {
  if (main == 'banker' || main == 'dragon') return RoadmapMarkerColor.red;
  if (main == 'player' || main == 'tiger') return RoadmapMarkerColor.blue;
  if (main.isEmpty && emptyDefaultsToBlue) return RoadmapMarkerColor.blue;
  return null;
}

RoadmapMarkerColor _tieColor(String main) =>
    main == 'banker' || main == 'dragon'
    ? RoadmapMarkerColor.red
    : RoadmapMarkerColor.blue;

RoadmapMarkerColor _secondBigRoadTieColor(String main) {
  if (main == 'banker' || main == 'dragon') return RoadmapMarkerColor.red;
  if (main == 'player' || main == 'tiger') return RoadmapMarkerColor.blue;
  return RoadmapMarkerColor.black;
}

RoadmapMarker _baseRoadMarker(String main) =>
    RoadmapMarker(shape: RoadmapMarkerShape.ring, main: main);

class _RoadDisplay {
  const _RoadDisplay(this.label, this.color);

  final String label;
  final RoadmapMarkerColor? color;
}

class _DerivedRoadConfig {
  const _DerivedRoadConfig({
    required this.type,
    required this.shape,
    required this.minimumBaseColumns,
    required this.startCol,
    required this.depthOffset,
    required this.rowComparisonOffset,
    required this.minimumDisplayColumns,
  });

  static const bigEye = _DerivedRoadConfig(
    type: RoadmapType.bigEye,
    shape: RoadmapMarkerShape.ring,
    minimumBaseColumns: 2,
    startCol: 1,
    depthOffset: 2,
    rowComparisonOffset: 1,
    minimumDisplayColumns: _bigEyeMinColumns,
  );

  static const small = _DerivedRoadConfig(
    type: RoadmapType.small,
    shape: RoadmapMarkerShape.solid,
    minimumBaseColumns: 3,
    startCol: 2,
    depthOffset: 3,
    rowComparisonOffset: 2,
    minimumDisplayColumns: _smallRoadMinColumns,
  );

  static const cockroach = _DerivedRoadConfig(
    type: RoadmapType.cockroach,
    shape: RoadmapMarkerShape.slash,
    minimumBaseColumns: 4,
    startCol: 3,
    depthOffset: 4,
    rowComparisonOffset: 3,
    minimumDisplayColumns: _cockroachMinColumns,
  );

  final RoadmapType type;
  final RoadmapMarkerShape shape;
  final int minimumBaseColumns;
  final int startCol;
  final int depthOffset;
  final int rowComparisonOffset;
  final int minimumDisplayColumns;
}
