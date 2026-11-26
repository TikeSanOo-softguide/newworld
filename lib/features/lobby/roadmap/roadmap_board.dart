import 'package:flutter/material.dart';

import 'roadmap_metrics.dart';
import 'roadmap_models.dart';
import 'roadmap_painter.dart';

/// Bead plate plus the four roads stacked beside it.
///
/// The list card and detail page 1 both use this board, so the cell size,
/// gap, and column counts cannot drift apart.
class RoadmapBoard extends StatelessWidget {
  const RoadmapBoard({
    super.key,
    required this.markerRoad,
    required this.bigRoad,
    required this.bigEyeRoad,
    required this.smallRoad,
    required this.cockroachRoad,
    required this.secondBigRoad,
    this.boardColor = listRoadBoardColor,
    this.lineColor = listRoadLineColor,
    this.spacing = RoadmapBoardSpacing.detail,
    this.trailingOverlay,
  });

  final RoadmapGrid markerRoad;
  final RoadmapGrid bigRoad;
  final RoadmapGrid bigEyeRoad;
  final RoadmapGrid smallRoad;
  final RoadmapGrid cockroachRoad;
  final RoadmapGrid secondBigRoad;
  final Color boardColor;
  final Color lineColor;
  final RoadmapBoardSpacing spacing;
  final Widget? trailingOverlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final beadCellWidth = spacing.beadCellWidth(constraints.maxWidth);
        final margin = spacing.margin(beadCellWidth);
        final boardGap = spacing.boardGap(beadCellWidth);
        final sectionGap = spacing.sectionGap(beadCellWidth);
        final rightHeightOverWidth = spacing.rightHeightOverWidth(
          beadCellWidth,
        );
        return ColoredBox(
          color: boardColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: margin * 2 + beadCellWidth * beadPlateColumns,
                child: Padding(
                  padding: EdgeInsets.all(margin),
                  child: _grid(
                    markerRoad,
                    rows: beadPlateRows,
                    columns: beadPlateColumns,
                    cellWidth: beadCellWidth,
                  ),
                ),
              ),
              SizedBox(width: boardGap),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: margin),
                  child: LayoutBuilder(
                    builder: (context, roadConstraints) {
                      final wideDerivedRoadWidth =
                          roadConstraints.maxWidth *
                          bigEyeBoyColumns /
                          bigRoadColumns;
                      final narrowDerivedRoadWidth =
                          roadConstraints.maxWidth - wideDerivedRoadWidth;
                      return Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: margin),
                                child: KeyedSubtree(
                                  key: const ValueKey('big-road'),
                                  child: _grid(
                                    bigRoad,
                                    rows: bigRoadRows,
                                    columns: bigRoadColumns,
                                    heightOverWidth: rightHeightOverWidth,
                                  ),
                                ),
                              ),
                              SizedBox(height: sectionGap),
                              Padding(
                                padding: EdgeInsets.only(bottom: margin),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: wideDerivedRoadWidth,
                                          child: _grid(
                                            bigEyeRoad,
                                            rows: bigEyeBoyRows,
                                            columns: bigEyeBoyColumns,
                                            heightOverWidth:
                                                rightHeightOverWidth,
                                          ),
                                        ),
                                        SizedBox(
                                          width: narrowDerivedRoadWidth,
                                          child: _grid(
                                            cockroachRoad,
                                            rows: cockroachPigRows,
                                            columns: cockroachPigColumns,
                                            heightOverWidth:
                                                rightHeightOverWidth,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: wideDerivedRoadWidth,
                                          child: _grid(
                                            smallRoad,
                                            rows: smallRoadRows,
                                            columns: smallRoadColumns,
                                            heightOverWidth:
                                                rightHeightOverWidth,
                                          ),
                                        ),
                                        SizedBox(
                                          width: narrowDerivedRoadWidth,
                                          child: _grid(
                                            secondBigRoad,
                                            rows: secondBigRoadRows,
                                            columns: secondBigRoadColumns,
                                            heightOverWidth:
                                                rightHeightOverWidth,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (trailingOverlay != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(child: trailingOverlay),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _grid(
    RoadmapGrid grid, {
    required int rows,
    required int columns,
    double? cellWidth,
    double heightOverWidth = listRoadCellHeightOverWidth,
  }) {
    return RoadmapGridView(
      key: ValueKey('road-grid-${grid.type.name}'),
      grid: grid,
      cellWidth: cellWidth ?? 12,
      cellHeight: 12,
      visibleRows: rows,
      visibleColumns: columns,
      heightOverWidth: heightOverWidth,
      boardColor: boardColor,
      gridLineColor: lineColor,
      gridLineWidth: 1,
      referenceMarkers: true,
    );
  }
}
