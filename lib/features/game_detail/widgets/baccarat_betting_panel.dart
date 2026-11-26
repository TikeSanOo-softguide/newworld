import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../lobby/realtime/live_table_events.dart';
import '../baccarat_detail_models.dart';
import 'live_card_overlay.dart';

class BaccaratBettingPanel extends StatelessWidget {
  const BaccaratBettingPanel({
    super.key,
    required this.options,
    required this.confirmedBets,
    required this.confirmedTotalAmount,
    required this.pendingBets,
    required this.poolTotals,
    required this.chipDenominations,
    required this.selectedChip,
    required this.balance,
    required this.minBet,
    required this.maxBet,
    required this.bettingOpen,
    required this.secondsRemaining,
    required this.submitting,
    this.submittingResultId,
    required this.canceling,
    required this.onSelectChip,
    required this.onPlaceBet,
    required this.onConfirmZone,
    required this.onCancelZone,
    required this.onCancel,
    this.onRepeat,
    this.repeating = false,
    required this.onHistory,
    required this.onCustomerService,
    this.longhu = false,
    this.deskId = 0,
    this.cards,
    this.cardRevealAfter = cardRevealDelay,
  });

  final List<BaccaratResultOption> options;
  final Map<String, BaccaratConfirmedBet> confirmedBets;
  final num confirmedTotalAmount;
  final Map<int, num> pendingBets;
  final Map<String, num> poolTotals;
  final List<int> chipDenominations;
  final int? selectedChip;
  final num balance;
  final num minBet;
  final num maxBet;
  final bool bettingOpen;
  final int secondsRemaining;
  final bool submitting;
  final int? submittingResultId;
  final bool canceling;
  final ValueChanged<int> onSelectChip;
  final ValueChanged<BaccaratResultOption> onPlaceBet;
  final ValueChanged<BaccaratResultOption> onConfirmZone;
  final ValueChanged<BaccaratResultOption> onCancelZone;
  final VoidCallback onCancel;
  final VoidCallback? onRepeat;
  final bool repeating;
  final VoidCallback onHistory;
  final VoidCallback onCustomerService;
  final bool longhu;

  /// Changing desks builds a new tray at the first coin. Selection stays
  /// with [selectedChip] and does not follow the scroll offset.
  final int deskId;
  final DeskCardSnapshot? cards;
  final Duration cardRevealAfter;

  @override
  Widget build(BuildContext context) {
    final totalBet = confirmedTotalAmount;
    final optionsByKey = {for (final option in options) option.key: option};
    final allowCancelConfirmed =
        bettingOpen && secondsRemaining > 5 && confirmedBets.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 390.0;
        final balanceHeight = bounded ? constraints.maxHeight * 0.190 : 44.0;
        final chipRowHeight = bounded ? constraints.maxHeight * 0.210 : 58.0;
        final boardRadius = width * 0.04;
        final boardInset = width * 0.012;
        final board = Padding(
          padding: EdgeInsets.symmetric(horizontal: boardInset),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF194D72),
              borderRadius: BorderRadius.circular(boardRadius),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF3FA7ED),
                width: (width * 0.005).clamp(1.6, 4.0),
              ),
              borderRadius: BorderRadius.circular(boardRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(math.max(0, boardRadius - 2)),
              clipBehavior: Clip.none,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  longhu
                      ? _longhuBoard(optionsByKey)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 29,
                              child: _BetZone(
                                option: optionsByKey['player'],
                                label: '闲',
                                color: const Color(0xFF2380C3),
                                confirmed: confirmedBets['player']?.amount ?? 0,
                                pending:
                                    pendingBets[optionsByKey['player']?.id] ??
                                    0,
                                poolAmount: _poolAmount(
                                  optionsByKey['player'],
                                  poolTotals,
                                ),
                                enabled: bettingOpen,
                                submitting:
                                    submittingResultId ==
                                    optionsByKey['player']?.id,
                                onTap: () {
                                  final option = optionsByKey['player'];
                                  if (option != null) onPlaceBet(option);
                                },
                                onConfirm: () {
                                  final option = optionsByKey['player'];
                                  if (option != null) onConfirmZone(option);
                                },
                                onCancelStage: () {
                                  final option = optionsByKey['player'];
                                  if (option != null) onCancelZone(option);
                                },
                              ),
                            ),
                            const _ZoneDivider(),
                            Expanded(
                              flex: 43,
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _BetZone(
                                            option: optionsByKey['playerPair'],
                                            label: '闲对',
                                            color: const Color(0xFF2380C3),
                                            confirmed:
                                                confirmedBets['playerPair']
                                                    ?.amount ??
                                                0,
                                            pending:
                                                pendingBets[optionsByKey['playerPair']
                                                    ?.id] ??
                                                0,
                                            poolAmount: _poolAmount(
                                              optionsByKey['playerPair'],
                                              poolTotals,
                                            ),
                                            enabled: bettingOpen,
                                            submitting:
                                                submittingResultId ==
                                                optionsByKey['playerPair']?.id,
                                            onTap: () {
                                              final option =
                                                  optionsByKey['playerPair'];
                                              if (option != null) {
                                                onPlaceBet(option);
                                              }
                                            },
                                            onConfirm: () {
                                              final option =
                                                  optionsByKey['playerPair'];
                                              if (option != null) {
                                                onConfirmZone(option);
                                              }
                                            },
                                            onCancelStage: () {
                                              final option =
                                                  optionsByKey['playerPair'];
                                              if (option != null) {
                                                onCancelZone(option);
                                              }
                                            },
                                          ),
                                        ),
                                        const _ZoneDivider(),
                                        Expanded(
                                          child: _BetZone(
                                            option: optionsByKey['bankerPair'],
                                            label: '庄对',
                                            color: const Color(0xFFFF0111),
                                            confirmed:
                                                confirmedBets['bankerPair']
                                                    ?.amount ??
                                                0,
                                            pending:
                                                pendingBets[optionsByKey['bankerPair']
                                                    ?.id] ??
                                                0,
                                            poolAmount: _poolAmount(
                                              optionsByKey['bankerPair'],
                                              poolTotals,
                                            ),
                                            enabled: bettingOpen,
                                            submitting:
                                                submittingResultId ==
                                                optionsByKey['bankerPair']?.id,
                                            onTap: () {
                                              final option =
                                                  optionsByKey['bankerPair'];
                                              if (option != null) {
                                                onPlaceBet(option);
                                              }
                                            },
                                            onConfirm: () {
                                              final option =
                                                  optionsByKey['bankerPair'];
                                              if (option != null) {
                                                onConfirmZone(option);
                                              }
                                            },
                                            onCancelStage: () {
                                              final option =
                                                  optionsByKey['bankerPair'];
                                              if (option != null) {
                                                onCancelZone(option);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const _ZoneDivider(vertical: false),
                                  Expanded(
                                    flex: 1,
                                    child: _BetZone(
                                      option: optionsByKey['tie'],
                                      label: '和',
                                      color: const Color(0xFF22C14B),
                                      oddsBeside: true,
                                      confirmed:
                                          confirmedBets['tie']?.amount ?? 0,
                                      pending:
                                          pendingBets[optionsByKey['tie']
                                              ?.id] ??
                                          0,
                                      poolAmount: _poolAmount(
                                        optionsByKey['tie'],
                                        poolTotals,
                                      ),
                                      enabled: bettingOpen,
                                      submitting:
                                          submittingResultId ==
                                          optionsByKey['tie']?.id,
                                      onTap: () {
                                        final option = optionsByKey['tie'];
                                        if (option != null) onPlaceBet(option);
                                      },
                                      onConfirm: () {
                                        final option = optionsByKey['tie'];
                                        if (option != null) {
                                          onConfirmZone(option);
                                        }
                                      },
                                      onCancelStage: () {
                                        final option = optionsByKey['tie'];
                                        if (option != null) {
                                          onCancelZone(option);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const _ZoneDivider(),
                            Expanded(
                              flex: 28,
                              child: _BetZone(
                                option: optionsByKey['banker'],
                                label: '庄',
                                color: const Color(0xFFFF0111),
                                confirmed: confirmedBets['banker']?.amount ?? 0,
                                pending:
                                    pendingBets[optionsByKey['banker']?.id] ??
                                    0,
                                poolAmount: _poolAmount(
                                  optionsByKey['banker'],
                                  poolTotals,
                                ),
                                enabled: bettingOpen,
                                submitting:
                                    submittingResultId ==
                                    optionsByKey['banker']?.id,
                                onTap: () {
                                  final option = optionsByKey['banker'];
                                  if (option != null) onPlaceBet(option);
                                },
                                onConfirm: () {
                                  final option = optionsByKey['banker'];
                                  if (option != null) onConfirmZone(option);
                                },
                                onCancelStage: () {
                                  final option = optionsByKey['banker'];
                                  if (option != null) onCancelZone(option);
                                },
                              ),
                            ),
                          ],
                        ),
                  LiveCardOverlay(
                    snapshot: cards,
                    longhu: longhu,
                    revealAfter: cardRevealAfter,
                  ),
                ],
              ),
            ),
          ),
        );
        final chips = SizedBox(
          height: chipRowHeight,
          child: ColoredBox(
            color: const Color(0xFF194D72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: _chipRow(allowCancelConfirmed: allowCancelConfirmed),
            ),
          ),
        );
        return ColoredBox(
          color: const Color(0xFF0F2C44),
          child: Column(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                height: balanceHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0xFF182536),
                child: Row(
                  children: [
                    Expanded(
                      child: _AmountMetric(
                        label: '总分',
                        value: _formatAmount(balance),
                      ),
                    ),
                    Expanded(
                      child: _AmountMetric(
                        label: '投注',
                        value: _formatAmount(totalBet),
                      ),
                    ),
                    _ActionIconButton(
                      label: '在线客服',
                      onPressed: onCustomerService,
                    ),
                    const SizedBox(width: 6),
                    _ActionIconButton(
                      label: '下注记录',
                      showDot: true,
                      onPressed: onHistory,
                    ),
                  ],
                ),
              ),
              if (bounded)
                Expanded(child: board)
              else
                SizedBox(height: width * 0.46, child: board),
              chips,
            ],
          ),
        );
      },
    );
  }

  Widget _chipRow({required bool allowCancelConfirmed}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWidth = (constraints.maxWidth * 0.134).clamp(52.0, 120.0);
        final rowHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 58.0;
        final actionHeight = math.min(
          rowHeight * 0.72,
          (constraints.maxWidth * 0.078).clamp(34.0, 72.0),
        );
        final chipWidth = math.max(
          0.0,
          constraints.maxWidth - actionWidth * 2 - 10,
        );
        final itemExtent = chipWidth / 4;
        // The selected face scales to 1.1 and adds the 5px ring. Fitting
        // that inside the row keeps the highlight on the tray, where the
        // tap lands, instead of painting it onto the roadmap.
        const selectedExtent = 1.1 * (1 + 10 / 65);
        final innerHeight = math.max(0.0, rowHeight - 8);
        final fitted = innerHeight == 0 ? 0.0 : innerHeight / selectedExtent;
        final chipSide = math.min(fitted, math.max(0.0, itemExtent - 8));
        return Row(
          children: [
            SizedBox(
              width: chipWidth,
              child: chipDenominations.isEmpty
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _ChipStrip(
                      key: ValueKey('chip-strip-$deskId'),
                      denominations: chipDenominations,
                      itemExtent: itemExtent,
                      chipSide: chipSide,
                      selectedChip: selectedChip,
                      onSelectChip: onSelectChip,
                    ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: actionWidth,
              height: actionHeight,
              child: _BetActionButton(
                label: '取消',
                color: const Color(0xFFFD0000),
                enabled: !canceling && allowCancelConfirmed,
                dimWhenDisabled: false,
                loading: canceling,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: actionWidth,
              height: actionHeight,
              child: _BetActionButton(
                label: '续投',
                color: const Color(0xFF171A11),
                borderColor: const Color(0xFFDCB20F),
                textColor: Colors.white,
                enabled: onRepeat != null && !repeating,
                dimWhenDisabled: false,
                loading: repeating,
                onPressed: onRepeat ?? () {},
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _longhuBoard(Map<String, BaccaratResultOption> optionsByKey) {
    Widget zone(String key, String fallback, Color color) {
      final option = optionsByKey[key];
      return _BetZone(
        option: option,
        label: option?.name.isNotEmpty == true ? option!.name : fallback,
        color: color,
        confirmed: confirmedBets[key]?.amount ?? 0,
        pending: pendingBets[option?.id] ?? 0,
        poolAmount: _poolAmount(option, poolTotals),
        enabled: bettingOpen,
        submitting: submittingResultId == option?.id,
        onTap: () {
          if (option != null) onPlaceBet(option);
        },
        onConfirm: () {
          if (option != null) onConfirmZone(option);
        },
        onCancelStage: () {
          if (option != null) onCancelZone(option);
        },
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: zone('dragon', '龙', const Color(0xFFFF0111))),
        const _ZoneDivider(),
        Expanded(child: zone('tie', '和', const Color(0xFF22C14B))),
        const _ZoneDivider(),
        Expanded(child: zone('tiger', '虎', const Color(0xFF2380C3))),
      ],
    );
  }
}

class _ChipStrip extends StatefulWidget {
  const _ChipStrip({
    super.key,
    required this.denominations,
    required this.itemExtent,
    required this.chipSide,
    required this.selectedChip,
    required this.onSelectChip,
  });

  final List<int> denominations;
  final double itemExtent;
  final double chipSide;
  final int? selectedChip;
  final ValueChanged<int> onSelectChip;

  @override
  State<_ChipStrip> createState() => _ChipStripState();
}

class _ChipStripState extends State<_ChipStrip> {
  // A new desk builds a new tray. Its first offset is the selected coin's
  // index, clamped to the list. PageStorage is left off so a route cannot
  // put an older pixel offset back after that jump.
  final _controller = ScrollController(keepScrollOffset: false);
  var _attempts = 0;
  var _orientationAttempts = 0;
  var _aligned = false;
  var _hold = false;
  double? _userLogical;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _scheduleAlign();
  }

  @override
  void didUpdateWidget(covariant _ChipStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemExtent == widget.itemExtent) return;
    // Layout can correct the old pixel offset before the same coin-slot
    // position is applied to the new width.
    _hold = true;
    _scheduleOrientationRestore();
  }

  /// Slots from the left edge to the selected coin. Fifty is the stand-in
  /// until a denomination has been chosen. The scroll offset is this count
  /// times the item extent, and never past the end of the list.
  double _selectedLogical() {
    final selected = widget.selectedChip;
    var index = selected == null ? -1 : widget.denominations.indexOf(selected);
    if (index < 0) index = widget.denominations.indexOf(50);
    if (index < 0) return 0;
    return index.toDouble();
  }

  void _scheduleAlign() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _aligned) return;
      if (!_ready) {
        if (_attempts++ < 8) _scheduleAlign();
        return;
      }
      final logical = _selectedLogical();
      final maxExtent = _controller.position.maxScrollExtent;
      if (logical > 0 && maxExtent <= 0.5) {
        if (_attempts++ < 8) _scheduleAlign();
        return;
      }
      _jumpToLogical(logical);
      // User scrolling is recorded only after this jump, so the list's
      // initial 0 cannot replace the selected coin's position.
      _aligned = true;
    });
  }

  void _scheduleOrientationRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_ready) {
        if (_orientationAttempts++ < 8) {
          _scheduleOrientationRestore();
        } else {
          _hold = false;
        }
        return;
      }
      _jumpToLogical(_userLogical ?? _selectedLogical());
      _hold = false;
    });
  }

  bool get _ready =>
      widget.itemExtent > 0 &&
      _controller.hasClients &&
      _controller.position.hasContentDimensions &&
      _controller.position.viewportDimension > 0;

  void _jumpToLogical(double logical) {
    final max = _controller.position.maxScrollExtent;
    final target = (logical * widget.itemExtent).clamp(0.0, max).toDouble();
    if ((_controller.offset - target).abs() <= 0.5) return;
    final held = _hold;
    _hold = true;
    _controller.jumpTo(target);
    _hold = held;
  }

  void _onScroll() {
    if (!_aligned || _hold || !mounted || widget.itemExtent <= 0) return;
    if (!_controller.hasClients) return;
    _userLogical = _controller.offset / widget.itemExtent;
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('baccarat-chip-selector'),
      controller: _controller,
      scrollDirection: Axis.horizontal,
      // Clip at the tray edges so a scrolled coin stops before 取消 and 续投.
      clipBehavior: Clip.hardEdge,
      itemExtent: widget.itemExtent,
      itemCount: widget.denominations.length,
      itemBuilder: (context, index) {
        final chip = widget.denominations[index];
        return Semantics(
          button: true,
          selected: chip == widget.selectedChip,
          label: '筹码 $chip',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onSelectChip(chip),
            child: Center(
              child: _ChipButton(
                value: chip,
                size: widget.chipSide,
                selected: chip == widget.selectedChip,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider({this.vertical = true});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return vertical
        ? const VerticalDivider(
            width: 1.2,
            thickness: 1.2,
            color: Color(0xFF0A3456),
          )
        : const Divider(height: 1.2, thickness: 1.2, color: Color(0xFF0A3456));
  }
}

class _BetZone extends StatelessWidget {
  const _BetZone({
    required this.option,
    required this.label,
    required this.color,
    this.oddsBeside = false,
    required this.confirmed,
    required this.pending,
    required this.poolAmount,
    required this.enabled,
    required this.submitting,
    required this.onTap,
    required this.onConfirm,
    required this.onCancelStage,
  });

  final BaccaratResultOption? option;
  final String label;
  final Color color;
  final bool oddsBeside;
  final num confirmed;
  final num pending;
  final num? poolAmount;
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onCancelStage;

  @override
  Widget build(BuildContext context) {
    final ink = enabled ? color : color.withValues(alpha: 0.55);
    final odds = option == null ? null : '1:${_formatOdds(option!.ratio)}';
    final stake = confirmed + pending;
    final staged = pending > 0;
    final side = !oddsBeside && label.length == 1;
    return Material(
      color: const Color(0xFF194D72),
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: enabled && option != null ? onTap : null,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(6, 4, 6, staged ? 52 : 4),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: oddsBeside
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _plainZoneText(label, ink, 48),
                            if (odds != null) ...[
                              const SizedBox(width: 14),
                              _plainZoneText(odds, ink, 40),
                            ],
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _plainZoneText(label, ink, side ? 78 : 34),
                            if (odds != null) ...[
                              SizedBox(height: side ? 6 : 2),
                              _plainZoneText(odds, ink, side ? 28 : 22),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            if (stake > 0) ...[
              Positioned(
                top: -6,
                right: 4,
                child: IgnorePointer(
                  child: Text(
                    _formatAmount(stake),
                    key: ValueKey('zone-amount-${option?.id}'),
                    style: TextStyle(
                      color: const Color(0xFFE2BF29),
                      fontSize: side ? 25 : 18,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      shadows: const [
                        Shadow(color: Color(0xCC000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: side ? 28 : 22,
                left: 0,
                right: 0,
                bottom: staged ? 52 : 4,
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chipSide = math
                          .min(62.0, constraints.maxHeight * 0.72)
                          .clamp(18.0, 62.0);
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          'assets/images/coins/${_chipArt(stake)}chip.png',
                          key: ValueKey('zone-chip-${option?.id}'),
                          width: chipSide,
                          height: chipSide,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (staged)
              Positioned(
                left: 2,
                right: 2,
                bottom: 3,
                child: _ZoneStageActions(
                  resultId: option?.id,
                  submitting: submitting,
                  canConfirm: !submitting,
                  onConfirm: onConfirm,
                  onCancel: onCancelStage,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _plainZoneText(String text, Color color, double size) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
  }
}

class _ZoneStageActions extends StatelessWidget {
  const _ZoneStageActions({
    required this.resultId,
    required this.submitting,
    required this.canConfirm,
    required this.onConfirm,
    required this.onCancel,
  });

  final int? resultId;
  final bool submitting;
  final bool canConfirm;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StageButton(
            key: ValueKey('zone-confirm-$resultId'),
            label: '确定',
            color: const Color(0xFF009900),
            borderColor: const Color(0xFFD0D0D0),
            enabled: canConfirm,
            loading: submitting,
            onPressed: onConfirm,
          ),
          const SizedBox(width: 31),
          _StageButton(
            key: ValueKey('zone-cancel-$resultId'),
            label: '取消',
            color: const Color(0xFFFE0000),
            enabled: !submitting,
            loading: false,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    super.key,
    required this.label,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color? borderColor;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fill = enabled ? color : color.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: 68,
        height: 47,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: borderColor ?? Colors.transparent,
              width: borderColor == null ? 0 : 1.5,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 8,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetActionButton extends StatelessWidget {
  const _BetActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    this.amount,
    this.borderColor,
    this.textColor = Colors.white,
    this.dimWhenDisabled = true,
  });

  final String label;
  final String? amount;
  final Color color;
  final Color? borderColor;
  final Color textColor;
  final bool enabled;
  final bool dimWhenDisabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final activeColor = enabled || !dimWhenDisabled
        ? color
        : color.withValues(alpha: 0.48);
    return Semantics(
      button: true,
      enabled: enabled,
      label: amount == null ? label : '$label $amount',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(7),
          child: Ink(
            decoration: BoxDecoration(
              color: activeColor,
              border: Border.all(color: borderColor ?? activeColor, width: 1.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatefulWidget {
  const _ChipButton({
    required this.value,
    required this.selected,
    this.size = 40,
  });

  final int value;
  final bool selected;
  final double size;

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton>
    with TickerProviderStateMixin {
  // Member ChipItem: 200ms scale to 1.1, then a 5px gold ring that spins
  // for 3.2s. The ring stays behind the full chip image.
  late final AnimationController _spin;
  late final AnimationController _select;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _select = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _select.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !widget.selected) {
        _spin.stop();
      }
    });
    if (widget.selected) {
      _select.value = 1;
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ChipButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    if (widget.selected) {
      _spin.value = 0;
      _spin.repeat();
      _select.forward();
    } else {
      _select.reverse();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _select.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final outset = size * 5 / 65;
    final glow = size * 14 / 65;
    final extent = (size + outset * 2) * 1.1 + glow * 2;
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: 0,
        minHeight: 0,
        maxWidth: extent,
        maxHeight: extent,
        child: AnimatedBuilder(
          animation: Listenable.merge([_select, _spin]),
          builder: (context, _) {
            final t = _select.value;
            return Transform.scale(
              key: ValueKey('chip-scale-${widget.value}'),
              scale: 1 + 0.1 * t,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (widget.selected || t > 0)
                    Opacity(
                      opacity: t,
                      child: SizedBox(
                        width: size + outset * 2,
                        height: size + outset * 2,
                        child: DecoratedBox(
                          key: widget.selected
                              ? ValueKey('selected-chip-${widget.value}')
                              : null,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromRGBO(255, 230, 0, 0.75),
                                blurRadius: glow,
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            key: ValueKey('chip-spin-${widget.value}'),
                            angle: _spin.value * math.pi * 2,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Color(0xFFFFE94D),
                                    Color(0xFFFF9F1A),
                                    Color(0xFFFFE94D),
                                    Color(0xFFFF9F1A),
                                    Color(0xFFFFE94D),
                                    Color(0xFFFF9F1A),
                                    Color(0xFFFFE94D),
                                    Color(0xFFFF9F1A),
                                    Color(0xFFFFE94D),
                                  ],
                                  stops: [
                                    0,
                                    0.125,
                                    0.25,
                                    0.375,
                                    0.5,
                                    0.625,
                                    0.75,
                                    0.875,
                                    1,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Image.asset(
                    'assets/images/coins/${widget.value}chip.png',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: RichText(
        text: TextSpan(
          text: '$label:$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.label,
    required this.onPressed,
    this.showDot = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        backgroundColor: const Color(0xFF1669A6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF49B4F5),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 8, height: 8),
            ),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

int _chipArt(num amount) {
  const values = [1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000];
  var nearest = values.first;
  for (final value in values) {
    if (value > amount) break;
    nearest = value;
  }
  return nearest;
}

String _formatAmount(num amount) =>
    amount == amount.roundToDouble() ? amount.toInt().toString() : '$amount';

String _formatOdds(num odds) {
  final value = odds.toString();
  return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
}

num? _poolAmount(BaccaratResultOption? option, Map<String, num> totals) {
  if (option == null) return null;
  return totals[option.key] ?? totals['${option.id}'];
}
