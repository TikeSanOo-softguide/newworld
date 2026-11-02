import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum GoldDialogKind { info, confirm, error, success }

/// Luxury notice used for errors, confirmations, and success messages.
Future<bool> showGoldDialog({
  required BuildContext context,
  required String title,
  required String message,
  GoldDialogKind kind = GoldDialogKind.info,
  String confirmLabel = '确定',
  String? cancelLabel,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xC4060504),
    builder: (context) {
      return _GoldDialog(
        title: title,
        message: message,
        kind: kind,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      );
    },
  );
  return accepted == true;
}

class _GoldDialog extends StatelessWidget {
  const _GoldDialog({
    required this.title,
    required this.message,
    required this.kind,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final GoldDialogKind kind;
  final String confirmLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    final accent = switch (kind) {
      GoldDialogKind.error => const Color(0xFFFFB4B4),
      GoldDialogKind.success => const Color(0xFFE8C872),
      GoldDialogKind.confirm => const Color(0xFFE8C872),
      GoldDialogKind.info => const Color(0xFFE8C872),
    };
    final icon = switch (kind) {
      GoldDialogKind.error => Icons.error_outline,
      GoldDialogKind.success => Icons.check_circle_outline,
      GoldDialogKind.confirm => Icons.help_outline,
      GoldDialogKind.info => Icons.info_outline,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x99C6A15B)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xF2302416),
                  Color(0xF614100C),
                  Color(0xFA0C0A08),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.85)),
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.28),
                          const Color(0x00000000),
                        ],
                      ),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CasinoColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF4E7C3),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cancelLabel != null) ...[
                        _DialogButton(
                          label: cancelLabel!,
                          filled: false,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _DialogButton(
                        label: confirmLabel,
                        filled: true,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: TextStyle(
        color: filled ? const Color(0xFF2A1C08) : CasinoColors.gold,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
    if (!filled) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(72, 32),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Color(0x99C6A15B)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3D48A), Color(0xFFC6923E), Color(0xFF8C6424)],
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(72, 32),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF2A1C08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: child,
      ),
    );
  }
}
