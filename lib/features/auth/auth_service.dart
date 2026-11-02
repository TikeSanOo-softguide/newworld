import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';

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
    required this.csrfToken,
    required this.userId,
    required this.account,
    required this.oldUserFlg,
    this.name,
    this.trialUserFlg = false,
  });

  final String token;
  final String csrfToken;
  final String userId;
  final String account;
  final String? name;
  final bool oldUserFlg;
  final bool trialUserFlg;
}

class AuthException implements Exception {
  AuthException(this.message, {this.lockedUntil});

  final String message;
  final int? lockedUntil;

  @override
  String toString() => message;
}

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

  Future<AuthResult> login({
    required String account,
    required String password,
    required bool rememberAccount,
    bool trial = false,
  }) async {
    final trimmed = account.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw AuthException('账号或密码不可为空');
    }

    try {
      final json = await _api.postJson(
        AppConstants.loginPath,
        body: {
          'account': trimmed,
          'password': password,
          'equipment': _equipmentLabel(),
          'browser': 'Newsworld',
        },
      );

      final token = json['accessToken']?.toString() ?? '';
      if (token.isEmpty) {
        throw AuthException('服务器未返回访问令牌');
      }

      final csrf = json['csrfToken']?.toString() ?? '';
      final userId = json['id']?.toString() ?? '';
      final resolvedAccount = json['account']?.toString() ?? trimmed;
      final name = json['name']?.toString();
      final oldUser = _isOldUser(json['old_user_flg']);
      final trialUser = trial ||
          json['trial_user_flg'] == true ||
          json['trial_user_flg'] == 1;

      await _secure.setAuthToken(token);
      await _secure.setUserId(userId);
      await _secure.setCsrfToken(csrf);
      await _secure.setAccount(resolvedAccount);
      await _secure.setDisplayName(name);
      await _secure.setOldUserFlag(oldUser);
      await _secure.setTrialUser(trialUser);
      if (!trial) {
        await _local.setRememberMe(rememberAccount);
        await _local.setRememberedAccount(rememberAccount ? trimmed : null);
      }

      return AuthResult(
        token: token,
        csrfToken: csrf,
        userId: userId,
        account: resolvedAccount,
        name: name,
        oldUserFlg: oldUser,
        trialUserFlg: trialUser,
      );
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      if (error.lockedUntil != null || error.message.contains('已被锁定')) {
        throw AuthException(
          '此账号已被锁定',
          lockedUntil: error.lockedUntil ??
              DateTime.now().millisecondsSinceEpoch +
                  const Duration(minutes: 3).inMilliseconds,
        );
      }
      throw AuthException(
        error.message.isEmpty ? '登录失败，请稍后重试' : error.message,
      );
    } on http.ClientException {
      throw AuthException('无法连接服务器，请确认 API 服务已启动');
    } on TimeoutException {
      throw AuthException('请求超时，请稍后重试');
    } on FormatException {
      throw AuthException('服务器响应格式错误');
    }
  }

  Future<void> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final next = newPassword.trim();
    if (!RegExp(r'^[A-Za-z0-9]{6,32}$').hasMatch(next)) {
      throw AuthException('只能由6-32位数字和字母组成！');
    }
    if (next != confirmPassword.trim()) {
      throw AuthException('两次密码不同！');
    }

    final token = await _secure.getAuthToken();
    final csrf = await _secure.getCsrfToken();
    try {
      await _api.putJson(
        AppConstants.changePasswordPath,
        token: token,
        csrfToken: csrf,
        body: {
          'new_password': next,
          'confirm_password': confirmPassword.trim(),
        },
      );
    } on ApiException catch (error) {
      throw AuthException(
        error.message.isEmpty ? '修改失败，请稍后重试' : error.message,
      );
    } on http.ClientException {
      throw AuthException('无法连接服务器，请确认 API 服务已启动');
    } on TimeoutException {
      throw AuthException('请求超时，请稍后重试');
    }

    await logout();
  }

  Future<void> fetchCurrentUser() async {
    final token = await _secure.getAuthToken();
    final userId = await _secure.getUserId();
    if (token == null ||
        token.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      throw AuthException('服务器未返回访问令牌');
    }

    try {
      final json = await _api.getJson(
        '${AppConstants.userByIdPath}/$userId',
        token: token,
      );
      final data = json['data'];
      final user = data is Map ? data['user'] : null;
      if (user is! Map) return;
      final account = user['account']?.toString();
      final name = user['name']?.toString();
      final balance = user['balance']?.toString();
      if (account != null && account.isNotEmpty) {
        await _secure.setAccount(account);
      }
      if (name != null && name.isNotEmpty) {
        await _secure.setDisplayName(name);
      }
      await _secure.setBalance(
        balance == null || balance.isEmpty ? '0' : balance,
      );
    } on ApiException catch (error) {
      throw AuthException(
        error.message.isEmpty ? '读取账号失败' : error.message,
      );
    } on http.ClientException {
      throw AuthException('无法连接服务器，请确认 API 服务已启动');
    } on TimeoutException {
      throw AuthException('请求超时，请稍后重试');
    }
  }

  Future<void> logout() async {
    final token = await _secure.getAuthToken();
    final userId = await _secure.getUserId();
    if (userId != null && userId.isNotEmpty) {
      final parsedId = int.tryParse(userId);
      try {
        await _api.postJson(
          AppConstants.logoutPath,
          token: token,
          body: {'userId': parsedId ?? userId},
        );
      } catch (_) {}
    }
    try {
      await _secure.clearSession();
    } catch (_) {}
  }

  bool _isOldUser(Object? value) {
    if (value == false || value == 0 || value == '0' || value == 'false') {
      return false;
    }
    return true;
  }

  String _equipmentLabel() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      _ => 'Flutter',
    };
  }
}
