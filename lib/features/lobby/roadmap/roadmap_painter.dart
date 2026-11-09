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
  });

  final RoadmapGrid grid;
  final double cellWidth;
  final double cellHeight;
  final int? visibleRows;
  final int? visibleColumns;
  final bool squareCells;

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
        final displayCellHeight = squareCells ? displayCellWidth : cellHeight;
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
  });

  final RoadmapGrid grid;
  final double cellWidth;
  final double cellHeight;
  final int visualRows;

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(boardRect);

    canvas.drawRect(boardRect, Paint()..color = const Color(0xFFFFFFFF));
    _drawGridLines(canvas, size);
    for (final entry in grid.markers.entries) {
      _drawMarker(canvas, entry.key, entry.value);
    }

    canvas.restore();
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF858585)
      ..strokeWidth = 0.65;

    for (var col = 0; col <= grid.columnCount; col++) {
      final x = col * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var row = 0; row <= visualRows; row++) {
      final y = row * cellHeight;
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
        final radius = switch (grid.type) {
          RoadmapType.bigEye =>
            math.min(cellWidthForMarker, cellHeightForMarker) * 0.28,
          RoadmapType.marker || RoadmapType.big || RoadmapType.secondBig =>
            math.min(cellWidthForMarker, cellHeightForMarker) * 0.40,
          _ => math.min(cellWidthForMarker, cellHeightForMarker) * 0.38,
        };
        if (marker.color != null) {
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = grid.type == RoadmapType.marker ? 1.8 : 1.45,
          );
        }
        if (marker.label != null && marker.label!.isNotEmpty) {
          _drawText(
            canvas,
            marker.label!,
            center,
            color,
            math.max(6, math.min(13, radius * 1.05)),
            bold: true,
          );
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
          math.min(cellWidthForMarker, cellHeightForMarker) * 0.24,
          Paint()..color = color,
        );
      case RoadmapMarkerShape.slash:
        final slashPaint = Paint()
          ..color = color
          ..strokeWidth = math.max(
            1.2,
            math.min(cellWidthForMarker, cellHeightForMarker) * 0.14,
          )
          ..strokeCap = StrokeCap.square;
        final half = math.min(cellWidthForMarker, cellHeightForMarker) * 0.25;
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
      ..color = const Color(0xFF13B832)
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
    RoadmapMarkerColor.red => const Color(0xFFD52F38),
    RoadmapMarkerColor.blue => const Color(0xFF245ED0),
    RoadmapMarkerColor.green => const Color(0xFF168A3A),
    RoadmapMarkerColor.black => const Color(0xFF111111),
    null => null,
  };

  @override
  bool shouldRepaint(covariant RoadmapGridPainter oldDelegate) =>
      oldDelegate.grid != grid ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight ||
      oldDelegate.visualRows != visualRows;
}
