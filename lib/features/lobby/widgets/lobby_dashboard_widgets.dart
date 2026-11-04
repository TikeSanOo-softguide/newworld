import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/lobby_dashboard_data.dart';
import '../roadmap/roadmap_models.dart';
import '../roadmap/roadmap_painter.dart';

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
      padding: const EdgeInsets.fromLTRB(10, 7, 5, 7),
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
      margin: const EdgeInsets.fromLTRB(3, 5, 3, 5),
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
                  final textPainter = TextPainter(
                    text: TextSpan(text: message, style: style),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
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
                            children: [
                              Text(message, maxLines: 1, style: style),
                              const SizedBox(width: gap),
                              Text(message, maxLines: 1, style: style),
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
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 96),
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
        final innerWidth = math.max(0, constraints.maxWidth - 10);
        final markerWidth = (innerWidth * 0.29).clamp(76.0, 112.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: const BoxDecoration(color: Color(0xFF050505)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF241D10), Color(0xFF090807)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                    _DeskStatusLabel(
                      label: desk.statusLabel,
                      status: desk.status,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < desk.statistics.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Container(
                          width: 1,
                          height: 17,
                          color: const Color(0x55474747),
                        ),
                      Expanded(
                        child: _StatisticText(
                          statistic: desk.statistics[index],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                height: 168,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: markerWidth,
                      child: RoadmapGridView(
                        grid: desk.markerRoad,
                        cellWidth: 28,
                        cellHeight: 28,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              RoadmapGridView(
                                grid: desk.bigRoad,
                                cellWidth: 14,
                                cellHeight: 14,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: RoadmapGridView(
                                      grid: desk.bigEyeRoad,
                                      cellWidth: 14,
                                      cellHeight: 14,
                                    ),
                                  ),
                                  Expanded(
                                    child: RoadmapGridView(
                                      grid: desk.cockroachRoad,
                                      cellWidth: 14,
                                      cellHeight: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: RoadmapGridView(
                                      grid: desk.smallRoad,
                                      cellWidth: 14,
                                      cellHeight: 14,
                                    ),
                                  ),
                                  Expanded(
                                    child: RoadmapGridView(
                                      grid: desk.secondBigRoad,
                                      cellWidth: 14,
                                      cellHeight: 14,
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
                          if (isTrial)
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: Center(child: _TrialWatermark()),
                              ),
                            ),
                        ],
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
                text: '${statistic.label} ',
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
        color: const Color(0xEFFFFFFF),
        border: Border.all(color: const Color(0xFFEF3038), width: 1.6),
      ),
      child: const Text(
        '试玩中',
        style: TextStyle(
          color: Color(0xFFEF3038),
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
