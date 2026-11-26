import 'package:flutter/material.dart';

const beadPlateRows = 6;
const beadPlateColumns = 6;
const bigRoadRows = 6;
const bigRoadColumns = 27;
const bigEyeBoyRows = 3;
const bigEyeBoyColumns = 14;
const cockroachPigRows = 3;
const cockroachPigColumns = 13;
const smallRoadRows = 3;
const smallRoadColumns = 14;
const secondBigRoadRows = 3;
const secondBigRoadColumns = 13;

/// Bead cells are 32 px wide by 28 px tall in the lobby reference.
/// Big-road and derived cells are half of that on both axes.
const listRoadCellHeightOverWidth = 28 / 32;

/// Gap between the bead plate and the Big Road on the list page, as a
/// fraction of one bead cell.
const listRoadGapOverBeadCell = 17 / 90;

/// White space between a board edge and its grid lines, in bead-cell widths.
/// The facing margins are the gutter between the bead plate and the big road,
/// about one fifth of a bead cell, matching the reference.
const detailBoardMarginOverBeadCell = 0.10;

/// Extra space between the two boards, beyond each board's inner margin.
const detailBoardGapOverBeadCell = 0.0;

/// Small white gap between the big road and the derived roads, in bead-cell
/// widths. About 4 px on a 1024-wide board. List and detail share it.
const detailSectionGapOverBeadCell = 0.08;

/// Spacing of one roadmap board. List and detail share it.
class RoadmapBoardSpacing {
  const RoadmapBoardSpacing({
    this.marginOverBeadCell = 0,
    this.boardGapOverBeadCell = listRoadGapOverBeadCell,
    this.sectionGapOverBeadCell = 0,
  });

  final double marginOverBeadCell;
  final double boardGapOverBeadCell;
  final double sectionGapOverBeadCell;

  static const detail = RoadmapBoardSpacing(
    marginOverBeadCell: detailBoardMarginOverBeadCell,
    boardGapOverBeadCell: detailBoardGapOverBeadCell,
    sectionGapOverBeadCell: detailSectionGapOverBeadCell,
  );

  double beadCellWidth(double width) {
    final units =
        4 * marginOverBeadCell +
        boardGapOverBeadCell +
        beadPlateColumns +
        bigRoadColumns / 2;
    return width / units;
  }

  double margin(double beadCellWidth) => marginOverBeadCell * beadCellWidth;

  double boardGap(double beadCellWidth) => boardGapOverBeadCell * beadCellWidth;

  double sectionGap(double beadCellWidth) =>
      sectionGapOverBeadCell * beadCellWidth;

  /// Big-road and derived cells stay half as wide as a bead. Their height
  /// gives up [sectionGap] so the right column matches the bead plate.
  double rightHeightOverWidth(double beadCellWidth) {
    final gridHeight =
        beadCellWidth * listRoadCellHeightOverWidth * beadPlateRows;
    final halfRows = bigRoadRows + bigEyeBoyRows + smallRoadRows;
    final cellHeight = (gridHeight - sectionGap(beadCellWidth)) / halfRows;
    return cellHeight / (beadCellWidth / 2);
  }

  double height(double width) {
    final bead = beadCellWidth(width);
    return margin(bead) * 2 +
        bead * listRoadCellHeightOverWidth * beadPlateRows;
  }
}

const listRoadBoardColor = Color(0xFFFFFFFF);
const listRoadLineColor = Color(0xFF9A9A9A);

const roadTitleColor = Color(0xFF999999);
