import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/session_pages.dart';
import '../../features/loading/loading_page.dart';

abstract final class AppRoutes {
  static const loading = '/';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const session = '/session';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.loading,
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        name: 'loading',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        name: 'changePassword',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.session,
        name: 'session',
        builder: (context, state) => const SessionPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('页面不存在：${state.uri}')),
    ),
  );
});
