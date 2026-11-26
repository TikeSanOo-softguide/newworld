import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/lobby_dashboard_data.dart';
import '../roadmap/roadmap_board.dart';
import '../roadmap/roadmap_metrics.dart';
import '../roadmap/roadmap_models.dart';

export '../roadmap/roadmap_metrics.dart';

/// Dim wash used only while 洗牌中... is showing. Other desks stay sharp.
const listShuffleBoardColor = Color(0xFF808483);
const listShuffleLineColor = Color(0xFF565A59);

const _lobbyGold = Color(0xFFF0CC79);
const _lobbyReferenceWidth = 640.0;

/// Sizes below match the 640-wide lobby reference. Other widths scale them so
/// the header, tabs, and announcement keep that proportion to the roads.
double lobbyChromeScale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width <= 0) return 1;
  return (width / _lobbyReferenceWidth).clamp(0.6, 1.7);
}

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
    final scale = lobbyChromeScale(context);
    final userStyle = TextStyle(
      color: const Color(0xFFF4F1EA),
      fontSize: 15 * scale,
      height: 1.15,
    );
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050301), Color(0xFF100E0A), Color(0xFF2A2214)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        16 * scale,
        8 * scale,
        14 * scale,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '用户：${account.isEmpty ? '会员' : account}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: userStyle,
                ),
                SizedBox(height: 3 * scale),
                Text(
                  '总分：$balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: userStyle,
                ),
              ],
            ),
          ),
          Image.asset(AppAssets.logo, width: 46 * scale, height: 46 * scale),
          SizedBox(width: 6 * scale),
          Text(
            '新世界在线',
            maxLines: 1,
            style: TextStyle(
              color: _lobbyGold,
              fontSize: 22 * scale,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onMenu,
                tooltip: '菜单',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.all(6 * scale),
                constraints: BoxConstraints(
                  minWidth: 36 * scale,
                  minHeight: 36 * scale,
                ),
                icon: _MenuMark(size: 32 * scale, color: _lobbyGold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuMark extends StatelessWidget {
  const _MenuMark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final barHeight = (size * 0.14).clamp(2.0, 6.0);
    final gap = size * 0.18;
    return SizedBox(
      width: size * 1.2,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) SizedBox(height: gap),
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(barHeight),
              ),
            ),
          ],
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

  /// Member site list marquee: `max(10, length * 0.2 + 5)` seconds.
  static Duration _durationFor(String message) {
    final seconds = math.max(10.0, message.length * 0.2 + 5);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  String get _message =>
      widget.text?.trim().isNotEmpty == true ? widget.text!.trim() : '暂无公告';

  void _syncDuration() {
    final duration = _durationFor(_message);
    if (_controller.duration == duration) return;
    _controller.duration = duration;
    _controller.repeat();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(_message),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant LobbyAnnouncementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDuration();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final scale = lobbyChromeScale(context);
    return Container(
      height: 64 * scale,
      margin: EdgeInsets.fromLTRB(4, 4 * scale, 4, 6 * scale),
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1406),
        border: Border.all(color: const Color(0xFF9A7A37), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.campaign_outlined,
            color: const Color(0xFFC9A45A),
            size: 26 * scale,
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final style = TextStyle(
                    color: Colors.white,
                    fontSize: 17 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  );
                  final textScaler = MediaQuery.textScalerOf(context);
                  final textPainter = TextPainter(
                    text: TextSpan(text: message, style: style),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    textScaler: textScaler,
                  )..layout();
                  final viewport = constraints.maxWidth;
                  final textWidth = textPainter.width;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final start = viewport;
                      final end = -textWidth;
                      return Transform.translate(
                        offset: Offset(
                          start + (end - start) * _controller.value,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: textWidth,
                      maxWidth: textWidth,
                      child: Text(
                        message,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        textScaler: textScaler,
                        style: style,
                      ),
                    ),
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
    final scale = lobbyChromeScale(context);
    return SizedBox(
      height: 62 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2 * scale),
        child: Row(
          children: [
            Expanded(
              child: _CategoryTab(
                label: '全部',
                selected: selectedId == 0,
                onTap: () => onSelected(0),
              ),
            ),
            for (final category in categories)
              Expanded(
                child: _CategoryTab(
                  key: ValueKey(category.id),
                  label: category.name,
                  selected: selectedId == category.id,
                  onTap: () => onSelected(category.id),
                ),
              ),
          ],
        ),
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
    final scale = lobbyChromeScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.5 * scale),
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF8A703D), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFF243C52), Color(0xFF5C849C)]
                  : const [Color(0xFF162A40), Color(0xFF3E6078)],
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20 * scale,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
        final rowWidth = math.max(0.0, constraints.maxWidth - 3);
        final beadCellWidth = RoadmapBoardSpacing.detail.beadCellWidth(
          rowWidth,
        );
        final markScale = (beadCellWidth / 32).clamp(0.6, 1.7);
        final boardColor = desk.shuffling
            ? listShuffleBoardColor
            : listRoadBoardColor;
        final lineColor = desk.shuffling
            ? listShuffleLineColor
            : listRoadLineColor;
        return GestureDetector(
          onTap: onEnter,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: EdgeInsets.only(bottom: 4 * markScale),
            decoration: const BoxDecoration(color: Color(0xFF050505)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 36 * markScale,
                  padding: EdgeInsets.symmetric(horizontal: 8 * markScale),
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
                          style: TextStyle(
                            color: const Color(0xFFF1E7D2),
                            fontSize: 16 * markScale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final statistic in desk.statistics)
                        Expanded(
                          flex: 1,
                          child: _StatisticText(
                            statistic: statistic,
                            scale: markScale,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_showsBettingProgress(desk))
                  _BettingProgressBar(
                    progress: desk.remainingSeconds / desk.bettingSeconds,
                    height: (beadCellWidth * 0.16).clamp(3.0, 7.0),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Stack(
                    children: [
                      RoadmapBoard(
                        markerRoad: desk.markerRoad,
                        bigRoad: desk.bigRoad,
                        bigEyeRoad: desk.bigEyeRoad,
                        smallRoad: desk.smallRoad,
                        cockroachRoad: desk.cockroachRoad,
                        secondBigRoad: desk.secondBigRoad,
                        boardColor: boardColor,
                        lineColor: lineColor,
                      ),
                      if (isTrial || desk.shuffling)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _ListRoadStamp(
                              shuffling: desk.shuffling,
                              isTrial: isTrial,
                              cellWidth: beadCellWidth / 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
  const _StatisticText({required this.statistic, required this.scale});

  final LobbyOutcomeStat statistic;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${statistic.label} ${statistic.count}',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14 * scale),
            children: [
              TextSpan(
                text: '${statistic.label}:',
                style: TextStyle(color: _roadColor(statistic.color)),
              ),
              TextSpan(
                text: '${statistic.count}',
                style: TextStyle(
                  color: _roadColor(statistic.color),
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

/// 试玩中 sits on the center of the whole right-hand roadmap. While shuffling,
/// 洗牌中... stays above that same stamp so the stamp does not move.
class _ListRoadStamp extends StatelessWidget {
  const _ListRoadStamp({
    required this.shuffling,
    required this.isTrial,
    required this.cellWidth,
  });

  final bool shuffling;
  final bool isTrial;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final stamp = isTrial ? _TrialWatermark(cellWidth: cellWidth) : null;
    if (!shuffling) return Center(child: stamp);
    final label = _ShufflingLabel(cellWidth: cellWidth);
    if (!isTrial) return Center(child: label);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          stamp!,
          Transform.translate(
            offset: Offset(0, -cellWidth * 1.6),
            child: label,
          ),
        ],
      ),
    );
  }
}

class _ShufflingLabel extends StatelessWidget {
  const _ShufflingLabel({required this.cellWidth});

  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    return Text(
      '洗牌中...',
      style: TextStyle(
        color: const Color(0xF2F20300),
        fontSize: cellWidth * 2.05,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
  }
}

const _trialStampColor = Color(0xF2C44746);

bool _showsBettingProgress(LobbyDeskDashboardData desk) {
  return !desk.shuffling &&
      desk.status == 'betting' &&
      desk.bettingSeconds > 0 &&
      desk.remainingSeconds > 0;
}

class _BettingProgressBar extends StatelessWidget {
  const _BettingProgressBar({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '下注进度',
      child: SizedBox(
        key: const Key('betting-progress'),
        height: height,
        child: ColoredBox(
          color: const Color(0xFF14365F),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: const ColoredBox(color: Color(0xFF2F9BFF)),
          ),
        ),
      ),
    );
  }
}

class _TrialWatermark extends StatelessWidget {
  const _TrialWatermark({required this.cellWidth});

  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: cellWidth * 1.05,
        vertical: cellWidth * 0.42,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: _trialStampColor,
          width: (cellWidth * 0.07).clamp(1.0, 2.2),
        ),
      ),
      child: Text(
        '试玩中',
        style: TextStyle(
          color: _trialStampColor,
          fontSize: cellWidth * 1.22,
          fontWeight: FontWeight.w500,
          height: 1,
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
