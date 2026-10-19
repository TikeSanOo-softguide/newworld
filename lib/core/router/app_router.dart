import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/home_horizontal/horizontal_home_page.dart';
import '../../features/home_vertical/vertical_home_page.dart';
import '../../features/init_loading/init_loading_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/terms/terms_page.dart';
import '../../features/ui_selection/ui_selection_page.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const uiSelection = '/ui-selection';
  static const initLoading = '/init-loading';
  static const login = '/login';
  static const terms = '/terms';
  static const homeHorizontal = '/home/horizontal';
  static const homeVertical = '/home/vertical';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.uiSelection,
        name: 'uiSelection',
        builder: (context, state) => const UiSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.initLoading,
        name: 'initLoading',
        builder: (context, state) => const InitLoadingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const SharedLoginPage(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        name: 'terms',
        builder: (context, state) => const TermsPage(),
      ),
      GoRoute(
        path: AppRoutes.homeHorizontal,
        name: 'homeHorizontal',
        builder: (context, state) => const HorizontalHomePage(),
      ),
      GoRoute(
        path: AppRoutes.homeVertical,
        name: 'homeVertical',
        builder: (context, state) => const VerticalHomePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面不存在：${state.uri}'),
      ),
    ),
  );
});
