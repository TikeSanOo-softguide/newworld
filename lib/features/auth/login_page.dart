import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/twinkling_logo.dart';
import 'auth_service.dart';

enum _InstallGuidePlatform { android, ios }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _h5InstallButtonKey = GlobalKey();
  final _h5InstallOptionsKey = GlobalKey();

  bool _rememberAccount = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _showH5InstallOptions = false;
  int? _lockedUntil;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  bool get _locked =>
      _lockedUntil != null &&
      _lockedUntil! > DateTime.now().millisecondsSinceEpoch;

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
    final password = trial
        ? AppConstants.trialPassword
        : _passwordController.text;

    if (!trial && (account.trim().isEmpty || password.isEmpty)) {
      await _notice('账号或密码不可为空', kind: GoldDialogKind.error);
      return;
    }
    if (_locked) {
      final seconds =
          ((_lockedUntil! - DateTime.now().millisecondsSinceEpoch) / 1000)
              .ceil();
      await _notice('此账号已被锁定 ${seconds}s', kind: GoldDialogKind.error);
      return;
    }
    setState(() => _submitting = true);
    String? failure;
    try {
      final result = await ref
          .read(authServiceProvider)
          .login(
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted || failure == null) return;
    await _notice(failure, kind: GoldDialogKind.error);
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    String? errorDetails;

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on PlatformException catch (error) {
      errorDetails = error.toString();
    } on MissingPluginException catch (error) {
      errorDetails = error.toString();
    }

    debugPrint(
      errorDetails == null
          ? 'Could not open URL: $url'
          : 'Could not open URL: $url ($errorDetails)',
    );
    if (!mounted) return;
    await _notice('无法打开链接，请检查浏览器配置后重试', kind: GoldDialogKind.error);
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

  void _toggleH5InstallOptions() {
    setState(() => _showH5InstallOptions = !_showH5InstallOptions);
  }

  void _dismissH5InstallOptionsOutside(PointerDownEvent event) {
    if (!_showH5InstallOptions ||
        _containsGlobalPosition(_h5InstallButtonKey, event.position) ||
        _containsGlobalPosition(_h5InstallOptionsKey, event.position)) {
      return;
    }

    setState(() => _showH5InstallOptions = false);
  }

  bool _containsGlobalPosition(GlobalKey key, Offset position) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;

    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.contains(position);
  }

  Future<void> _openH5InstallGuide(_InstallGuidePlatform platform) async {
    setState(() => _showH5InstallOptions = false);
    final url = switch (platform) {
      _InstallGuidePlatform.android => 'https://adad.abfd32.cn/mobile/Install/android_sp.html?r=0.6979901995778091',
      _InstallGuidePlatform.ios => 'https://adad.abfd32.cn/mobile/Install/ios_sp.html?r=0.6765042799219435',
    };
    await _openExternalUrl(url);
  }

  Widget _h5InstallOptions() {
    const textStyle = TextStyle(
      color: CasinoColors.gold,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return KeyedSubtree(
      key: _h5InstallOptionsKey,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xE61D1912),
          border: Border.all(color: const Color(0xFFC6A15B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _H5InstallOption(
              icon: Icons.apple_outlined,
              label: '苹果 H5 安装说明',
              onPressed: () => _openH5InstallGuide(_InstallGuidePlatform.ios),
              textStyle: textStyle,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Divider(height: 1, color: Color(0x668A744A)),
            ),
            _H5InstallOption(
              icon: Icons.phone_android_outlined,
              label: '安卓 H5 安装说明',
              onPressed: () =>
                  _openH5InstallGuide(_InstallGuidePlatform.android),
              textStyle: textStyle,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadClient() async {
    await _openExternalUrl(
      'https://adad.abfd32.cn/mobile/neworld23/install.html?r=0.4896935546480302',
    );
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
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _dismissH5InstallOptionsOutside,
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
                          const TwinklingLogo(width: 200),
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
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _rememberAccount = !_rememberAccount,
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.standard,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.fromLTRB(
                                  2,
                                  18,
                                  4,
                                  18,
                                ),
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
                          // Login button
                          GoldButton(
                            label: '登录',
                            loading: _submitting,
                            onPressed: _locked ? null : () => _submit(),
                            colors: const [
                              Color(0xFFF3D48A),
                              Color(0xFFC6923E),
                              Color(0xFF8C6424),
                            ],
                            foregroundColor: const Color(0xFF083018),
                          ),
                          const SizedBox(height: 24),

                          // Trial button
                          GoldButton(
                            label: '试玩',
                            colors: const [
                              Color(0xFF347D20),
                              Color(0xFF286B19),
                              Color(0xFF205914),
                            ],
                            onPressed: _submitting ? null : _confirmTrial,
                            foregroundColor: Colors.white,
                          ),

                          const SizedBox(height: 20),

                          // H5 installation instructions
                          KeyedSubtree(
                            key: _h5InstallButtonKey,
                            child: GoldButton(
                              label: 'H5安装说明',
                              colors: const [
                                Color(0xFF347D20),
                                Color(0xFF286B19),
                                Color(0xFF205914),
                              ],
                              onPressed: _toggleH5InstallOptions,
                              foregroundColor: Colors.white,
                            ),
                          ),

                          if (_showH5InstallOptions) ...[
                            const SizedBox(height: 6),
                            _h5InstallOptions(),
                          ],

                          const SizedBox(height: 20),

                          // Android app download
                          GoldButton(
                            label: '安卓APP下载',
                            colors: const [
                              Color(0xFF347D20),
                              Color(0xFF286B19),
                              Color(0xFF205914),
                            ],
                            onPressed: _downloadClient,
                            foregroundColor: Colors.white,
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
      ),
    );
  }
}

class _H5InstallOption extends StatelessWidget {
  const _H5InstallOption({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.textStyle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: CasinoColors.gold, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: textStyle)),
              const Icon(
                Icons.chevron_right,
                color: CasinoColors.gold,
                size: 18,
              ),
            ],
          ),
        ),
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
