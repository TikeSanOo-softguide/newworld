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
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_started) return;
    _started = true;

    final snapshot = await ref.read(preloadLoaderProvider).load(
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
                const TwinklingLogo(width: 112),
                const SizedBox(height: 36),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0x33C6A15B),
                      color: CasinoColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: CasinoColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
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
