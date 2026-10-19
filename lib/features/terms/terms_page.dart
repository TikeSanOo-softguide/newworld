import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../auth/auth_service.dart';

/// Landscape terms screen shown after U1 (经典版) login.
class TermsPage extends ConsumerStatefulWidget {
  const TermsPage({super.key});

  static const String bodyText = '''
1. 本平台所提供的产品和服务，均由相应产品公司提供。若有任何疑问，请联系相关产品公司。

2. 为保障账号及资金安全，请勿向他人透露您的密码及验证码，并定期修改密码。

3. 在下注过程中，若出现网络中断，以本平台最终数据为准。
''';

  @override
  ConsumerState<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends ConsumerState<TermsPage> {
  static const Color _gold = Color(0xFFFFBF00);
  static const Color _goldLight = Color(0xFFFFE566);
  static const Color _goldDark = Color(0xFFE0A800);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restorePortrait() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _onAgree() async {
    await _restorePortrait();
    if (!mounted) return;
    context.go(AppRoutes.homeHorizontal);
  }

  Future<void> _onRefuse() async {
    await ref.read(authServiceProvider).logout();
    await _restorePortrait();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    // Keep landscape unlock if user navigates away unexpectedly.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Space-themed login bg (terms screenshot is a rotated UI mock).
          Image.asset(
            'assets/images/login_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/login_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(color: Color(0xFF050B18));
                },
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x66000000),
                  Color(0x99000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
              child: Column(
                children: [
                  const Text(
                    '协议条款',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: const Text(
                            TermsPage.bodyText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.7,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _GoldActionButton(
                          label: '我同意',
                          gold: _gold,
                          goldLight: _goldLight,
                          goldDark: _goldDark,
                          onPressed: _onAgree,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _GoldActionButton(
                          label: '我拒绝',
                          gold: _gold,
                          goldLight: _goldLight,
                          goldDark: _goldDark,
                          onPressed: _onRefuse,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldActionButton extends StatelessWidget {
  const _GoldActionButton({
    required this.label,
    required this.onPressed,
    required this.gold,
    required this.goldLight,
    required this.goldDark,
  });

  final String label;
  final VoidCallback onPressed;
  final Color gold;
  final Color goldLight;
  final Color goldDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [goldLight, gold, goldDark],
              stops: const [0, 0.45, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
