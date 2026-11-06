import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_calculations.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_models.dart';

RoadmapResult _result(String key, {bool isGuess = false}) =>
    RoadmapResult(key: key, isGuess: isGuess);

List<RoadmapResult> _sequence(List<String> keys) =>
    keys.map((key) => _result(key)).toList(growable: false);

void _expectPositions(RoadmapGrid grid, Set<RoadmapPosition> expected) {
  expect(grid.markers.keys.toSet(), expected);
}

void _expectMarker(
  RoadmapGrid grid,
  int col,
  int row, {
  int subCol = 0,
  String? main,
  String? label,
  RoadmapMarkerColor? color,
  RoadmapMarkerShape? shape,
  int? tieCount,
  RoadmapMarkerColor? tieCountColor,
  bool? bankerPair,
  bool? playerPair,
  bool? isGuess,
}) {
  final marker = grid.at(col, row, subCol: subCol);
  expect(marker, isNotNull, reason: 'Missing marker at $col,$row,$subCol');
  if (main != null) expect(marker!.main, main);
  if (label != null) expect(marker!.label, label);
  if (color != null) expect(marker!.color, color);
  if (shape != null) expect(marker!.shape, shape);
  if (tieCount != null) expect(marker!.tieCount, tieCount);
  if (tieCountColor != null) expect(marker!.tieCountColor, tieCountColor);
  if (bankerPair != null) expect(marker!.isBankerPair, bankerPair);
  if (playerPair != null) expect(marker!.isPlayerPair, playerPair);
  if (isGuess != null) expect(marker!.isGuess, isGuess);
}

void main() {
  group('React roadmap parity fixtures', () {
    test('empty history keeps each React Home grid minimum', () {
      const empty = <RoadmapResult>[];
      expect(calculateMarkerRoad(empty).columnCount, 8);
      expect(calculateBigRoad(empty).columnCount, 31);
      expect(calculateNoLShapeBigRoad(empty).columnCount, 0);
      expect(calculateBigEyeRoad(empty).columnCount, 16);
      expect(calculateSmallRoad(empty).columnCount, 16);
      expect(calculateCockroachRoad(empty).columnCount, 15);
      expect(calculateSecondBigRoad(empty).columnCount, 15);
      expect(calculateBigRoad(empty).markers, isEmpty);
      expect(calculateBigEyeRoad(empty).markers, isEmpty);
      expect(calculateSmallRoad(empty).markers, isEmpty);
      expect(calculateCockroachRoad(empty).markers, isEmpty);
      expect(calculateSecondBigRoad(empty).markers, isEmpty);
    });

    test('one banker result appears in matrix, Big Road, helper, and Second Big Road', () {
      final input = _sequence(['banker']);
      final matrix = calculateMarkerRoad(input);
      final big = calculateBigRoad(input);
      final helper = calculateNoLShapeBigRoad(input);
      final second = calculateSecondBigRoad(input);

      _expectPositions(matrix, {const RoadmapPosition(col: 0, row: 0)});
      _expectMarker(
        matrix,
        0,
        0,
        label: '庄',
        color: RoadmapMarkerColor.red,
        shape: RoadmapMarkerShape.ring,
      );
      _expectMarker(big, 0, 0, main: 'banker', color: RoadmapMarkerColor.red);
      _expectMarker(helper, 0, 0, main: 'banker');
      _expectMarker(second, 0, 0, main: 'banker');
      expect(calculateBigEyeRoad(input).markers, isEmpty);
      expect(calculateSmallRoad(input).markers, isEmpty);
      expect(calculateCockroachRoad(input).markers, isEmpty);
    });

    test('banker and player streaks descend in Big Road', () {
      final banker = calculateBigRoad(
        _sequence(['banker', 'banker', 'banker']),
      );
      final player = calculateBigRoad(
        _sequence(['player', 'player', 'player']),
      );
      _expectPositions(banker, {
        const RoadmapPosition(col: 0, row: 0),
        const RoadmapPosition(col: 0, row: 1),
        const RoadmapPosition(col: 0, row: 2),
      });
      _expectMarker(banker, 0, 2, main: 'banker');
      _expectPositions(player, {
        const RoadmapPosition(col: 0, row: 0),
        const RoadmapPosition(col: 0, row: 1),
        const RoadmapPosition(col: 0, row: 2),
      });
      _expectMarker(player, 0, 2, main: 'player');
    });

    test('alternating groups start a new Big Road column', () {
      final grid = calculateBigRoad(
        _sequence(['banker', 'player', 'banker', 'player']),
      );
      _expectPositions(grid, {
        const RoadmapPosition(col: 0, row: 0),
        const RoadmapPosition(col: 1, row: 0),
        const RoadmapPosition(col: 2, row: 0),
        const RoadmapPosition(col: 3, row: 0),
      });
      _expectMarker(grid, 0, 0, main: 'banker');
      _expectMarker(grid, 3, 0, main: 'player');
    });

    test('MarkerRoad maps seven ordered outcomes column-major', () {
      final grid = calculateMarkerRoad(
        _sequence([
          'banker',
          'banker',
          'player',
          'tie',
          'player',
          'player',
          'dragon',
        ]),
      );
      _expectPositions(grid, {
        for (var row = 0; row < 6; row++) RoadmapPosition(col: 0, row: row),
        const RoadmapPosition(col: 1, row: 0),
      });
      _expectMarker(grid, 1, 0, label: '龙', color: RoadmapMarkerColor.red);
    });

    test('tie before the first main result is ignored by road algorithms', () {
      final input = _sequence(['tie', 'banker']);
      final big = calculateBigRoad(input);
      final helper = calculateNoLShapeBigRoad(input);
      final second = calculateSecondBigRoad(input);
      _expectPositions(big, {const RoadmapPosition(col: 0, row: 0)});
      _expectMarker(big, 0, 0, main: 'banker', tieCount: 0);
      _expectPositions(helper, {const RoadmapPosition(col: 0, row: 0)});
      _expectPositions(second, {const RoadmapPosition(col: 0, row: 0)});
      final matrix = calculateMarkerRoad(input);
      _expectMarker(matrix, 0, 0, label: '和', color: RoadmapMarkerColor.green);
      _expectMarker(matrix, 0, 1, label: '庄', color: RoadmapMarkerColor.red);
    });

    test(
      'consecutive ties increment the last Big Road and Second Big Road bead',
      () {
        final input = _sequence(['banker', 'tie', 'tie', 'player']);
        final big = calculateBigRoad(input);
        final second = calculateSecondBigRoad(input);
        _expectMarker(
          big,
          0,
          0,
          tieCount: 2,
          tieCountColor: RoadmapMarkerColor.red,
        );
        _expectMarker(second, 0, 0, tieCount: 2);
        _expectMarker(second, 0, 1, main: 'player');
      },
    );

    test(
      'React Big Road fixture preserves pairs, combined keys, and attached tie',
      () {
        final input = _sequence([
          'banker|bankerPair',
          'banker',
          'player',
          'tie',
          'player|playerPair',
          'player',
        ]);
        final grid = calculateBigRoad(input);
        _expectPositions(grid, {
          const RoadmapPosition(col: 0, row: 0),
          const RoadmapPosition(col: 0, row: 1),
          const RoadmapPosition(col: 1, row: 0),
          const RoadmapPosition(col: 1, row: 1),
          const RoadmapPosition(col: 1, row: 2),
        });
        _expectMarker(
          grid,
          0,
          0,
          main: 'banker',
          bankerPair: true,
          playerPair: false,
        );
        _expectMarker(grid, 0, 1, main: 'banker', tieCount: 0);
        _expectMarker(grid, 1, 0, main: 'player', tieCount: 1);
        _expectMarker(grid, 1, 1, main: 'player', playerPair: true);
        _expectMarker(grid, 1, 2, main: 'player');

        final second = calculateSecondBigRoad(input);
        _expectPositions(second, {
          const RoadmapPosition(col: 0, row: 0),
          const RoadmapPosition(col: 0, row: 1),
          const RoadmapPosition(col: 0, row: 2),
          const RoadmapPosition(col: 1, row: 0),
          const RoadmapPosition(col: 1, row: 1),
        });
        _expectMarker(second, 0, 0, main: 'banker', bankerPair: true);
        _expectMarker(second, 0, 2, main: 'player', tieCount: 1);
        _expectMarker(second, 1, 0, main: 'player', playerPair: true);
      },
    );

    test('combined main tokens use React precedence and tie takes precedence in Big Road', () {
      final combined = _result('banker|player|bankerPair|playerPair');
      final matrix = calculateMarkerRoad([combined]);
      final big = calculateBigRoad([combined]);
      final second = calculateSecondBigRoad([combined]);
      _expectMarker(
        matrix,
        0,
        0,
        label: '庄',
        bankerPair: true,
        playerPair: true,
      );
      _expectMarker(
        big,
        0,
        0,
        main: 'banker',
        bankerPair: true,
        playerPair: true,
      );
      _expectMarker(
        second,
        0,
        0,
        main: 'banker',
        bankerPair: true,
        playerPair: true,
      );

      final tieCombined = calculateBigRoad(_sequence(['banker|tie']));
      expect(tieCombined.markers, isEmpty);
    });

    test('React display Big Road moves horizontally after six rows', () {
      final grid = calculateBigRoad(
        List<RoadmapResult>.generate(7, (_) => _result('banker')),
      );
      _expectPositions(grid, {
        for (var row = 0; row < 6; row++) RoadmapPosition(col: 0, row: row),
        const RoadmapPosition(col: 1, row: 5),
      });
      expect(grid.columnCount, 31);
    });

    test(
      'No-L-Shape helper continues downward without the display collision rule',
      () {
        final grid = calculateNoLShapeBigRoad(
          List<RoadmapResult>.generate(7, (_) => _result('banker|bankerPair')),
        );
        _expectPositions(grid, {
          for (var row = 0; row < 7; row++) RoadmapPosition(col: 0, row: row),
        });
        expect(grid.rowCount, 7);
        _expectMarker(
          grid,
          0,
          0,
          main: 'banker',
          bankerPair: false,
          isGuess: false,
        );
      },
    );

    test('derived roads enforce their React base-column thresholds', () {
      expect(
        calculateBigEyeRoad(_sequence(['banker', 'banker'])).markers,
        isEmpty,
      );
      expect(
        calculateSmallRoad(_sequence(['banker', 'player'])).markers,
        isEmpty,
      );
      expect(
        calculateCockroachRoad(_sequence(['banker', 'player', 'banker']))
            .markers,
        isEmpty,
      );
      expect(
        calculateBigEyeRoad(_sequence(['banker', 'player'])).columnCount,
        16,
      );
      expect(
        calculateSmallRoad(_sequence(['banker', 'player'])).columnCount,
        16,
      );
      expect(
        calculateCockroachRoad(_sequence(['banker', 'player'])).columnCount,
        15,
      );
    });

    test(
      'Big Eye Boy React fixtures preserve start-column and comparison rules',
      () {
        final equalDepths = calculateBigEyeRoad(
          _sequence(['banker', 'player', 'banker']),
        );
        _expectPositions(equalDepths, {
          const RoadmapPosition(col: 0, row: 0, subCol: 0),
        });
        _expectMarker(
          equalDepths,
          0,
          0,
          color: RoadmapMarkerColor.red,
          shape: RoadmapMarkerShape.ring,
        );

        final unequalCellPresence = calculateBigEyeRoad(
          _sequence(['banker', 'player', 'player']),
        );
        _expectMarker(
          unequalCellPresence,
          0,
          0,
          color: RoadmapMarkerColor.blue,
        );
      },
    );

    test('Small Road and Cockroach Road start offsets match React', () {
      final small = calculateSmallRoad(
        _sequence(['banker', 'player', 'banker', 'player']),
      );
      _expectPositions(small, {
        const RoadmapPosition(col: 0, row: 0, subCol: 0),
      });
      _expectMarker(small, 0, 0, color: RoadmapMarkerColor.red);

      final cockroach = calculateCockroachRoad(
        _sequence(['banker', 'player', 'banker', 'player', 'banker']),
      );
      _expectPositions(cockroach, {
        const RoadmapPosition(col: 0, row: 0, subCol: 0),
      });
      _expectMarker(
        cockroach,
        0,
        0,
        color: RoadmapMarkerColor.red,
        shape: RoadmapMarkerShape.slash,
      );
    });

    test(
      'derived-road row overflow wraps through two subcolumns then next column',
      () {
        final input = List<RoadmapResult>.generate(
          12,
          (index) => _result(index.isEven ? 'banker' : 'player'),
        );
        final grid = calculateBigEyeRoad(input);
        expect(grid.markers.length, 10);
        _expectMarker(grid, 0, 5, subCol: 0, color: RoadmapMarkerColor.red);
        _expectMarker(grid, 0, 5, subCol: 1, color: RoadmapMarkerColor.red);
        _expectMarker(grid, 1, 5, subCol: 0, color: RoadmapMarkerColor.red);
        _expectMarker(grid, 2, 5, subCol: 0, color: RoadmapMarkerColor.red);
      },
    );

    test('derived colors change into the first free top-row subcolumn', () {
      final input = _sequence([
        'banker',
        'player',
        'banker',
        'player',
        'player',
        'banker',
        'player',
      ]);
      final grid = calculateBigEyeRoad(input);
      _expectPositions(grid, {
        const RoadmapPosition(col: 0, row: 0, subCol: 0),
        const RoadmapPosition(col: 0, row: 1, subCol: 0),
        const RoadmapPosition(col: 0, row: 0, subCol: 1),
        const RoadmapPosition(col: 0, row: 1, subCol: 1),
        const RoadmapPosition(col: 0, row: 2, subCol: 1),
      });
      _expectMarker(grid, 0, 0, subCol: 0, color: RoadmapMarkerColor.red);
      _expectMarker(grid, 0, 1, subCol: 0, color: RoadmapMarkerColor.red);
      _expectMarker(grid, 0, 0, subCol: 1, color: RoadmapMarkerColor.blue);
      _expectMarker(grid, 0, 1, subCol: 1, color: RoadmapMarkerColor.blue);
      _expectMarker(grid, 0, 2, subCol: 1, color: RoadmapMarkerColor.blue);
    });

    test(
      'isGuess propagates from source results into applicable road markers',
      () {
        final input = [
          _result('banker'),
          _result('player'),
          _result('banker', isGuess: true),
        ];
        _expectMarker(calculateMarkerRoad(input), 0, 2, isGuess: true);
        _expectMarker(calculateBigRoad(input), 2, 0, isGuess: true);
        _expectMarker(calculateBigEyeRoad(input), 0, 0, isGuess: true);
      },
    );

    test('special six key uses each React algorithm precedence', () {
      const input = [RoadmapResult(key: 'supertwoSix')];
      _expectMarker(
        calculateMarkerRoad(input),
        0,
        0,
        label: '6',
        color: RoadmapMarkerColor.red,
      );
      _expectMarker(
        calculateBigRoad(input),
        0,
        0,
        main: '',
        color: RoadmapMarkerColor.blue,
      );
      _expectMarker(
        calculateSecondBigRoad(input),
        0,
        0,
        main: 'banker',
        color: RoadmapMarkerColor.red,
      );
    });

    test('Second Big Road compacts ties and preserves pair markers', () {
      final grid = calculateSecondBigRoad(
        _sequence([
          'banker|bankerPair',
          'banker',
          'player',
          'tie',
          'player|playerPair',
          'player',
        ]),
      );
      _expectPositions(grid, {
        const RoadmapPosition(col: 0, row: 0),
        const RoadmapPosition(col: 0, row: 1),
        const RoadmapPosition(col: 0, row: 2),
        const RoadmapPosition(col: 1, row: 0),
        const RoadmapPosition(col: 1, row: 1),
      });
      _expectMarker(grid, 0, 0, main: 'banker', bankerPair: true);
      _expectMarker(
        grid,
        0,
        2,
        main: 'player',
        tieCount: 1,
        tieCountColor: RoadmapMarkerColor.blue,
      );
      _expectMarker(grid, 1, 0, main: 'player', playerPair: true);
    });

    test(
      'Second Big Road uses black tie text for an unrecognized main result',
      () {
        final grid = calculateSecondBigRoad(_sequence(['unknown', 'tie']));
        _expectMarker(
          grid,
          0,
          0,
          main: '',
          tieCount: 1,
          color: null,
          tieCountColor: RoadmapMarkerColor.black,
        );
      },
    );

    test('long ordered histories expand matrix, Big Road, derived, and compact grids', () {
      final input = List<RoadmapResult>.generate(
        50,
        (index) => _result(index.isEven ? 'banker' : 'player'),
      );
      final matrix = calculateMarkerRoad(input);
      final big = calculateBigRoad(input);
      final eye = calculateBigEyeRoad(input);
      final second = calculateSecondBigRoad(input);
      expect(matrix.columnCount, 9);
      _expectMarker(matrix, 8, 1, label: '闲', color: RoadmapMarkerColor.blue);
      expect(big.columnCount, 50);
      _expectMarker(big, 49, 0, main: 'player');
      expect(eye.markers.length, 48);
      expect(second.columnCount, 17);
      _expectMarker(second, 16, 1, main: 'player');
    });
  });
}
