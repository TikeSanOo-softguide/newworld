import 'package:flutter/material.dart';

/// White bead plate + big road grid matching classic Baccarat UI.
class BaccaratRoadmap extends StatelessWidget {
  const BaccaratRoadmap({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(flex: 5, child: _BeadPlate()),
              Container(height: 1, color: Colors.black12),
              Expanded(flex: 4, child: _BigRoad()),
              const SizedBox(height: 14),
            ],
          ),
          // 测试中 watermark
          IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: -0.35,
                child: Text(
                  '测试中',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.red.withValues(alpha: 0.28),
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 ? Colors.black54 : Colors.black26,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeadPlate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
      ),
      itemCount: 48,
      itemBuilder: (context, i) {
        final colors = [
          const Color(0xFFE53935),
          const Color(0xFF1E88E5),
          const Color(0xFF43A047),
        ];
        final labels = ['庄', '闲', '和'];
        final idx = (i * 7) % 3;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors[idx],
              shape: BoxShape.circle,
            ),
            child: Text(
              labels[idx],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BigRoad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 14,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: 70,
      itemBuilder: (context, i) {
        final empty = i % 5 == 0 || i > 55;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
          ),
          alignment: Alignment.center,
          child: empty
              ? null
              : Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i.isEven
                          ? const Color(0xFFE53935)
                          : const Color(0xFF1E88E5),
                      width: 1.4,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
