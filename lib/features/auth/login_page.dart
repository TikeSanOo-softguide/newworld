import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/local_storage.dart';
import 'auth_service.dart';

/// Shared login page for both U1 and U2 (no registration).
class SharedLoginPage extends ConsumerStatefulWidget {
  const SharedLoginPage({super.key});

  @override
  ConsumerState<SharedLoginPage> createState() => _SharedLoginPageState();
}

class _SharedLoginPageState extends ConsumerState<SharedLoginPage> {
  static const Color _gold = Color(0xFFFFBF00);
  static const Color _goldLight = Color(0xFFFFE566);
  static const Color _fieldFill = Color(0xCC1A1A1A);
  static const double _formWidthFactor = 0.60;
  static const double _controlHeight = 52;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;
  UiStyle? _uiStyle;

  String get _logoAsset {
    switch (_uiStyle) {
      case UiStyle.u2:
        return 'assets/images/logo_upgrade.png';
      case UiStyle.u1:
      case null:
        return 'assets/images/logo_classic.png';
    }
  }

  @override
  void initState() {
    super.initState();
    final local = ref.read(localStorageProvider);
    _uiStyle = local.getUiStyle() ?? UiStyle.u1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreRemembered());
  }

  Future<void> _restoreRemembered() async {
    final style = _uiStyle ?? UiStyle.u1;
    final saved =
        await ref.read(authServiceProvider).loadRememberedCredentials(style);
    if (!mounted) return;
    setState(() {
      _rememberMe = saved.remember;
      if (saved.username != null && saved.username!.isNotEmpty) {
        _usernameController.text = saved.username!;
      }
      if (saved.password != null && saved.password!.isNotEmpty) {
        _passwordController.text = saved.password!;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final result = await ref.read(authServiceProvider).login(
            username: _usernameController.text,
            password: _passwordController.text,
            rememberMe: _rememberMe,
            selectedStyle: _uiStyle,
          );

      if (!mounted) return;

      final style =
          result.uiStyle ?? ref.read(localStorageProvider).getUiStyle();
      if (style == UiStyle.u2) {
        context.go(AppRoutes.homeVertical);
      } else {
        // U1 → horizontal home (terms is not on this route).
        context.go(AppRoutes.homeHorizontal);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = '登录失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label（即将推出）'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.42),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      // Keep icon gold on focus (avoid theme primary takeover).
      prefixIconColor: _gold,
      suffixIconColor: _gold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(minHeight: _controlHeight),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _gold, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _gold, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _goldLight, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
    );
  }

  static const TextStyle _inputTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  @override
  Widget build(BuildContext context) {
    // Keyboard overlays; layout / background size stay fixed.
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _gold,
          selectionColor: _gold.withValues(alpha: 0.35),
          selectionHandleColor: _gold,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        // Critical: do not shrink body when keyboard opens.
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/login_bg.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/login_bg.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(color: Color(0xFF0A1628));
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
                      Color(0x66000000),
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x99000000),
                    ],
                    stops: [0, 0.25, 0.55, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: _gold),
                        onPressed: () => context.go(AppRoutes.uiSelection),
                        tooltip: '返回',
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        // Extra bottom padding so focused field can scroll above keyboard
                        // without resizing the overall design.
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          24 + keyboardBottom,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Push logo + form slightly lower on screen.
                              const SizedBox(height: 48),
                              Image.asset(
                                _logoAsset,
                                width: 168,
                                height: 168,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    AppConstants.appLogoAsset,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.contain,
                                  );
                                },
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: MediaQuery.sizeOf(context).width *
                                    _formWidthFactor,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocus,
                                      style: _inputTextStyle,
                                      cursorColor: _gold,
                                      cursorWidth: 2,
                                      cursorRadius: const Radius.circular(1),
                                      keyboardAppearance: Brightness.dark,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(
                                          RegExp(r'\n'),
                                        ),
                                      ],
                                      onFieldSubmitted: (_) {
                                        _passwordFocus.requestFocus();
                                      },
                                      decoration: _fieldDecoration(
                                        hint: '请输入账号',
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: _gold,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return '请输入账号';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      style: _inputTextStyle,
                                      cursorColor: _gold,
                                      cursorWidth: 2,
                                      cursorRadius: const Radius.circular(1),
                                      keyboardAppearance: Brightness.dark,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: _fieldDecoration(
                                        hint: '请输入密码',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: _gold,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            );
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: _gold,
                                          ),
                                          tooltip: _obscurePassword
                                              ? '显示密码'
                                              : '隐藏密码',
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return '请输入密码';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: _gold,
                                            checkColor: Colors.black,
                                            side: const BorderSide(
                                              color: _gold,
                                              width: 1.5,
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            onChanged: _submitting
                                                ? null
                                                : (value) {
                                                    setState(
                                                      () => _rememberMe =
                                                          value ?? false,
                                                    );
                                                  },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _submitting
                                              ? null
                                              : () => setState(
                                                    () => _rememberMe =
                                                        !_rememberMe,
                                                  ),
                                          child: const Text(
                                            '记住账户和密码',
                                            style: TextStyle(
                                              color: _gold,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_errorMessage != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFFF8A80),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 22),
                                    _GoldButton(
                                      label: '登录',
                                      loading: _submitting,
                                      onPressed:
                                          _submitting ? null : _submit,
                                    ),
                                    const SizedBox(height: 12),
                                    _GoldButton(
                                      label: '试玩',
                                      onPressed: () => _showSoon('试玩'),
                                    ),
                                    const SizedBox(height: 12),
                                    _GoldButton(
                                      label: 'H5安装说明',
                                      onPressed: () =>
                                          _showSoon('H5安装说明'),
                                    ),
                                    const SizedBox(height: 12),
                                    _GoldButton(
                                      label: '安卓APP下载',
                                      onPressed: () =>
                                          _showSoon('安卓APP下载'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  static const Color _gold = Color(0xFFFFBF00);
  static const Color _goldLight = Color(0xFFFFE566);
  static const Color _goldDark = Color(0xFFE0A800);
  static const double _controlHeight = 52;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: _controlHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: onPressed == null && !loading
                  ? [
                      _gold.withValues(alpha: 0.45),
                      _goldDark.withValues(alpha: 0.45),
                    ]
                  : const [_goldLight, _gold, _goldDark],
              stops: const [0, 0.45, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
