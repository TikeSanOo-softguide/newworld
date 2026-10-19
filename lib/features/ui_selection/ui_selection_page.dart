import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/local_storage.dart';

/// Dark luxury UI style selection — 经典版 (U1) / 升级版 (U2).
class UiSelectionPage extends ConsumerStatefulWidget {
  const UiSelectionPage({super.key});

  @override
  ConsumerState<UiSelectionPage> createState() => _UiSelectionPageState();
}

class _UiSelectionPageState extends ConsumerState<UiSelectionPage> {
  UiStyle? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(localStorageProvider).getUiStyle();
  }

  Future<void> _select(UiStyle style) async {
    if (_saving) return;
    setState(() {
      _selected = style;
      _saving = true;
    });
    try {
      await ref.read(localStorageProvider).setUiStyle(style);
      if (!mounted) return;
      context.go(AppRoutes.initLoading);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SelectBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoSize =
                      ((constraints.maxHeight - 120) / 2).clamp(110.0, 200.0);

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LogoOption(
                            size: logoSize,
                            assetPath: 'assets/images/logo_classic.png',
                            label: '经典版',
                            selected: _selected == UiStyle.u1,
                            onTap: _saving ? null : () => _select(UiStyle.u1),
                          ),
                          const SizedBox(height: 20),
                          const _PromptBanner(text: '请选择游戏类型'),
                          const SizedBox(height: 20),
                          _LogoOption(
                            size: logoSize,
                            assetPath: 'assets/images/logo_upgrade.png',
                            label: '升级版',
                            selected: _selected == UiStyle.u2,
                            onTap: _saving ? null : () => _select(UiStyle.u2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectBackground extends StatelessWidget {
  const _SelectBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ui_select_bg.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Color(0xFF0E0E0E),
          child: SizedBox.expand(),
        );
      },
    );
  }
}

class _PromptBanner extends StatelessWidget {
  const _PromptBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.55),
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LogoOption extends StatelessWidget {
  const _LogoOption({
    required this.size,
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);

  final double size;
  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: selected ? _gold : Colors.white24,
                  width: selected ? 3.5 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              // BoxFit.contain — show the full logo, no cropping.
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    width: size,
                    height: size,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.public,
                        size: size * 0.4,
                        color: _gold,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? _gold : Colors.white,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
