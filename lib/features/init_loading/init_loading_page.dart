import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Second loading screen after UI selection — initializes before login.
class InitLoadingPage extends StatefulWidget {
  const InitLoadingPage({super.key});

  static const Duration displayDuration = Duration(seconds: 3);

  @override
  State<InitLoadingPage> createState() => _InitLoadingPageState();
}

class _InitLoadingPageState extends State<InitLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _navTimer = Timer(InitLoadingPage.displayDuration, _goLogin);
  }

  void _goLogin() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/ui_select_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: Color(0xFF0E0E0E));
            },
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _spinController,
                  child: const Icon(
                    Icons.sync,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '正在初始化游戏信息...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
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
