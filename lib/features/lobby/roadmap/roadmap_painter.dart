import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'roadmap_models.dart';

class RoadmapGridView extends StatelessWidget {
  const RoadmapGridView({
    super.key,
    required this.grid,
    required this.cellWidth,
    required this.cellHeight,
    this.visibleRows,
    this.visibleColumns,
    this.squareCells = false,
    this.heightOverWidth,
    this.boardColor = const Color(0xFFFFFFFF),
    this.gridLineColor = const Color(0xFF858585),
    this.gridLineWidth = 0.65,
    this.referenceMarkers = false,
    this.subcellGrid = false,
  });

  final RoadmapGrid grid;
  final double cellWidth;
  final double cellHeight;
  final int? visibleRows;
  final int? visibleColumns;
  final bool squareCells;

  /// Cell height divided by cell width. The lobby still uses 28/32.
  final double? heightOverWidth;
  final Color boardColor;
  final Color gridLineColor;
  final double gridLineWidth;

  /// List-page marker size, stroke, and color taken from the roadmap reference.
  final bool referenceMarkers;

  /// Draws a line through the middle of each logical cell. Derived-road
  /// markers already sit in those halves. Detail page 3 uses this so the
  /// empty board matches the fine reference grid. The list board does not.
  final bool subcellGrid;

  int get _visualRows =>
      visibleRows ??
      switch (grid.type) {
        RoadmapType.bigEye || RoadmapType.small || RoadmapType.cockroach => 3,
        _ => grid.rowCount,
      };

  @override
  Widget build(BuildContext context) {
    final defaultHeight = cellHeight * _visualRows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnLimit = visibleColumns;
        if (columnLimit == null) {
          final contentWidth = math.max(
            constraints.maxWidth,
            cellWidth * grid.columnCount,
          );
          return SizedBox(
            height: defaultHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: defaultHeight,
                child: _gridPaint(cellWidth),
              ),
            ),
          );
        }

        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : cellWidth * columnLimit;
        final displayCellWidth = viewportWidth / columnLimit;
        final displayCellHeight = heightOverWidth != null
            ? displayCellWidth * heightOverWidth!
            : (squareCells ? displayCellWidth : cellHeight);
        final displayHeight = displayCellHeight * _visualRows;
        final displayGrid = _slidingWindowGrid(grid, columnLimit);
        return SizedBox(
          width: viewportWidth,
          height: displayHeight,
          child: _gridPaint(
            displayCellWidth,
            displayGrid: displayGrid,
            visualRows: _visualRows,
            height: displayHeight,
            paintCellHeight: displayCellHeight,
          ),
        );
      },
    );
  }

  RoadmapGrid _slidingWindowGrid(RoadmapGrid source, int columnLimit) {
    var dataColumnCount = 0;
    for (final position in source.markers.keys) {
      dataColumnCount = math.max(dataColumnCount, position.col + 1);
    }

    final firstVisibleColumn = math.max(0, dataColumnCount - columnLimit);
    final visibleMarkers = <RoadmapPosition, RoadmapMarker>{};
    for (final entry in source.markers.entries) {
      if (entry.key.col < firstVisibleColumn ||
          entry.key.col >= firstVisibleColumn + columnLimit) {
        continue;
      }
      visibleMarkers[RoadmapPosition(
            col: entry.key.col - firstVisibleColumn,
            row: entry.key.row,
            subCol: entry.key.subCol,
          )] =
          entry.value;
    }

    return RoadmapGrid(
      type: source.type,
      rowCount: source.rowCount,
      columnCount: columnLimit,
      markers: visibleMarkers,
    );
  }

  Widget _gridPaint(
    double width, {
    RoadmapGrid? displayGrid,
    int? visualRows,
    double? height,
    double? paintCellHeight,
  }) {
    final gridPainter = RoadmapGridPainter(
      grid: displayGrid ?? grid,
      cellWidth: width,
      cellHeight: paintCellHeight ?? cellHeight,
      visualRows: visualRows ?? _visualRows,
      boardColor: boardColor,
      gridLineColor: gridLineColor,
      gridLineWidth: gridLineWidth,
      referenceMarkers: referenceMarkers,
      subcellGrid: subcellGrid,
    );
    if (displayGrid == null) {
      return CustomPaint(
        painter: gridPainter,
        isComplex: true,
        willChange: false,
      );
    }
    return CustomPaint(
      size: Size(width * displayGrid.columnCount, height!),
      painter: gridPainter,
      isComplex: true,
      willChange: false,
    );
  }
}

class RoadmapGridPainter extends CustomPainter {
  const RoadmapGridPainter({
    required this.grid,
    required this.cellWidth,
    required this.cellHeight,
    required this.visualRows,
    this.boardColor = const Color(0xFFFFFFFF),
    this.gridLineColor = const Color(0xFF858585),
    this.gridLineWidth = 0.65,
    this.referenceMarkers = false,
    this.subcellGrid = false,
  });

  final RoadmapGrid grid;
  final double cellWidth;
  final double cellHeight;
  final int visualRows;
  final Color boardColor;
  final Color gridLineColor;
  final double gridLineWidth;
  final bool referenceMarkers;
  final bool subcellGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(boardRect);

    canvas.drawRect(boardRect, Paint()..color = boardColor);
    _drawGridLines(canvas, size);
    for (final entry in grid.markers.entries) {
      _drawMarker(canvas, entry.key, entry.value);
    }

    canvas.restore();
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = gridLineWidth;
    final subdivisions = subcellGrid ? 2 : 1;
    final columnLines = grid.columnCount * subdivisions;
    final rowLines = visualRows * subdivisions;
    final columnStep = cellWidth / subdivisions;
    final rowStep = cellHeight / subdivisions;

    for (var col = 0; col <= columnLines; col++) {
      final x = col * columnStep;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var row = 0; row <= rowLines; row++) {
      final y = row * rowStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  void _drawMarker(
    Canvas canvas,
    RoadmapPosition position,
    RoadmapMarker marker,
  ) {
    if (grid.type == RoadmapType.noLShapeBase) return;

    final isDerived =
        grid.type == RoadmapType.bigEye ||
        grid.type == RoadmapType.small ||
        grid.type == RoadmapType.cockroach;
    final center = isDerived
        ? Offset(
            position.col * cellWidth + (position.subCol + 0.5) * cellWidth / 2,
            (position.row ~/ 2) * cellHeight +
                (position.row % 2 + 0.5) * cellHeight / 2,
          )
        : Offset(
            position.col * cellWidth + cellWidth / 2,
            position.row * cellHeight + cellHeight / 2,
          );
    final cellWidthForMarker = isDerived ? cellWidth / 2 : cellWidth;
    final cellHeightForMarker = isDerived ? cellHeight / 2 : cellHeight;
    final color =
        _colorFor(marker.color) ??
        (grid.type == RoadmapType.big
            ? const Color(0xFF2467D1)
            : const Color(0xFF2467D1));

    switch (marker.shape) {
      case RoadmapMarkerShape.ring:
        final span = math.min(cellWidthForMarker, cellHeightForMarker);
        // Reference rings are circles. Bead rings are 90% of the shorter
        // cell side. Big-road rings are 85% of the longer side, which meets
        // the top and bottom grid lines of the shorter cell.
        final radius = referenceMarkers
            ? switch (grid.type) {
                RoadmapType.bigEye => span * 0.36,
                RoadmapType.marker => span * 0.46,
                RoadmapType.big || RoadmapType.secondBig => span * 0.44,
                _ => span * 0.42,
              }
            : switch (grid.type) {
                RoadmapType.bigEye => span * 0.40,
                RoadmapType.marker ||
                RoadmapType.big ||
                RoadmapType.secondBig => span * 0.42,
                _ => span * 0.38,
              };
        final strokeWidth = referenceMarkers
            ? math.max(1.0, radius * 0.16)
            : (grid.type == RoadmapType.marker ? 1.8 : 1.45);
        if (marker.color != null) {
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth,
          );
        }
        if (marker.label != null && marker.label!.isNotEmpty) {
          final fontSize = referenceMarkers
              ? math.max(8.0, radius * 1.35)
              : math.max(6.0, math.min(13.0, radius * 1.05));
          _drawText(canvas, marker.label!, center, color, fontSize, bold: true);
        }
        if (marker.isBankerPair) {
          _drawPairDot(canvas, center, radius, const Color(0xFFE03B3B), true);
        }
        if (marker.isPlayerPair) {
          _drawPairDot(canvas, center, radius, const Color(0xFF2868CF), false);
        }
        if (marker.tieCount > 0) {
          _drawTie(canvas, center, radius, marker);
        }
      case RoadmapMarkerShape.solid:
        canvas.drawCircle(
          center,
          math.min(cellWidthForMarker, cellHeightForMarker) * 0.36,
          Paint()..color = color,
        );
      case RoadmapMarkerShape.slash:
        final slashPaint = Paint()
          ..color = color
          ..strokeWidth = math.max(
            1.2,
            math.min(cellWidthForMarker, cellHeightForMarker) * 0.18,
          )
          ..strokeCap = StrokeCap.square;
        final half = math.min(cellWidthForMarker, cellHeightForMarker) * 0.38;
        canvas.drawLine(
          Offset(center.dx - half, center.dy + half),
          Offset(center.dx + half, center.dy - half),
          slashPaint,
        );
    }
  }

  void _drawPairDot(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    bool banker,
  ) {
    final offset = radius * 0.72;
    final point = banker
        ? Offset(center.dx - offset, center.dy - offset)
        : Offset(center.dx + offset, center.dy + offset);
    canvas.drawCircle(
      point,
      math.max(1.6, radius * 0.28),
      Paint()..color = color,
    );
  }

  void _drawTie(
    Canvas canvas,
    Offset center,
    double radius,
    RoadmapMarker marker,
  ) {
    final tiePaint = Paint()
      ..color = referenceMarkers
          ? const Color(0xFF0E7A0C)
          : const Color(0xFF13B832)
      ..strokeWidth = math.max(1.4, radius * 0.42)
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(center.dx - radius * 0.88, center.dy + radius * 0.88),
      Offset(center.dx + radius * 0.88, center.dy - radius * 0.18),
      tiePaint,
    );
    _drawText(
      canvas,
      '${marker.tieCount}',
      center,
      _colorFor(marker.tieCountColor) ?? const Color(0xFF2467D1),
      math.max(6, radius * 0.65),
      bold: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cellWidth);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  Color? _colorFor(RoadmapMarkerColor? color) => switch (color) {
    RoadmapMarkerColor.red =>
      referenceMarkers ? const Color(0xFFC41E22) : const Color(0xFFD52F38),
    RoadmapMarkerColor.blue =>
      referenceMarkers ? const Color(0xFF1A28E8) : const Color(0xFF245ED0),
    RoadmapMarkerColor.green =>
      referenceMarkers ? const Color(0xFF0E7A0C) : const Color(0xFF168A3A),
    RoadmapMarkerColor.black => const Color(0xFF111111),
    null => null,
  };

  @override
  bool shouldRepaint(covariant RoadmapGridPainter oldDelegate) =>
      oldDelegate.grid != grid ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight ||
      oldDelegate.visualRows != visualRows ||
      oldDelegate.boardColor != boardColor ||
      oldDelegate.gridLineColor != gridLineColor ||
      oldDelegate.gridLineWidth != gridLineWidth ||
      oldDelegate.referenceMarkers != referenceMarkers ||
      oldDelegate.subcellGrid != subcellGrid;
}
