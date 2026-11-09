import 'package:flutter/material.dart';

import '../../lobby/models/lobby_round_result.dart';
import '../../lobby/roadmap/roadmap_calculations.dart';
import '../../lobby/roadmap/roadmap_models.dart';
import '../../lobby/roadmap/roadmap_painter.dart';

class BaccaratRoadmapPanel extends StatelessWidget {
  const BaccaratRoadmapPanel({super.key, required this.results});

  final List<LobbyRoundResult> results;

  @override
  Widget build(BuildContext context) {
    final roadmapResults = results
        .map((result) => RoadmapResult(key: result.key))
        .toList(growable: false);
    final markerRoad = _Road('珠盘路', calculateMarkerRoad(roadmapResults));
    final bigRoad = _Road('大路', calculateBigRoad(roadmapResults));
    final derivedRoads = [
      _Road('大眼仔', calculateBigEyeRoad(roadmapResults)),
      _Road('小路', calculateSmallRoad(roadmapResults)),
      _Road('曱甴路', calculateCockroachRoad(roadmapResults)),
      _Road('第二大路', calculateSecondBigRoad(roadmapResults)),
    ];
    final banker = _count(results, 'banker');
    final player = _count(results, 'player');
    final tie = _count(results, 'tie');
    final bankerPair = _count(results, 'bankerPair');
    final playerPair = _count(results, 'playerPair');

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth / 22).clamp(16.0, 20.0);
        return Container(
          margin: const EdgeInsets.fromLTRB(6, 2, 6, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF89939B)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth * 0.32,
                      child: _RoadCard(
                        key: const ValueKey('marker-road'),
                        road: markerRoad,
                        cellSize: cellSize,
                        rows: 6,
                      ),
                    ),
                    Expanded(
                      child: _RoadCard(
                        key: const ValueKey('big-road'),
                        road: bigRoad,
                        cellSize: cellSize,
                        rows: 6,
                      ),
                    ),
                  ],
                ),
              ),
              for (var index = 0; index < derivedRoads.length; index += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final road in derivedRoads.skip(index).take(2))
                        Expanded(
                          child: _RoadCard(
                            key: ValueKey('road-${road.grid.type.name}'),
                            road: road,
                            cellSize: cellSize,
                            rows: 3,
                          ),
                        ),
                    ],
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                  border: Border(top: BorderSide(color: Color(0xFFB7B7B7))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _CountLabel(label: '庄', count: banker, color: _bankerRed),
                    _CountLabel(label: '闲', count: player, color: _playerBlue),
                    _CountLabel(label: '和', count: tie, color: _tieGreen),
                    _CountLabel(
                      label: '庄对',
                      count: bankerPair,
                      color: _bankerRed,
                    ),
                    _CountLabel(
                      label: '闲对',
                      count: playerPair,
                      color: _playerBlue,
                    ),
                    Text(
                      '共 ${results.length} 局',
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const _RoadLegend(),
            ],
          ),
        );
      },
    );
  }
}

class _Road {
  const _Road(this.title, this.grid);

  final String title;
  final RoadmapGrid grid;
}

class _RoadCard extends StatelessWidget {
  const _RoadCard({
    super.key,
    required this.road,
    required this.cellSize,
    required this.rows,
  });

  final _Road road;
  final double cellSize;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: road.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 19,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4F4),
              border: Border(
                bottom: BorderSide(color: Color(0xFF9B9B9B), width: 0.7),
                right: BorderSide(color: Color(0xFF9B9B9B), width: 0.7),
              ),
            ),
            child: Text(
              road.title,
              style: const TextStyle(
                color: Color(0xFF53606A),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: cellSize * rows,
            child: RoadmapGridView(
              key: ValueKey('road-grid-${road.grid.type.name}'),
              grid: road.grid,
              cellWidth: cellSize,
              cellHeight: cellSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12),
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
    );
  }
}

class _RoadLegend extends StatelessWidget {
  const _RoadLegend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 5, 8, 7),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _LegendItem(color: _bankerRed, label: '庄路'),
          _LegendItem(color: _playerBlue, label: '闲路'),
          _LegendItem(color: _tieGreen, label: '和局'),
          _PairLegend(label: '庄对'),
          _PairLegend(label: '闲对', right: true),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF333333), fontSize: 10),
        ),
      ],
    );
  }
}

class _PairLegend extends StatelessWidget {
  const _PairLegend({required this.label, this.right = false});

  final String label;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: right ? _playerBlue : _bankerRed),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF333333), fontSize: 10),
        ),
      ],
    );
  }
}

const _bankerRed = Color(0xFFD52F38);
const _playerBlue = Color(0xFF245ED0);
const _tieGreen = Color(0xFF168A3A);

int _count(List<LobbyRoundResult> results, String key) =>
    results.where((result) => result.key.split('|').contains(key)).length;
