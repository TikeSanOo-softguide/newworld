import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../lobby/models/lobby_round_result.dart';
import '../../lobby/roadmap/roadmap_board.dart';
import '../../lobby/roadmap/roadmap_calculations.dart';
import '../../lobby/roadmap/roadmap_metrics.dart';
import '../../lobby/roadmap/roadmap_models.dart';
import '../../lobby/roadmap/roadmap_painter.dart';
import '../detail_status_notice.dart';

const detailBeadColumns = 6;
const detailBigColumns = 14;
const detailDerivedColumns = 10;

/// Height reserved for the roadmap. Page 3 is the tallest once each road has
/// an inner margin and a small gap.
double detailRoadBoardHeight(double width) {
  final listPage = RoadmapBoardSpacing.detail.height(width);
  final mainPage = _DetailBoardMetrics.forRow(
    width,
    columns: detailBeadColumns + detailBigColumns,
    boards: 2,
  ).cardHeight(6);
  final derived = _DetailBoardMetrics.forRow(
    width,
    columns: detailDerivedColumns * 2,
    boards: 2,
    marginPerBoard: false,
  );
  final derivedPage =
      derived.margin * 2 + derived.gridHeight(3) * 2 + derived.gap;
  var height = listPage;
  if (mainPage > height) height = mainPage;
  if (derivedPage > height) height = derivedPage;
  return height;
}

double detailRoadFooterHeight(double width) {
  final font = _footerFontSize(width);
  final vertical = _beadCellWidth(width) * 0.08;
  return font * 1.2 + vertical * 2 + 1 + _detailRoadSlack(width);
}

/// The painted grid and footer on an 1800-wide screen sit 22px short of the
/// reference road block. The extra stays in the footer so cell size is unchanged
/// and the white road starts at the reference position.
double _detailRoadSlack(double width) => width * (22 / 1800);

double _beadCellWidth(double width) =>
    width / (beadPlateColumns + listRoadGapOverBeadCell + bigRoadColumns / 2);

double _footerFontSize(double width) =>
    _beadCellWidth(width) * listRoadCellHeightOverWidth * 0.70;

class BaccaratRoadmapPanel extends StatefulWidget {
  const BaccaratRoadmapPanel({
    super.key,
    required this.results,
    this.stamp,
    this.stampColor = const Color(0xE6E02028),
    this.statusText,
    this.longhu = false,
  });

  final List<LobbyRoundResult> results;
  final String? stamp;
  final Color stampColor;

  /// Current status phrase drawn across the board. `试玩中` stays in [stamp].
  final String? statusText;
  final bool longhu;

  @override
  State<BaccaratRoadmapPanel> createState() => _BaccaratRoadmapPanelState();
}

class _BaccaratRoadmapPanelState extends State<BaccaratRoadmapPanel> {
  var _page = 0;

  void _nextPage() => setState(() => _page = (_page + 1) % 3);

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    final roadmapResults = results
        .map((result) => RoadmapResult(key: result.key))
        .toList(growable: false);
    final markerRoad = _Road(
      '珠盘路',
      calculateMarkerRoad(roadmapResults),
      detailBeadColumns,
      6,
    );
    final bigRoad = _Road(
      '大路',
      calculateBigRoad(roadmapResults),
      detailBigColumns,
      6,
    );
    final derivedRoads = [
      _Road(
        '大眼仔',
        calculateBigEyeRoad(roadmapResults),
        detailDerivedColumns,
        3,
      ),
      _Road(
        '曱甴路',
        calculateCockroachRoad(roadmapResults),
        detailDerivedColumns,
        3,
      ),
      _Road('小眼仔', calculateSmallRoad(roadmapResults), detailDerivedColumns, 3),
      _Road(
        '三星路',
        calculateSecondBigRoad(roadmapResults),
        detailDerivedColumns,
        3,
      ),
    ];
    final longhu = widget.longhu;
    final bankerSide = longhu ? 'dragon' : 'banker';
    final playerSide = longhu ? 'tiger' : 'player';
    final bankerAsk = _AskPreview.from(roadmapResults, bankerSide);
    final playerAsk = _AskPreview.from(roadmapResults, playerSide);
    final banker = _count(results, longhu ? 'dragon' : 'banker');
    final player = _count(results, longhu ? 'tiger' : 'player');
    final tie = _count(results, 'tie');
    final bankerPair = _count(results, 'bankerPair');
    final playerPair = _count(results, 'playerPair');

    final grid = _RoadmapGrid(
      page: _page,
      markerRoad: markerRoad,
      bigRoad: bigRoad,
      derivedRoads: derivedRoads,
      stamp: widget.stamp,
      stampColor: widget.stampColor,
      onTap: _nextPage,
    );
    return Container(
      color: listRoadBoardColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final font = _footerFontSize(width);
          final pad = _beadCellWidth(width) * 0.08;
          final slack = _detailRoadSlack(width);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  grid,
                  if (widget.statusText != null &&
                      widget.statusText!.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0x80333333),
                                borderRadius:
                                    detailRepeatNotice(widget.statusText)
                                    ? BorderRadius.circular(4)
                                    : null,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: font * 0.35,
                                  ),
                                  child: Text(
                                    widget.statusText!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: detailStatusPhraseInk(
                                        widget.statusText,
                                      ),
                                      fontSize: (font * 1.7).clamp(18.0, 32.0),
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  pad * 2,
                  pad + slack / 2,
                  pad * 2,
                  pad + slack / 2,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: listRoadLineColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            _CountLabel(
                              label: longhu ? '龙' : '庄',
                              count: banker,
                              color: _bankerRed,
                              fontSize: font,
                            ),
                            _CountLabel(
                              label: longhu ? '虎' : '闲',
                              count: player,
                              color: _playerBlue,
                              fontSize: font,
                            ),
                            _CountLabel(
                              label: '和',
                              count: tie,
                              color: _tieGreen,
                              fontSize: font,
                            ),
                            if (!longhu) ...[
                              _CountLabel(
                                label: '庄对',
                                count: bankerPair,
                                color: _bankerRed,
                                fontSize: font,
                              ),
                              _CountLabel(
                                label: '闲对',
                                count: playerPair,
                                color: _playerBlue,
                                fontSize: font,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AskRoadLabel(
                              label: longhu ? '龙问路' : '庄问路',
                              color: _bankerRed,
                              fontSize: font,
                              preview: bankerAsk,
                            ),
                            SizedBox(width: font * 0.7),
                            _AskRoadLabel(
                              label: longhu ? '虎问路' : '闲问路',
                              color: _playerBlue,
                              fontSize: font,
                              preview: playerAsk,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoadmapGrid extends StatelessWidget {
  const _RoadmapGrid({
    required this.page,
    required this.markerRoad,
    required this.bigRoad,
    required this.derivedRoads,
    required this.stamp,
    required this.stampColor,
    required this.onTap,
  });

  final int page;
  final _Road markerRoad;
  final _Road bigRoad;
  final List<_Road> derivedRoads;
  final String? stamp;
  final Color stampColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stampWidget = stamp == null || stamp!.isEmpty
        ? null
        : _RoadStamp(stamp: stamp!, color: stampColor);
    return GestureDetector(
      key: const ValueKey('roadmap-page'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: switch (page) {
        0 => _ListStylePage(
          markerRoad: markerRoad,
          bigRoad: bigRoad,
          derivedRoads: derivedRoads,
          stamp: stampWidget,
        ),
        1 => _TitledMainPage(
          markerRoad: markerRoad,
          bigRoad: bigRoad,
          stamp: stampWidget,
        ),
        _ => _DerivedPage(roads: derivedRoads, stamp: stampWidget),
      },
    );
  }
}

class _ListStylePage extends StatelessWidget {
  const _ListStylePage({
    required this.markerRoad,
    required this.bigRoad,
    required this.derivedRoads,
    required this.stamp,
  });

  final _Road markerRoad;
  final _Road bigRoad;
  final List<_Road> derivedRoads;
  final Widget? stamp;

  @override
  Widget build(BuildContext context) {
    return RoadmapBoard(
      markerRoad: markerRoad.grid,
      bigRoad: bigRoad.grid,
      bigEyeRoad: derivedRoads[0].grid,
      cockroachRoad: derivedRoads[1].grid,
      smallRoad: derivedRoads[2].grid,
      secondBigRoad: derivedRoads[3].grid,
      spacing: RoadmapBoardSpacing.detail,
      trailingOverlay: stamp,
    );
  }
}

class _TitledMainPage extends StatelessWidget {
  const _TitledMainPage({
    required this.markerRoad,
    required this.bigRoad,
    required this.stamp,
  });

  final _Road markerRoad;
  final _Road bigRoad;
  final Widget? stamp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _DetailBoardMetrics.forRow(
          constraints.maxWidth,
          columns: detailBeadColumns + detailBigColumns,
          boards: 2,
        );
        final titleSize = (metrics.cell * listRoadCellHeightOverWidth * 1.25)
            .clamp(12.0, 28.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: metrics.boardWidth(detailBeadColumns),
              child: _RoadCard(
                key: const ValueKey('marker-road'),
                road: markerRoad,
                titleSize: titleSize,
                margin: metrics.margin,
              ),
            ),
            SizedBox(width: metrics.gap),
            Expanded(
              child: Stack(
                children: [
                  _RoadCard(
                    key: const ValueKey('big-road'),
                    road: bigRoad,
                    titleSize: titleSize,
                    margin: metrics.margin,
                  ),
                  if (stamp != null)
                    Positioned.fill(
                      child: IgnorePointer(child: Center(child: stamp)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DerivedPage extends StatelessWidget {
  const _DerivedPage({required this.roads, required this.stamp});

  final List<_Road> roads;
  final Widget? stamp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _DetailBoardMetrics.forRow(
          constraints.maxWidth,
          columns: detailDerivedColumns * 2,
          boards: 2,
          marginPerBoard: false,
        );
        final titleSize = (metrics.cell * listRoadCellHeightOverWidth * 0.9)
            .clamp(11.0, 22.0);
        final cardWidth = metrics.cell * detailDerivedColumns;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(metrics.margin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < roads.length; index += 2) ...[
                    if (index > 0) SizedBox(height: metrics.gap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final road in roads.skip(index).take(2)) ...[
                          if (road != roads[index])
                            SizedBox(width: metrics.gap),
                          SizedBox(
                            width: cardWidth,
                            child: _RoadCard(
                              key: ValueKey('road-${road.grid.type.name}'),
                              road: road,
                              titleSize: titleSize,
                              subcellGrid: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (stamp != null)
              Positioned.fill(
                child: IgnorePointer(child: Center(child: stamp)),
              ),
          ],
        );
      },
    );
  }
}

class _RoadStamp extends StatelessWidget {
  const _RoadStamp({required this.stamp, required this.color});

  final String stamp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 96.0;
        final fontSize = (height * 0.34).clamp(18.0, 32.0);
        return Transform.rotate(
          angle: -0.26,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.45,
              vertical: fontSize * 0.08,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
            ),
            child: Text(
              stamp,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Road {
  const _Road(this.title, this.grid, this.columns, this.rows);

  final String title;
  final RoadmapGrid grid;
  final int columns;
  final int rows;
}

/// Cell size for a row of titled detail boards, leaving a margin inside each
/// board and a small gap between them.
class _DetailBoardMetrics {
  const _DetailBoardMetrics({
    required this.cell,
    required this.margin,
    required this.gap,
  });

  final double cell;
  final double margin;
  final double gap;

  static _DetailBoardMetrics forRow(
    double width, {
    required int columns,
    required int boards,
    double marginOverCell = detailBoardMarginOverBeadCell,
    double gapOverCell = detailSectionGapOverBeadCell,
    bool marginPerBoard = true,
  }) {
    final gaps = boards <= 1 ? 0 : boards - 1;
    final marginSpans = marginPerBoard ? boards * 2 : 2;
    final units = columns + gaps * gapOverCell + marginSpans * marginOverCell;
    final cell = width <= 0 || units <= 0 ? 0.0 : width / units;
    return _DetailBoardMetrics(
      cell: cell,
      margin: cell * marginOverCell,
      gap: cell * gapOverCell,
    );
  }

  double boardWidth(int columns) => margin * 2 + cell * columns;

  double gridHeight(int rows) => cell * listRoadCellHeightOverWidth * rows;

  double cardHeight(int rows) => margin * 2 + gridHeight(rows);
}

class _RoadCard extends StatelessWidget {
  const _RoadCard({
    super.key,
    required this.road,
    required this.titleSize,
    this.margin = 0,
    this.subcellGrid = false,
  });

  final _Road road;
  final double titleSize;
  final double margin;
  final bool subcellGrid;

  @override
  Widget build(BuildContext context) {
    final fineCells = subcellGrid && road.grid.type == RoadmapType.secondBig;
    return Semantics(
      label: road.title,
      child: Padding(
        padding: EdgeInsets.all(margin),
        child: Stack(
          alignment: Alignment.center,
          children: [
            RoadmapGridView(
              key: ValueKey('road-grid-${road.grid.type.name}'),
              grid: road.grid,
              cellWidth: 12,
              cellHeight: 12,
              visibleRows: fineCells ? road.rows * 2 : road.rows,
              visibleColumns: fineCells ? road.columns * 2 : road.columns,
              heightOverWidth: listRoadCellHeightOverWidth,
              boardColor: listRoadBoardColor,
              gridLineColor: listRoadLineColor,
              gridLineWidth: 1,
              referenceMarkers: true,
              subcellGrid: subcellGrid && !fineCells,
            ),
            Text(
              road.title,
              style: TextStyle(
                color: roadTitleColor,
                fontSize: titleSize,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({
    required this.label,
    required this.count,
    required this.color,
    required this.fontSize,
  });

  final String label;
  final int count;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: fontSize * 0.45),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: fontSize, height: 1),
          children: [
            TextSpan(
              text: '$label:',
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: '$count',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskPreview {
  const _AskPreview({this.bigEye, this.smallRoad, this.cockroach});

  final Color? bigEye;
  final Color? smallRoad;
  final Color? cockroach;

  static _AskPreview from(List<RoadmapResult> results, String sideKey) {
    return _AskPreview(
      bigEye: _ink(_predictedAskColor(results, sideKey, calculateBigEyeRoad)),
      smallRoad: _ink(_predictedAskColor(results, sideKey, calculateSmallRoad)),
      cockroach: _ink(
        _predictedAskColor(results, sideKey, calculateCockroachRoad),
      ),
    );
  }
}

/// Color of the derived-road cell added by one hypothetical next result.
/// Uses the existing road functions and does not change their rules.
RoadmapMarkerColor? _predictedAskColor(
  List<RoadmapResult> results,
  String sideKey,
  RoadmapGrid Function(List<RoadmapResult> results) calculate,
) {
  final before = calculate(results);
  final after = calculate([
    ...results,
    RoadmapResult(key: sideKey, isGuess: true),
  ]);
  RoadmapMarkerColor? added;
  for (final entry in after.markers.entries) {
    final previous = before.markers[entry.key];
    if (previous == null || previous.color != entry.value.color) {
      added = entry.value.color;
    }
  }
  return added;
}

Color? _ink(RoadmapMarkerColor? color) => switch (color) {
  RoadmapMarkerColor.red => _bankerRed,
  RoadmapMarkerColor.blue => _playerBlue,
  _ => null,
};

class _AskRoadLabel extends StatelessWidget {
  const _AskRoadLabel({
    required this.label,
    required this.color,
    required this.fontSize,
    required this.preview,
  });

  final String label;
  final Color color;
  final double fontSize;
  final _AskPreview preview;

  @override
  Widget build(BuildContext context) {
    final mark = fontSize * 0.95;
    final symbols = <Widget>[
      if (preview.bigEye != null)
        _AskRing(color: preview.bigEye!, size: mark, label: label),
      if (preview.smallRoad != null)
        _AskDot(color: preview.smallRoad!, size: mark, label: label),
      if (preview.cockroach != null)
        _AskSlash(color: preview.cockroach!, size: mark, label: label),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: fontSize, height: 1),
        ),
        for (var index = 0; index < symbols.length; index++) ...[
          SizedBox(width: index == 0 ? mark * 0.38 : mark * 0.28),
          symbols[index],
        ],
      ],
    );
  }
}

class _AskRing extends StatelessWidget {
  const _AskRing({
    required this.color,
    required this.size,
    required this.label,
  });

  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('ask-ring-$label'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: (size * 0.14).clamp(1.0, 3.0)),
      ),
    );
  }
}

class _AskDot extends StatelessWidget {
  const _AskDot({required this.color, required this.size, required this.label});

  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('ask-dot-$label'),
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _AskSlash extends StatelessWidget {
  const _AskSlash({
    required this.color,
    required this.size,
    required this.label,
  });

  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('ask-slash-$label'),
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color),
            child: SizedBox(
              width: size * 0.92,
              height: math.max(1.4, size * 0.16),
            ),
          ),
        ),
      ),
    );
  }
}

const _bankerRed = Color(0xFFD52F38);
const _playerBlue = Color(0xFF245ED0);
const _tieGreen = Color(0xFF168A3A);

int _count(List<LobbyRoundResult> results, String key) =>
    results.where((result) => result.key.split('|').contains(key)).length;
