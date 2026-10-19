import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../baccarat_state.dart';

class BaccaratBottomBar extends ConsumerWidget {
  const BaccaratBottomBar({super.key});

  static const _gold = Color(0xFFFFBF00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(baccaratProvider);
    final n = ref.read(baccaratProvider.notifier);

    return Container(
      height: 54,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: n.repeatBet,
              borderRadius: BorderRadius.circular(6),
              child: Ink(
                width: 64,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _gold, width: 1.2),
                ),
                child: const Center(
                  child: Text(
                    '续投',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in BaccaratNotifier.chips) ...[
                    _Chip(
                      value: chip,
                      selected: state.selectedChip == chip,
                      onTap: () => n.selectChip(chip),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: n.clearBets,
            child: const Text('清除', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: n.confirmRound,
            child: const Text('确认', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  Color get _color {
    switch (value) {
      case 1:
        return const Color(0xFF9E9E9E);
      case 5:
        return const Color(0xFFE53935);
      case 10:
        return const Color(0xFF1E88E5);
      case 50:
        return const Color(0xFFFB8C00);
      case 100:
        return const Color(0xFF212121);
      case 500:
        return const Color(0xFF8E24AA);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = selected ? 40.0 : 34.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          border: Border.all(
            color: selected ? const Color(0xFFFFBF00) : Colors.white70,
            width: selected ? 2.4 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFBF00).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
