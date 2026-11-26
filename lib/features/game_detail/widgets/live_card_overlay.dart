import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../lobby/realtime/live_table_events.dart';
import '../card_images.dart';

/// How long a dealt card stays face down before it turns over.
///
/// This is the member site's delay. The recording shows the back held, then
/// the turn, but the socket event is not in the video, so the hold itself
/// was not measured.
const cardRevealDelay = Duration(milliseconds: 500);

/// Y-axis turn measured on BACCARAT_detail: full back at 59.4s, edge-on at
/// 59.6s, face up at 59.8s.
const cardFlipDuration = Duration(milliseconds: 400);

/// Vertical card measured on the 1800×2880 frames: about 256×321 px.
const cardFaceAspect = 321 / 256;

/// Live cards drawn on the betting board. It only paints [snapshot].
///
/// Sizes are fractions of the board, taken from the 1800-wide frames where
/// the board is about 1756 px wide and a vertical card is 256×321.
class LiveCardOverlay extends StatelessWidget {
  const LiveCardOverlay({
    super.key,
    required this.snapshot,
    required this.longhu,
    this.revealAfter = cardRevealDelay,
  });

  final DeskCardSnapshot? snapshot;
  final bool longhu;
  final Duration revealAfter;

  @override
  Widget build(BuildContext context) {
    final hand = snapshot;
    if (hand == null || hand.kind == DeskCardKind.empty) {
      return const SizedBox.shrink();
    }
    if (longhu && hand.kind != DeskCardKind.longhu) {
      return const SizedBox.shrink();
    }
    if (!longhu && hand.kind != DeskCardKind.baccarat) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (!width.isFinite ||
              !height.isFinite ||
              width <= 0 ||
              height <= 0) {
            return const SizedBox.shrink();
          }
          return longhu
              ? _longhu(hand, width, height)
              : _baccarat(hand, width, height);
        },
      ),
    );
  }

  Widget _baccarat(DeskCardSnapshot hand, double width, double height) {
    // 256/1756 of the measured board, and a 37 px gap between a pair.
    final cardWidth = width * 0.1458;
    final cardHeight = cardWidth * cardFaceAspect;
    final gap = width * 0.0211;
    final pairWidth = cardWidth * 2 + gap;
    // 240 px inset from each board edge on the 1756 px board.
    final inset = width * 0.1367;
    final playerLeft = inset;
    final bankerLeft = width - inset - pairWidth;
    final pairBottom = math.max(1.0, height * 0.012);
    return Stack(
      children: [
        _pair(
          hand: hand,
          slots: const ['p1', 'p2'],
          third: 'p3',
          label: '闲',
          labelColor: const Color(0xFF0020F8),
          left: playerLeft,
          bottom: pairBottom,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          gap: gap,
        ),
        _pair(
          hand: hand,
          slots: const ['b1', 'b2'],
          third: 'b3',
          label: '庄',
          labelColor: const Color(0xFFF0454A),
          left: bankerLeft,
          bottom: pairBottom,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          gap: gap,
        ),
      ],
    );
  }

  Widget _pair({
    required DeskCardSnapshot hand,
    required List<String> slots,
    required String third,
    required String label,
    required Color labelColor,
    required double left,
    required double bottom,
    required double cardWidth,
    required double cardHeight,
    required double gap,
  }) {
    final first = hand.slots[slots[0]];
    final second = hand.slots[slots[1]];
    final extra = hand.slots[third];
    final cards = <Widget>[
      if (first != null)
        _DealtCard(
          slot: slots[0],
          code: first,
          width: cardWidth,
          height: cardHeight,
          revealAfter: revealAfter,
        ),
      if (first != null && second != null) SizedBox(width: gap),
      if (second != null)
        _DealtCard(
          slot: slots[1],
          code: second,
          width: cardWidth,
          height: cardHeight,
          revealAfter: revealAfter,
        ),
    ];
    if (cards.isEmpty && extra == null) return const SizedBox.shrink();
    final tag = cardWidth * 0.289;
    // 26 px above the label, 27 px between the label and the pair.
    final aboveLabel = cardHeight * 0.081;
    final aboveCards = cardHeight * 0.084;
    return Positioned(
      left: left,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (extra != null)
            RotatedBox(
              key: ValueKey<String>('card-$third-rotated'),
              quarterTurns: 1,
              child: _DealtCard(
                slot: third,
                code: extra,
                width: cardWidth,
                height: cardHeight,
                revealAfter: revealAfter,
              ),
            ),
          if (extra != null) SizedBox(height: aboveLabel),
          if (cards.isNotEmpty)
            _HandTag(label: label, color: labelColor, width: tag),
          if (cards.isNotEmpty) SizedBox(height: aboveCards),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: cards,
          ),
        ],
      ),
    );
  }

  Widget _longhu(DeskCardSnapshot hand, double width, double height) {
    final cardWidth = width * 0.1458;
    final cardHeight = cardWidth * cardFaceAspect;
    final bottom = math.max(1.0, height * 0.012);
    final tag = cardWidth * 0.289;
    // Dragon card starts at 402/1760 of the board and overlaps the center.
    final innerLeft = width * 0.2284;
    Widget? side(String slot, String label, Color color, double left) {
      final code = hand.slots[slot];
      if (code == null) return null;
      return Positioned(
        left: left,
        bottom: bottom,
        width: cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HandTag(label: label, color: color, width: tag),
            SizedBox(height: cardHeight * 0.084),
            _DealtCard(
              slot: slot,
              code: code,
              width: cardWidth,
              height: cardHeight,
              revealAfter: revealAfter,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ?side('dragon', '龙', const Color(0xFFFF4A4D), innerLeft),
        ?side(
          'tiger',
          '虎',
          const Color(0xFF0020F8),
          width - innerLeft - cardWidth,
        ),
      ],
    );
  }
}

class _HandTag extends StatelessWidget {
  const _HandTag({
    required this.label,
    required this.color,
    required this.width,
  });

  final String label;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.89,
      alignment: Alignment.center,
      color: Colors.white,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: width * 0.62,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _DealtCard extends StatefulWidget {
  const _DealtCard({
    required this.slot,
    required this.code,
    required this.width,
    required this.height,
    required this.revealAfter,
  });

  final String slot;
  final String code;
  final double width;
  final double height;
  final Duration revealAfter;

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn;
  Timer? _wait;
  var _faceUp = false;

  @override
  void initState() {
    super.initState();
    _turn = AnimationController(vsync: this, duration: cardFlipDuration);
    _arm(widget.code);
  }

  @override
  void didUpdateWidget(_DealtCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) _arm(widget.code);
  }

  void _arm(String code) {
    _wait?.cancel();
    _faceUp = false;
    _turn.value = 0;
    if (cardFaceAsset(code) == null) return;
    _wait = Timer(widget.revealAfter, () {
      if (!mounted) return;
      setState(() => _faceUp = true);
      _turn.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = cardFaceAsset(widget.code);
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, child) {
        final angle = _faceUp ? _turn.value * math.pi : 0.0;
        final pastEdge = angle > math.pi / 2;
        final shown = pastEdge ? angle - math.pi : angle;
        final asset = pastEdge && face != null ? face : cardBackAsset;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(shown),
          child: Image.asset(
            asset,
            key: ValueKey<String>('card-${widget.slot}'),
            width: widget.width,
            height: widget.height,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              cardBackAsset,
              key: ValueKey<String>('card-${widget.slot}-back'),
              width: widget.width,
              height: widget.height,
              fit: BoxFit.fill,
            ),
          ),
        );
      },
    );
  }
}
