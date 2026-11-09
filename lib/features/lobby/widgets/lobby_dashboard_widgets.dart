import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/lobby_dashboard_data.dart';
import '../roadmap/roadmap_models.dart';
import '../roadmap/roadmap_painter.dart';

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

class LobbyDashboardHeader extends StatelessWidget {
  const LobbyDashboardHeader({
    super.key,
    required this.account,
    required this.balance,
    required this.onMenu,
  });

  final String account;
  final String balance;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080604),
      padding: const EdgeInsets.fromLTRB(10, 3.5, 5, 3.5),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '用户：${account.isEmpty ? '会员' : account}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  '总分：$balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppAssets.logo, width: 38, height: 38),
                const SizedBox(width: 5),
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '新世界在线',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFFF0CC79),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMenu,
            tooltip: '菜单',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu, color: Color(0xFFF0CC79), size: 30),
          ),
        ],
      ),
    );
  }
}

class LobbyAnnouncementBanner extends StatefulWidget {
  const LobbyAnnouncementBanner({super.key, required this.text});

  final String? text;

  @override
  State<LobbyAnnouncementBanner> createState() =>
      _LobbyAnnouncementBannerState();
}

class _LobbyAnnouncementBannerState extends State<LobbyAnnouncementBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.text?.trim().isNotEmpty == true
        ? widget.text!.trim()
        : '暂无公告';
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(3, 3.5, 3, 5),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xE91A1711),
        border: Border.all(color: const Color(0xAA9A7A37), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign_outlined,
            color: Color(0xFFE2C06B),
            size: 23,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final style = const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  );
                  final textScaler = MediaQuery.textScalerOf(context);
                  final textPainter = TextPainter(
                    text: TextSpan(text: message, style: style),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    textScaler: textScaler,
                  )..layout();
                  if (textPainter.width <= constraints.maxWidth) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(message, maxLines: 1, style: style),
                    );
                  }
                  const gap = 48.0;
                  final travel = textPainter.width + gap;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final offset = -_controller.value * travel;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: travel + textPainter.width,
                          maxWidth: travel + textPainter.width,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: textPainter.width,
                                child: Text(
                                  message,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                  textScaler: textScaler,
                                  style: style,
                                ),
                              ),
                              const SizedBox(width: gap),
                              SizedBox(
                                width: textPainter.width,
                                child: Text(
                                  message,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                  textScaler: textScaler,
                                  style: style,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LobbyGameCategoryTabs extends StatelessWidget {
  const LobbyGameCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<LobbyGameCategory> categories;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        children: [
          _CategoryTab(
            label: '全部',
            selected: selectedId == 0,
            onTap: () => onSelected(0),
          ),
          for (final category in categories)
            _CategoryTab(
              key: ValueKey(category.id),
              label: category.name,
              selected: selectedId == category.id,
              onTap: () => onSelected(category.id),
            ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF8A703D), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFF5888A8), Color(0xFF284E68)]
                  : const [Color(0xFF41677F), Color(0xFF203D52)],
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF101820),
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class LobbyGameTableSection extends StatelessWidget {
  const LobbyGameTableSection({
    super.key,
    required this.desk,
    required this.isTrial,
    required this.onEnter,
  });

  final LobbyDeskDashboardData desk;
  final bool isTrial;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = math.max(0, constraints.maxWidth - 3);
        final markerWidth = rowWidth * 0.31;
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(color: Color(0xFF050505)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF191710), Color(0xFF080807)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${desk.gameName}${desk.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF1E7D2),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final statistic in desk.statistics)
                      Expanded(
                        flex: 1,
                        child: _StatisticText(statistic: statistic),
                      ),
                    _DeskStatusLabel(
                      label: desk.statusLabel,
                      status: desk.status,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: markerWidth,
                          child: RoadmapGridView(
                            grid: desk.markerRoad,
                            cellWidth: 14,
                            cellHeight: 14,
                            visibleRows: beadPlateRows,
                            visibleColumns: beadPlateColumns,
                            squareCells: true,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, roadConstraints) {
                              final wideDerivedRoadWidth =
                                  roadConstraints.maxWidth *
                                  bigEyeBoyColumns /
                                  bigRoadColumns;
                              final narrowDerivedRoadWidth =
                                  roadConstraints.maxWidth -
                                  wideDerivedRoadWidth;
                              final derivedCellHeight =
                                  roadConstraints.maxWidth / bigRoadColumns;
                              return Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      RoadmapGridView(
                                        grid: desk.bigRoad,
                                        cellWidth: 12,
                                        cellHeight: 12,
                                        visibleRows: bigRoadRows,
                                        visibleColumns: bigRoadColumns,
                                        squareCells: true,
                                      ),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: wideDerivedRoadWidth,
                                            child: RoadmapGridView(
                                              grid: desk.bigEyeRoad,
                                              cellWidth: 12,
                                              cellHeight: 12,
                                              visibleRows: bigEyeBoyRows,
                                              visibleColumns: bigEyeBoyColumns,
                                              squareCells: true,
                                            ),
                                          ),
                                          SizedBox(
                                            width: narrowDerivedRoadWidth,
                                            child: RoadmapGridView(
                                              grid: desk.cockroachRoad,
                                              cellWidth: 12,
                                              cellHeight: derivedCellHeight,
                                              visibleRows: cockroachPigRows,
                                              visibleColumns:
                                                  cockroachPigColumns,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: wideDerivedRoadWidth,
                                            child: RoadmapGridView(
                                              grid: desk.smallRoad,
                                              cellWidth: 12,
                                              cellHeight: 12,
                                              visibleRows: smallRoadRows,
                                              visibleColumns: smallRoadColumns,
                                              squareCells: true,
                                            ),
                                          ),
                                          SizedBox(
                                            width: narrowDerivedRoadWidth,
                                            child: RoadmapGridView(
                                              grid: desk.secondBigRoad,
                                              cellWidth: 12,
                                              cellHeight: derivedCellHeight,
                                              visibleRows: secondBigRoadRows,
                                              visibleColumns:
                                                  secondBigRoadColumns,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (desk.resultCount == 0)
                                    const Positioned.fill(
                                      child: IgnorePointer(
                                        child: Center(
                                          child: Text(
                                            '暂无路单',
                                            style: TextStyle(
                                              color: Color(0xFF686868),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (isTrial)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: Center(child: _TrialWatermark()),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 27),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '限红 ${desk.minBet}-${desk.maxBet}',
                        style: const TextStyle(
                          color: Color(0xFFD8C99F),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text(
                      '共 ${desk.resultCount} 局',
                      style: const TextStyle(
                        color: Color(0xFFD8C99F),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 5),
                child: SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: onEnter,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: desk.gameType.toUpperCase() == 'BACCARAT'
                          ? const Color(0xFF176443)
                          : const Color(0xFF744344),
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                      side: const BorderSide(color: Color(0x99E8C872)),
                    ),
                    child: const Text(
                      '进入牌桌',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LobbyStateMessage extends StatelessWidget {
  const LobbyStateMessage({
    super.key,
    required this.message,
    this.error = false,
    this.onRetry,
  });

  final String message;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: error ? const Color(0xFFFFB8A8) : CasinoColors.muted,
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatisticText extends StatelessWidget {
  const _StatisticText({required this.statistic});

  final LobbyOutcomeStat statistic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${statistic.label} ${statistic.count}',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13),
            children: [
              TextSpan(
                text: '${statistic.label}:',
                style: TextStyle(color: _roadColor(statistic.color)),
              ),
              TextSpan(
                text: '${statistic.count}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskStatusLabel extends StatelessWidget {
  const _DeskStatusLabel({required this.label, required this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'betting'
        ? const Color(0xFF64D79A)
        : status == 'dealing'
        ? const Color(0xFFFF9A7B)
        : const Color(0xFFE3C66E);
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF17140D),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrialWatermark extends StatelessWidget {
  const _TrialWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x99EF3038), width: 1.6),
      ),
      child: const Text(
        '试玩中',
        style: TextStyle(
          color: Color(0xB3EF3038),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

Color _roadColor(RoadmapMarkerColor color) => switch (color) {
  RoadmapMarkerColor.red => const Color(0xFFD52F38),
  RoadmapMarkerColor.blue => const Color(0xFF245ED0),
  RoadmapMarkerColor.green => const Color(0xFF168A3A),
  RoadmapMarkerColor.black => Colors.black,
};
