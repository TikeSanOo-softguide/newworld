import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/twinkling_logo.dart';
import '../preload/lobby_preload.dart';
import 'auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _random = Random();

  bool _rememberAccount = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String _captcha = '';
  int? _lockedUntil;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
    final local = ref.read(localStorageProvider);
    _rememberAccount = local.getRememberMe();
    final saved = local.getRememberedAccount();
    if (_rememberAccount && saved != null) {
      _accountController.text = saved;
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _accountController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  bool get _locked =>
      _lockedUntil != null &&
      _lockedUntil! > DateTime.now().millisecondsSinceEpoch;

  void _refreshCaptcha() {
    _captcha = List.generate(4, (_) => _random.nextInt(10).toString()).join();
    _captchaController.clear();
  }

  void _applyLock(int until) {
    _lockTimer?.cancel();
    _lockedUntil = until;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_locked) {
        _lockTimer?.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _submit({bool trial = false}) async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;

    final account = trial ? AppConstants.trialAccount : _accountController.text;
    final password =
        trial ? AppConstants.trialPassword : _passwordController.text;

    if (!trial && (account.trim().isEmpty || password.isEmpty)) {
      await _notice('账号或密码不可为空', kind: GoldDialogKind.error);
      return;
    }
    if (_locked) {
      final seconds = ((_lockedUntil! - DateTime.now().millisecondsSinceEpoch) /
              1000)
          .ceil();
      await _notice('此账号已被锁定 ${seconds}s', kind: GoldDialogKind.error);
      return;
    }
    if (!trial && _captchaController.text.trim() != _captcha) {
      setState(_refreshCaptcha);
      await _notice('验证码不对', kind: GoldDialogKind.error);
      return;
    }

    setState(() => _submitting = true);
    String? failure;
    try {
      final result = await ref.read(authServiceProvider).login(
            account: account,
            password: password,
            rememberAccount: _rememberAccount,
            trial: trial,
          );
      if (!mounted) return;
      if (!result.oldUserFlg) {
        context.go(AppRoutes.changePassword);
        return;
      }
      await ref.read(authServiceProvider).fetchCurrentUser();
      if (!mounted) return;
      context.go(AppRoutes.agreement);
    } on AuthException catch (error) {
      if (error.lockedUntil != null) _applyLock(error.lockedUntil!);
      failure = error.message;
      _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted || failure == null) return;
    await _notice(failure, kind: GoldDialogKind.error);
  }

  Future<void> _confirmTrial() async {
    final accepted = await showGoldDialog(
      context: context,
      kind: GoldDialogKind.confirm,
      title: '提示',
      message: '试玩账号为免费账号，不可下分汇款。确定要用试玩账号登录？',
      cancelLabel: '取消',
    );
    if (accepted) await _submit(trial: true);
  }

  Future<void> _notice(
    String message, {
    required GoldDialogKind kind,
    String title = '提示',
  }) {
    return showGoldDialog(
      context: context,
      kind: kind,
      title: title,
      message: message,
    );
  }

  void _showQq() {
    showGoldDialog(
      context: context,
      kind: GoldDialogKind.info,
      title: '在线QQ',
      message: 'QQ: 1258081277',
    );
  }

  Future<void> _openAgentSite() async {
    final site = ref.read(lobbyPreloadProvider).setting('agent_website');
    if (site == null || site.isEmpty) {
      await _notice('暂无代理网址', kind: GoldDialogKind.error);
      return;
    }
    await Clipboard.setData(ClipboardData(text: site));
    if (!mounted) return;
    await _notice('已复制代理网址', kind: GoldDialogKind.success, title: '成功');
  }

  void _downloadClient() {
    _notice('客户端请在电脑浏览器下载', kind: GoldDialogKind.info);
  }

  InputDecoration _liquidField({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0x66C6A15B)),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      filled: true,
      fillColor: const Color(0x8016100C),
      hintStyle: const TextStyle(
        color: Color(0xB3F4E7C3),
        fontSize: 16,
        height: 1.2,
      ),
      prefixIconColor: CasinoColors.gold,
      suffixIconColor: CasinoColors.gold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xE6E8C872), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoldenDarkBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LiquidGlassCard(
                    child: Column(
                          children: [
                            const TwinklingLogo(width: 100),
                            const SizedBox(height: 22),
                            TextField(
                              controller: _accountController,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: _liquidField(
                                hint: '请输入账号',
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: _liquidField(
                                hint: '请输入密码',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Text(
                                  '验证码',
                                  style: TextStyle(
                                    color: CasinoColors.muted,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _captchaController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    decoration: _liquidField(hint: '4 位数字'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => setState(_refreshCaptcha),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 76,
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0x33C6A15B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0x99E8C872),
                                      ),
                                    ),
                                    child: Text(
                                      _captcha,
                                      style: const TextStyle(
                                        color: Color(0xFFF6E7C1),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => setState(
                                  () => _rememberAccount = !_rememberAccount,
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.standard,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.fromLTRB(2, 18, 4, 18),
                                  minimumSize: const Size(0, 56),
                                ),
                                icon: Icon(
                                  _rememberAccount
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: CasinoColors.gold,
                                  size: 22,
                                ),
                                label: const Text(
                                  '记住账号',
                                  style: TextStyle(
                                    color: CasinoColors.muted,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            GoldButton(
                              label: '登录',
                              loading: _submitting,
                              onPressed: _locked ? null : () => _submit(),
                              colors: const [
                                Color(0xFFB7EFC6),
                                Color(0xFF2EAE55),
                                Color(0xFF146B34),
                              ],
                              foregroundColor: const Color(0xFF083018),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _FrontButton(
                                    label: '在线QQ',
                                    colors: const [
                                      Color(0xFF123A9A),
                                      Color(0xFF1E5CFF),
                                      Color(0xFF0A2E78),
                                    ],
                                    onPressed: _showQq,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _FrontButton(
                                    label: '试玩',
                                    colors: const [
                                      Color(0xFF8B1020),
                                      Color(0xFFC41E3A),
                                      Color(0xFF6B0A14),
                                    ],
                                    onPressed:
                                        _submitting ? null : _confirmTrial,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _FrontButton(
                                    label: '代理登录',
                                    colors: const [
                                      Color(0xFF8E1458),
                                      Color(0xFFC2186A),
                                      Color(0xFF6B1048),
                                    ],
                                    onPressed: _openAgentSite,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _FrontButton(
                                    label: '客户端下载',
                                    colors: const [
                                      Color(0xFFA84A00),
                                      Color(0xFFE07010),
                                      Color(0xFF8A3E00),
                                    ],
                                    onPressed: _downloadClient,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '当前状态: 网络投注',
                              style: TextStyle(
                                color: Color(0xFFE6E0D4),
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Member-site `.liquid-glass` panel: blur, sheen, and a soft inner edge.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xE6241C12),
                      Color(0xE6100E0C),
                      Color(0xF20A0908),
                    ],
                  ),
                  border: Border.all(color: const Color(0x99C6A15B)),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              left: 18,
              right: 18,
              child: SizedBox(
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00E8C872),
                        Color(0xCCE8C872),
                        Color(0x00E8C872),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.05),
                    radius: 0.9,
                    colors: [Color(0x33C6A15B), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _FrontButton extends StatelessWidget {
  const _FrontButton({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border.all(color: const Color(0x99E8C872)),
      ),
      child: SizedBox(
        height: 40,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
