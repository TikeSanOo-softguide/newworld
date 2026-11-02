import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import 'auth_service.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    String? failure;
    var changed = false;
    try {
      await ref.read(authServiceProvider).changePassword(
            newPassword: _passwordController.text,
            confirmPassword: _confirmController.text,
          );
      changed = true;
    } on AuthException catch (error) {
      failure = error.message;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    if (failure != null) {
      await showGoldDialog(
        context: context,
        kind: GoldDialogKind.error,
        title: '提示',
        message: failure,
      );
      return;
    }
    if (!changed) return;
    await showGoldDialog(
      context: context,
      kind: GoldDialogKind.success,
      title: '成功',
      message: '密码已修改，请重新登录',
    );
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return CasinoBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          const Text(
            '首次登录',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CasinoColors.gold,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '请先修改密码，之后重新登录',
            textAlign: TextAlign.center,
            style: TextStyle(color: CasinoColors.muted),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '新密码',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmController,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '确认新密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          GoldButton(
            label: '确认修改',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key});

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  late final Future<_SessionView> _session;

  @override
  void initState() {
    super.initState();
    _session = _load(ref.read(secureStorageProvider));
  }

  Future<_SessionView> _load(SecureStorage storage) async {
    return _SessionView(
      account: await storage.getAccount() ?? '',
      name: await storage.getDisplayName(),
      trial: await storage.getTrialUser(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CasinoBackground(
      child: FutureBuilder<_SessionView>(
        future: _session,
        builder: (context, snapshot) {
          final view = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Image.asset(
                  AppAssets.logo,
                  width: 180,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.casino_outlined,
                    color: CasinoColors.gold,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  view == null ? '正在读取账号' : '已登录 ${view.account}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                if (view?.trial == true) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '试玩中',
                    style: TextStyle(
                      color: Color(0xFFFFB4B4),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (view?.name != null && view!.name!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    view.name!,
                    style: const TextStyle(color: CasinoColors.muted),
                  ),
                ],
                const Spacer(),
                const Text(
                  '大厅与投注将在下一阶段接入',
                  style: TextStyle(color: CasinoColors.muted),
                ),
                const SizedBox(height: 16),
                GoldButton(
                  label: '退出',
                  onPressed: () async {
                    await ref.read(authServiceProvider).logout();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SessionView {
  const _SessionView({required this.account, this.name, this.trial = false});

  final String account;
  final String? name;
  final bool trial;
}
