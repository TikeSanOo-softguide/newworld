import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/twinkling_logo.dart';
import '../preload/lobby_preload.dart';

class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key});

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  static const _total = 4;

  int _completed = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_started) return;
    _started = true;

    final snapshot = await ref
        .read(preloadLoaderProvider)
        .load(
          onProgress: (completed, total) {
            if (!mounted) return;
            setState(() => _completed = completed.clamp(0, total));
          },
        );
    if (!mounted) return;
    ref.read(lobbyPreloadProvider.notifier).replace(snapshot);

    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    final secure = ref.read(secureStorageProvider);
    final hasSession = await secure.hasValidSession();
    if (!mounted) return;
    if (!hasSession) {
      context.go(AppRoutes.login);
      return;
    }
    final oldUser = await secure.getOldUserFlag();
    if (!mounted) return;
    context.go(oldUser ? AppRoutes.lobby : AppRoutes.changePassword);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completed / _total;
    final percent = (progress * 100).round();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF080808),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: GoldenDarkBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TwinklingLogo(width: 200),

                const SizedBox(height: 28),

                // Text above progress bar
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '加载背景资源',
                    style: TextStyle(
                      color: Color(0xFFD6D0C5),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Progress bar
                Container(
                  height: 13,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF55504A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: const Color(0xFF9B927F),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0x33C6A15B),
                      color: CasinoColors.gold,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  '正在加载游戏……$percent%',
                  style: const TextStyle(
                    color: Color(0xFFD6D0C5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
