import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/auth_service.dart';

/// Right icon strip: 投注记录 / 在线客服 / 设置 / 退出
class BaccaratSidePanel extends ConsumerWidget {
  const BaccaratSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 56,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          _IconItem(
            icon: Icons.receipt_long,
            label: '投注记录',
            showDot: true,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          _IconItem(
            icon: Icons.headset_mic,
            label: '在线客服',
            onTap: () {},
          ),
          const Spacer(),
          IconButton(
            tooltip: '设置',
            onPressed: () {},
            icon: const Icon(Icons.settings, color: Colors.white, size: 22),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }
}

class _IconItem extends StatelessWidget {
  const _IconItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              if (showDot)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

/// Far-left vertical URL / legal strip.
class BaccaratLeftUrlStrip extends StatelessWidget {
  const BaccaratLeftUrlStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      color: const Color(0xFF0F3D28),
      alignment: Alignment.center,
      child: const RotatedBox(
        quarterTurns: 3,
        child: Text(
          'www.newwold.com  ·  理性娱乐  ·  未满18岁禁止进入',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
