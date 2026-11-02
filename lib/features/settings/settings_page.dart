import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../auth/auth_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _account = '';
  String _balance = '0';
  bool _trial = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final storage = ref.read(secureStorageProvider);
    final account = await storage.getAccount() ?? '';
    final balance = await storage.getBalance();
    final trial = await storage.getTrialUser();
    if (!mounted) return;
    setState(() {
      _account = account;
      _balance = balance;
      _trial = trial;
    });
  }

  Future<void> _logout() async {
    final accepted = await showGoldDialog(
      context: context,
      kind: GoldDialogKind.confirm,
      title: '提示',
      message: '确定要退出游戏吗？',
      cancelLabel: '取消',
    );
    if (!accepted || !mounted || _loggingOut) return;
    setState(() => _loggingOut = true);
    await ref.read(authServiceProvider).logout();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return GoldenDarkBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: CasinoColors.gold,
                    size: 18,
                  ),
                ),
                const Text(
                  '设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66C6A15B)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC2A2214), Color(0xCC14110C)],
              ),
            ),
            child: Row(
              children: [
                Image.asset(AppAssets.logo, width: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _account.isEmpty ? '会员' : _account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '余额 $_balance',
                        style: const TextStyle(
                          color: CasinoColors.gold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_trial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33C41E3A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFB4B4)),
                    ),
                    child: const Text(
                      '试玩中',
                      style: TextStyle(
                        color: Color(0xFFFFD0D0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: TextButton(
                onPressed: _loggingOut ? null : _logout,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3128),
                  disabledBackgroundColor: const Color(0xFF3A3128),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x99C6A15B)),
                  ),
                ),
                child: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CasinoColors.gold,
                        ),
                      )
                    : const Text(
                        '退出游戏',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
