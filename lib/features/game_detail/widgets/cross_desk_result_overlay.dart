import 'package:flutter/material.dart';

import '../desk_result_indicators.dart';

const crossDeskDeskInk = Color(0xFF3DDC6A);
const crossDeskLossInk = Color(0xFFFF2020);
const crossDeskZeroInk = Color(0xFFFFFFFF);

/// Same translucent band the roadmap status phrases sit on.
const crossDeskBarBand = Color(0x80333333);

/// Bar across the top of the betting board.
///
/// A win paints the desk, 赢额, and the amount green. A loss paints the desk,
/// 输额, and the amount red. A zero net leaves the middle empty and shows `0`
/// in white. The dark band matches the status-phrase bar. The bar does not
/// take hits.
class CrossDeskResultBar extends StatelessWidget {
  const CrossDeskResultBar({super.key, required this.content});

  final CrossDeskBarContent content;

  @override
  Widget build(BuildContext context) {
    final ink = _barInk(content.amountTone);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final longest = [
            content.deskLabel.length,
            content.verdict?.length ?? 0,
            content.amount.length,
          ].reduce((a, b) => a > b ? a : b);
          final column = constraints.maxWidth / 3;
          final fontSize = longest == 0
              ? 18.0
              : (column / longest * 0.9).clamp(12.0, 28.0);
          final style = TextStyle(
            color: ink,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.05,
          );
          return DecoratedBox(
            key: const ValueKey('cross-desk-announcement'),
            decoration: const BoxDecoration(color: crossDeskBarBand),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: fontSize * 0.22),
              child: Row(
                children: [
                  Expanded(child: _barText(content.deskLabel, style)),
                  Expanded(child: _barText(content.verdict ?? '', style)),
                  Expanded(child: _barText(content.amount, style)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _barText(String text, TextStyle style) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: style,
    ),
  );
}

Color _barInk(String tone) {
  if (tone == 'loss') return crossDeskLossInk;
  if (tone == 'zero') return crossDeskZeroInk;
  return crossDeskDeskInk;
}

/// Yellow circle and red ¥ shown beside a desk that has a confirmed stake.
class DeskConfirmedBetMark extends StatelessWidget {
  const DeskConfirmedBetMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFACC15),
        shape: BoxShape.circle,
      ),
      child: Text(
        '¥',
        style: TextStyle(
          color: const Color(0xFFDC2626),
          fontSize: size * 0.72,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
