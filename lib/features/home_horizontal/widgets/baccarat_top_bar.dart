import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../baccarat_state.dart';

class BaccaratTopBar extends ConsumerWidget {
  const BaccaratTopBar({super.key});

  static const _green = Color(0xFF1B5E3B);
  static const _greenDark = Color(0xFF0F3D28);
  static const _gold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(baccaratProvider);
    final notifier = ref.read(baccaratProvider.notifier);

    return Container(
      height: 44,
      color: _greenDark,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 11,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final selected = state.selectedTable == i;
                return GestureDetector(
                  onTap: () => notifier.selectTable(i),
                  child: Container(
                    width: 62,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? _green : const Color(0xFF123524),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: selected ? _gold : Colors.white24,
                        width: selected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          margin: const EdgeInsets.fromLTRB(3, 3, 3, 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            gradient: LinearGradient(
                              colors: [
                                _gold.withValues(alpha: 0.2 + (i % 5) * 0.15),
                                Colors.black54,
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '百家乐${i + 1}',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 72,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '投注限红: 20-10000',
                style: TextStyle(color: _gold.withValues(alpha: 0.95), fontSize: 9),
              ),
              Text(
                '总分: ${state.balance}',
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
              Text(
                '投注: ${state.totalBet}',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
