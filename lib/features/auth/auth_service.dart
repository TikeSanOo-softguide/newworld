import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import 'demo_accounts.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
    localStorage: ref.watch(localStorageProvider),
  );
});

class AuthResult {
  const AuthResult({
    required this.token,
    this.userId,
    this.username,
    this.uiStyle,
  });

  final String token;
  final String? userId;
  final String? username;
  final UiStyle? uiStyle;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Authenticates against the JSON API. Never treats login as always successful.
class AuthService {
  AuthService({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
    required LocalStorage localStorage,
  })  : _api = apiClient,
        _secure = secureStorage,
        _local = localStorage;

  final ApiClient _api;
  final SecureStorage _secure;
  final LocalStorage _local;

  Future<bool> hasValidSession() => _secure.hasValidSession();

  /// Saved username/password for a specific UI style (U1 / U2 separate).
  Future<({bool remember, String? username, String? password})>
      loadRememberedCredentials(UiStyle style) async {
    final remember = _local.getRememberMeFor(style);
    if (!remember) {
      return (remember: false, username: null, password: null);
    }
    final username = _local.getRememberedUsernameFor(style);
    final password = await _secure.getRememberedPasswordFor(style);
    return (remember: true, username: username, password: password);
  }

  Future<void> _persistRemembered({
    required UiStyle style,
    required bool rememberMe,
    required String username,
    required String password,
  }) async {
    await _local.setRememberMeFor(style, rememberMe);
    if (rememberMe) {
      await _local.setRememberedUsernameFor(style, username);
      await _secure.setRememberedPasswordFor(style, password);
    } else {
      await _local.setRememberedUsernameFor(style, null);
      await _secure.clearRememberedPasswordFor(style);
    }
  }

  Future<AuthResult> login({
    required String username,
    required String password,
    required bool rememberMe,
    UiStyle? selectedStyle,
  }) async {
    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty) {
      throw AuthException('请输入用户名');
    }
    if (password.isEmpty) {
      throw AuthException('请输入密码');
    }

    // Fake local accounts → different UI styles (classic / upgrade).
    final demo = DemoAccounts.match(trimmedUser, password);
    if (demo != null) {
      final token = 'demo-token-${demo.userId}';
      await _secure.setAuthToken(token);
      await _secure.setUserId(demo.userId);
      await _local.setUiStyle(demo.uiStyle);
      await _persistRemembered(
        style: demo.uiStyle,
        rememberMe: rememberMe,
        username: demo.username,
        password: password,
      );
      return AuthResult(
        token: token,
        userId: demo.userId,
        username: demo.username,
        uiStyle: demo.uiStyle,
      );
    }

    try {
      final json = await _api.postJson(
        AppConstants.loginPath,
        body: {
          'username': trimmedUser,
          'password': password,
        },
      );

      final token = _extractToken(json);
      if (token == null || token.isEmpty) {
        throw AuthException('登录失败：服务器未返回有效令牌');
      }

      final userId = json['userId']?.toString() ??
          json['user_id']?.toString() ??
          (json['user'] is Map
              ? (json['user'] as Map)['id']?.toString()
              : null);

      await _secure.setAuthToken(token);
      await _secure.setUserId(userId);

      final style = selectedStyle ?? _local.getUiStyle() ?? UiStyle.u1;
      await _persistRemembered(
        style: style,
        rememberMe: rememberMe,
        username: trimmedUser,
        password: password,
      );

      return AuthResult(
        token: token,
        userId: userId,
        username: trimmedUser,
        uiStyle: style,
      );
    } on AuthException {
      rethrow;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw AuthException('用户名或密码错误');
      }
      throw AuthException(_localizeApiMessage(e.message));
    } on SocketException {
      throw AuthException('网络连接失败，请检查网络后重试');
    } on TimeoutException {
      throw AuthException('请求超时，请稍后重试');
    } on FormatException {
      throw AuthException('服务器响应格式错误');
    } catch (_) {
      throw AuthException('登录失败，请稍后重试');
    }
  }

  Future<void> logout() async {
    await _secure.clearSession();
  }

  String? _extractToken(Map<String, dynamic> json) {
    final direct = json['token'] ?? json['accessToken'] ?? json['access_token'];
    if (direct != null) return direct.toString();
    final data = json['data'];
    if (data is Map) {
      final nested = data['token'] ?? data['accessToken'] ?? data['access_token'];
      if (nested != null) return nested.toString();
    }
    return null;
  }

  String _localizeApiMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid') ||
        lower.contains('unauthorized') ||
        lower.contains('credential')) {
      return '用户名或密码错误';
    }
    if (message.contains('用户') || message.contains('密码') || message.contains('登录')) {
      return message;
    }
    return '登录失败：$message';
  }
}
