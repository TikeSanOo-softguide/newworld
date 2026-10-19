import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../baccarat_state.dart';

/// Green betting board: PAIR | PLAYER TIE BANKER | PAIR
class BaccaratBettingBoard extends ConsumerWidget {
  const BaccaratBettingBoard({super.key});

  static const _felt = Color(0xFF1F6B45);
  static const _border = Color(0xFFBDBDBD);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(baccaratProvider);
    final n = ref.read(baccaratProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: _felt,
        border: Border.all(color: _border, width: 1),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: _Spot(
                    title: 'PAIR',
                    titleColor: const Color(0xFF64B5F6),
                    odds: '1赔11',
                    amount: state.playerPairBet,
                    onTap: () => n.placeBet(BetSpot.playerPair),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _Spot(
                    title: 'PAIR',
                    titleColor: const Color(0xFFEF5350),
                    odds: '1赔11',
                    amount: state.bankerPairBet,
                    onTap: () => n.placeBet(BetSpot.bankerPair),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Expanded(
                  child: _Spot(
                    title: 'TIE',
                    titleColor: Colors.white,
                    odds: '1赔8',
                    amount: state.tieBet,
                    onTap: () => n.placeBet(BetSpot.tie),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Spot(
                          title: 'PLAYER',
                          titleColor: const Color(0xFF64B5F6),
                          odds: '1赔1',
                          amount: state.playerBet,
                          onTap: () => n.placeBet(BetSpot.player),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _Spot(
                          title: 'BANKER',
                          titleColor: const Color(0xFFEF5350),
                          odds: '1赔0.95',
                          amount: state.bankerBet,
                          onTap: () => n.placeBet(BetSpot.banker),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: _Spot(
                    title: 'PAIR',
                    titleColor: const Color(0xFF64B5F6),
                    odds: '1赔11',
                    amount: state.playerPairBet,
                    onTap: () => n.placeBet(BetSpot.playerPair),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _Spot(
                    title: 'PAIR',
                    titleColor: const Color(0xFFEF5350),
                    odds: '1赔11',
                    amount: state.bankerPairBet,
                    onTap: () => n.placeBet(BetSpot.bankerPair),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spot extends StatelessWidget {
  const _Spot({
    required this.title,
    required this.titleColor,
    required this.odds,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final Color titleColor;
  final String odds;
  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF246B48),
            border: Border.all(color: Colors.white54, width: 0.8),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 4,
                top: 3,
                child: Text(
                  odds,
                  style: const TextStyle(
                    color: Color(0xFFFFF59D),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (amount > 0)
                      Text(
                        '$amount',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
