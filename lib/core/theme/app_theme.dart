import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Shared colors for the member loading and login screens.
abstract final class CasinoColors {
  static const Color ink = Color(0xFF0C0F14);
  static const Color gold = Color(0xFFE8C872);
  static const Color goldDeep = Color(0xFFB8893A);
  static const Color card = Color(0xE614161C);
  static const Color field = Color(0xFF1A1D24);
  static const Color muted = Color(0xFFB7B1A4);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CasinoColors.goldDeep,
      brightness: Brightness.dark,
      primary: CasinoColors.gold,
      surface: CasinoColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF080808),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: CasinoColors.gold,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CasinoColors.field,
        hintStyle: const TextStyle(color: Color(0xFF8A8478)),
        prefixIconColor: CasinoColors.gold,
        suffixIconColor: CasinoColors.gold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x66C6A15B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x66C6A15B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CasinoColors.gold, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Gold glow at the top fading into near-black. Background only.
class GoldenDarkBackground extends StatelessWidget {
  const GoldenDarkBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4A3A16),
                  Color(0xFF241C0E),
                  Color(0xFF121212),
                  Color(0xFF080808),
                ],
                stops: [0.0, 0.22, 0.48, 1.0],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.92),
                radius: 0.85,
                colors: [
                  Color(0xCCB8893A),
                  Color(0x553A2E12),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class CasinoBackground extends StatelessWidget {
  const CasinoBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CasinoColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                AppAssets.loginBackgroundFallback,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(color: CasinoColors.ink);
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
                  Color(0xD907080C),
                  Color(0x990B0E14),
                  Color(0xF207080C),
                ],
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

abstract final class AppAssets {
  static const loginBackground = 'assets/images/login_bg.jpg';
  static const loginBackgroundFallback = 'assets/images/login_bg.png';
  static const logo = AppConstants.appLogoAsset;
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.colors = const [
      Color(0xFFF3D48A),
      Color(0xFFC6923E),
      Color(0xFF8C6424),
    ],
    this.foregroundColor = const Color(0xFF2A1C08),
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final List<Color> colors;
  final Color foregroundColor;

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
      ),
      child: SizedBox(
        width: double.infinity,
        height: 42,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            foregroundColor: foregroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: foregroundColor,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
