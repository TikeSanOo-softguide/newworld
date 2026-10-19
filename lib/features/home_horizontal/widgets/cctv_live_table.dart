import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../baccarat_state.dart';
import 'cctv_effects_overlay.dart';
import 'live_status_overlay.dart';

/// Black live/video panel (CCTV simulated) above the betting board.
class CctvLiveTable extends ConsumerStatefulWidget {
  const CctvLiveTable({super.key});

  @override
  ConsumerState<CctvLiveTable> createState() => _CctvLiveTableState();
}

class _CctvLiveTableState extends ConsumerState<CctvLiveTable> {
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(baccaratProvider);

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/cctv_baccarat_table.png',
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.35),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: Colors.black);
            },
          ),
          const CctvEffectsOverlay(),
          LiveStatusOverlay(now: _now),
          Positioned(
            left: 8,
            top: 36,
            child: Text(
              '${state.shoe}靴 - ${state.round}局',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
