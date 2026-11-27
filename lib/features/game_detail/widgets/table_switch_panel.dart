import 'package:flutter/material.dart';

import '../../lobby/desk_session_state.dart';
import '../../lobby/models/lobby_round_result.dart';
import '../../lobby/roadmap/roadmap_calculations.dart';
import '../../lobby/roadmap/roadmap_models.dart';
import '../../lobby/roadmap/roadmap_painter.dart';
import '../../lobby/widgets/lobby_dashboard_widgets.dart';
import 'cross_desk_result_overlay.dart';

/// Reference frame is 600px wide and the list starts at x=94.
const tableSwitchPanelWidthFactor = 506 / 600;

enum DeskSwitchChoice { ignore, stay, start }

/// Same desk closes the list. Another desk starts a switch. A second tap
/// while one switch is running is ignored.
DeskSwitchChoice decideDeskSwitch({
  required int? selectedId,
  required int currentId,
  required bool switching,
}) {
  if (selectedId == null || switching) return DeskSwitchChoice.ignore;
  if (selectedId == currentId) return DeskSwitchChoice.stay;
  return DeskSwitchChoice.start;
}

/// Header label used by the list and by `正在换到…`.
String deskSwitchName(Map<String, dynamic> desk) {
  final game = desk['game'];
  final gameName = game is Map ? game['name']?.toString() ?? '' : '';
  final name = desk['name']?.toString() ?? '';
  final combined = '$gameName$name';
  if (combined.isEmpty) return '台桌';
  return combined.endsWith('台') ? combined : '$combined台';
}

String deskSwitchMessage(String deskName) => '正在换到$deskName...';

/// Shown while the list is open. It stays in the visible strip, vertically
/// centered, with its right side against the list.
class TableSwitchEdgeButton extends StatelessWidget {
  const TableSwitchEdgeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width * (58 / 600);
    final height = size.height * (138 / 960);
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: const Color(0xE62C4A68),
        borderRadius: BorderRadius.circular(width * 0.16),
        child: InkWell(
          key: const ValueKey('table-switch-edge-button'),
          borderRadius: BorderRadius.circular(width * 0.16),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(width * 0.16),
              border: Border.all(color: const Color(0xFFE7EFF6), width: 1.2),
            ),
            child: Center(
              child: Text(
                '切\n换\n台\n桌',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFF4F8FB),
                  fontSize: height * 0.16,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeskSwitchOverlay extends StatelessWidget {
  const DeskSwitchOverlay({super.key, required this.deskName});

  final String deskName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: Color(0x99000000)),
        Center(
          child: Text(
            deskSwitchMessage(deskName),
            key: const ValueKey('desk-switch-message'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class DeskListClock {
  const DeskListClock({
    required this.status,
    required this.remainingSeconds,
    required this.bettingSeconds,
  });

  final String? status;
  final int remainingSeconds;
  final int bettingSeconds;

  bool get showsProgress =>
      status == 'betting' && bettingSeconds > 0 && remainingSeconds > 0;

  double get progress =>
      (remainingSeconds / bettingSeconds).clamp(0.0, 1.0).toDouble();
}

class TableSwitchPanel extends StatefulWidget {
  const TableSwitchPanel({
    super.key,
    required this.desks,
    required this.currentDeskId,
    required this.initialType,
    required this.trial,
    required this.clockFor,
    required this.onSelect,
    this.confirmedBetAmountByDesk = const {},
  });

  final List<Map<String, dynamic>> desks;
  final int currentDeskId;
  final String initialType;
  final bool trial;
  final DeskListClock? Function(int deskId) clockFor;
  final ValueChanged<Map<String, dynamic>> onSelect;

  /// Confirmed stake totals. A value above zero draws the ¥ mark.
  final Map<int, num> confirmedBetAmountByDesk;

  @override
  State<TableSwitchPanel> createState() => _TableSwitchPanelState();
}

class _TableSwitchPanelState extends State<TableSwitchPanel> {
  late String _type = _normalizedType(widget.initialType);

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width * tableSwitchPanelWidthFactor;
    final visible = _visibleDesks();
    final tabHeight = width * (47 / 505);
    return Material(
      key: const ValueKey('table-switch-panel'),
      color: const Color(0xFF000000),
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            _CategoryTabs(
              selected: _type,
              height: tabHeight,
              onSelected: (type) => setState(() => _type = type),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无台桌',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('table-switch-list'),
                      padding: EdgeInsets.only(bottom: width * (8 / 505)),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final desk = visible[index];
                        final id = _asInt(desk['id']) ?? 0;
                        return _DeskSwitchCard(
                          desk: desk,
                          current: id == widget.currentDeskId,
                          trial: widget.trial,
                          clock: widget.clockFor(id),
                          hasConfirmedBet:
                              (widget.confirmedBetAmountByDesk[id] ?? 0) > 0,
                          onTap: () => widget.onSelect(desk),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _visibleDesks() {
    final rows = widget.desks.where((desk) {
      if (_type == 'ALL') return true;
      return _deskType(desk) == _type;
    }).toList();
    rows.sort((a, b) {
      final byGame = _gamePosition(a).compareTo(_gamePosition(b));
      if (byGame != 0) return byGame;
      return (_asInt(a['position']) ?? 0).compareTo(_asInt(b['position']) ?? 0);
    });
    return rows;
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.selected,
    required this.height,
    required this.onSelected,
  });

  final String selected;
  final double height;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final gap = height * (6 / 47);
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(left: gap * 1.3, right: gap * 4),
        child: Row(
          children: [
            for (final tab in const [
              ('ALL', '全部'),
              ('BACCARAT', '百家乐'),
              ('LONGHU', '龙虎'),
            ]) ...[
              if (tab.$1 != 'ALL') SizedBox(width: gap),
              Expanded(
                child: _CategoryTab(
                  label: tab.$2,
                  height: height,
                  selected: selected == tab.$1,
                  onTap: () => onSelected(tab.$1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF000000),
      child: InkWell(
        key: ValueKey('desk-tab-$label'),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFF1A3E62), Color(0xFF4E7394)]
                  : const [Color(0xFF0E233F), Color(0xFF405E7C)],
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: height * 0.40,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeskSwitchCard extends StatelessWidget {
  const _DeskSwitchCard({
    required this.desk,
    required this.current,
    required this.trial,
    required this.clock,
    required this.hasConfirmedBet,
    required this.onTap,
  });

  final Map<String, dynamic> desk;
  final bool current;
  final bool trial;
  final DeskListClock? clock;
  final bool hasConfirmedBet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = _asInt(desk['id']) ?? 0;
    final longhu = _deskType(desk) == 'LONGHU';
    final results = _results(desk);
    final roadmap = results
        .map((result) => RoadmapResult(key: result.key))
        .toList(growable: false);
    final shuffling = deskIsShuffling(desk);
    final progress = _progress(clock, desk);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final headerHeight = width * (40 / 505);
        final barHeight = width * (6 / 505);
        final gap = width * (6 / 505);
        final fontSize = headerHeight * 0.46;
        return GestureDetector(
          key: ValueKey('desk-switch-$id'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: ValueKey('desk-header-$id'),
                  height: headerHeight,
                  padding: EdgeInsets.symmetric(horizontal: width * (8 / 505)),
                  color: const Color(0xFF000000),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _listTitle(desk),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFFD5D5D5),
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ),
                            if (hasConfirmedBet) ...[
                              SizedBox(width: fontSize * 0.35),
                              DeskConfirmedBetMark(
                                key: ValueKey('desk-bet-mark-$id'),
                                size: (headerHeight * 0.55).clamp(12.0, 16.0),
                              ),
                            ],
                          ],
                        ),
                      ),
                      for (final stat in _statistics(results, longhu: longhu))
                        Expanded(
                          flex: 3,
                          child: Text(
                            stat,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFD5D5D5),
                              fontSize: fontSize * 0.92,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  key: ValueKey('desk-progress-$id'),
                  height: barHeight,
                  child: ColoredBox(
                    color: const Color(0xFF2B4863),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress ?? 0,
                      child: const ColoredBox(color: Color(0xFF00FC97)),
                    ),
                  ),
                ),
                _SwitchRoadPreview(
                  roadmap: roadmap,
                  shuffling: shuffling,
                  trial: trial,
                  current: current,
                  boardColor: shuffling
                      ? listShuffleBoardColor
                      : listRoadBoardColor,
                  lineColor: shuffling
                      ? listShuffleLineColor
                      : const Color(0xFFC2C2C2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bead plate and big road at the same cell size. The reference row has no
/// derived roads under the big road.
class _SwitchRoadPreview extends StatelessWidget {
  const _SwitchRoadPreview({
    required this.roadmap,
    required this.shuffling,
    required this.trial,
    required this.current,
    required this.boardColor,
    required this.lineColor,
  });

  final List<RoadmapResult> roadmap;
  final bool shuffling;
  final bool trial;
  final bool current;
  final Color boardColor;
  final Color lineColor;

  static const beadColumns = 6;
  static const bigColumns = 13;
  static const cellAspect = 22 / 26;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColoredBox(
          color: boardColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final units = beadColumns + bigColumns + listRoadGapOverBeadCell;
              final cell = constraints.maxWidth / units;
              final title = cell * cellAspect * 0.95;
              final boardGap = cell * listRoadGapOverBeadCell;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: cell * beadColumns,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _grid(
                          calculateMarkerRoad(roadmap),
                          columns: beadColumns,
                        ),
                        IgnorePointer(child: _RoadWatermark('珠盘路', title)),
                      ],
                    ),
                  ),
                  SizedBox(
                    key: const ValueKey('road-board-gap'),
                    width: boardGap,
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _grid(calculateBigRoad(roadmap), columns: bigColumns),
                        IgnorePointer(child: _RoadWatermark('大路', title)),
                        if (trial || shuffling)
                          IgnorePointer(
                            child: shuffling
                                ? Text(
                                    '洗牌中...',
                                    style: TextStyle(
                                      color: const Color(0xF2F20300),
                                      fontSize: title * 1.15,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : _TrialStamp(title: title),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (current) const Positioned.fill(child: _CurrentDeskMark()),
      ],
    );
  }

  Widget _grid(RoadmapGrid grid, {required int columns}) {
    return RoadmapGridView(
      key: ValueKey('road-grid-${grid.type.name}'),
      grid: grid,
      cellWidth: 12,
      cellHeight: 12,
      visibleRows: beadPlateRows,
      visibleColumns: columns,
      heightOverWidth: cellAspect,
      boardColor: boardColor,
      gridLineColor: lineColor,
      gridLineWidth: 1,
      referenceMarkers: true,
    );
  }
}

class _RoadWatermark extends StatelessWidget {
  const _RoadWatermark(this.label, this.size);

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: roadTitleColor,
        fontSize: size,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CurrentDeskMark extends StatelessWidget {
  const _CurrentDeskMark();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey('current-desk-marker'),
      color: Color(0x7C000000),
      child: Align(alignment: Alignment(0.60, 0), child: _CurrentDeskLabel()),
    );
  }
}

class _CurrentDeskLabel extends StatelessWidget {
  const _CurrentDeskLabel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pin = (constraints.maxHeight * 0.30).clamp(28.0, 52.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: const Color(0xFFD2131B), size: pin),
            Text(
              '您当前所在的台',
              style: TextStyle(
                color: const Color(0xFFD2131B),
                fontSize: pin * 0.38,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrialStamp extends StatelessWidget {
  const _TrialStamp({required this.title});

  final double title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: title * 0.7,
        vertical: title * 0.22,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xF2C44746), width: 1),
      ),
      child: Text(
        '试玩中',
        style: TextStyle(
          color: const Color(0xF2C44746),
          fontSize: title * 0.85,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

String _normalizedType(String type) {
  final upper = type.toUpperCase();
  if (upper == 'LONGHU' || upper == 'BACCARAT') return upper;
  return 'ALL';
}

String _deskType(Map<String, dynamic> desk) {
  final game = desk['game'];
  if (game is Map) return game['type']?.toString().toUpperCase() ?? '';
  return '';
}

int _gamePosition(Map<String, dynamic> desk) {
  final game = desk['game'];
  if (game is Map) return _asInt(game['position']) ?? 1 << 20;
  return 1 << 20;
}

String _listTitle(Map<String, dynamic> desk) {
  final named = deskSwitchName(desk);
  return named.endsWith('台') ? named.substring(0, named.length - 1) : named;
}

List<String> _statistics(
  List<LobbyRoundResult> results, {
  required bool longhu,
}) {
  int count(String key) =>
      results.where((result) => result.key.split('|').contains(key)).length;
  if (longhu) {
    return ['龙:${count('dragon')}', '虎:${count('tiger')}', '和:${count('tie')}'];
  }
  return ['庄:${count('banker')}', '闲:${count('player')}', '和:${count('tie')}'];
}

double? _progress(DeskListClock? clock, Map<String, dynamic> desk) {
  if (clock != null) {
    return clock.showsProgress ? clock.progress : null;
  }
  final round = desk['last_round'];
  final status = round is Map ? round['status']?.toString() : null;
  if (status == 'betting' && !deskIsShuffling(desk)) return 1.0;
  return null;
}

List<LobbyRoundResult> _results(Map<String, dynamic> desk) {
  final id = _asInt(desk['id']) ?? 0;
  final raw = desk['results'];
  if (raw is! List) return const [];
  final results = <LobbyRoundResult>[];
  for (final item in raw) {
    try {
      results.add(LobbyRoundResult.fromApi(id, item));
    } on FormatException {
      continue;
    }
  }
  return results;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
