import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';

/// Splash with full-bleed artwork and a golden loading bar (0 → 100% in 10s).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Duration for the determinate gold progress fill.
  static const Duration loadDuration = Duration(seconds: 10);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);

  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final Animation<double> _fadeAnimation;
  bool _navigated = false;
  UiStyle? _savedStyle;
  bool _hasSession = false;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _enableFullscreenSplash();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _progressController = AnimationController(
      vsync: this,
      duration: SplashPage.loadDuration,
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _tryNavigate();
      }
    });

    _fadeController.forward();
    _progressController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  void _enableFullscreenSplash() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _loadSession() async {
    final local = ref.read(localStorageProvider);
    final auth = ref.read(authServiceProvider);
    _savedStyle = local.getUiStyle();
    _hasSession = await auth.hasValidSession();
    if (!mounted) return;
    _sessionReady = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (!mounted || _navigated) return;
    if (!_sessionReady || !_progressController.isCompleted) return;

    _navigated = true;
    _restoreSystemUi();

    if (_savedStyle != null && _hasSession) {
      switch (_savedStyle!) {
        case UiStyle.u1:
          context.go(AppRoutes.homeHorizontal);
        case UiStyle.u2:
          context.go(AppRoutes.homeVertical);
      }
      return;
    }

    context.go(AppRoutes.uiSelection);
  }

  @override
  void dispose() {
    if (!_navigated) _restoreSystemUi();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        // Draw under status / nav bars — image covers the whole screen.
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: _SplashBackground()),
              // Narrower width, thicker (taller) gold loading bar.
              Positioned(
                left: 0,
                right: 0,
                bottom: 28 + bottomInset,
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.42,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progressController.value,
                            minHeight: 12,
                            backgroundColor: const Color(0x33D4AF37),
                            color: _gold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    // BoxFit.fill = stretch to every pixel (no black bars, full screen).
    return Image.asset(
      'assets/images/splash_image.jpg',
      fit: BoxFit.fill,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/splash_image.png',
          fit: BoxFit.fill,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return ColoredBox(
              color: Colors.black,
              child: Center(
                child: Image.asset(
                  AppConstants.appLogoAsset,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.public,
                      size: 96,
                      color: AppTheme.primary,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
