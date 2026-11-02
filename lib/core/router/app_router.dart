import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/agreement_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/session_pages.dart';
import '../../features/loading/loading_page.dart';
import '../../features/lobby/lobby_page.dart';
import '../../features/settings/settings_page.dart';

abstract final class AppRoutes {
  static const loading = '/';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const agreement = '/agreement';
  static const lobby = '/lobby';
  static const settings = '/settings';
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
        path: AppRoutes.agreement,
        name: 'agreement',
        builder: (context, state) => const AgreementPage(),
      ),
      GoRoute(
        path: AppRoutes.lobby,
        name: 'lobby',
        builder: (context, state) => LobbyPage(
          showNotice: state.uri.queryParameters['notice'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
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
