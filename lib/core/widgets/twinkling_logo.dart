import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Same pulse as the member site `.animate-twinkling` (1s, ease-in-out).
class TwinklingLogo extends StatefulWidget {
  const TwinklingLogo({super.key, this.width = 220});

  final double width;

  @override
  State<TwinklingLogo> createState() => _TwinklingLogoState();
}

class _TwinklingLogoState extends State<TwinklingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _logo() {
    return Image.asset(
      AppAssets.logo,
      width: widget.width,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.casino_outlined,
        color: CasinoColors.gold,
        size: widget.width * 0.36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final brightness = 0.7 + (1.1 - 0.7) * t;
        final blur = 3 + (9 - 3) * t;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.3 + (0.8 - 0.3) * t,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: _logo(),
              ),
            ),
            ColorFiltered(
              colorFilter: ColorFilter.matrix(<double>[
                brightness, 0, 0, 0, 0,
                0, brightness, 0, 0, 0,
                0, 0, brightness, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: _logo(),
            ),
          ],
        );
      },
    );
  }
}
