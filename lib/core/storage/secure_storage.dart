import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(ref.watch(flutterSecureStorageProvider));
});

/// Token and session credentials in secure storage.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> getAuthToken() =>
      _storage.read(key: AppConstants.keyAuthToken);

  Future<void> setAuthToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: AppConstants.keyAuthToken);
    } else {
      await _storage.write(key: AppConstants.keyAuthToken, value: token);
    }
  }

  Future<String?> getUserId() => _storage.read(key: AppConstants.keyAuthUserId);

  Future<void> setUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      await _storage.delete(key: AppConstants.keyAuthUserId);
    } else {
      await _storage.write(key: AppConstants.keyAuthUserId, value: userId);
    }
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyAuthToken),
      _storage.delete(key: AppConstants.keyAuthUserId),
    ]);
  }

  Future<bool> hasValidSession() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getRememberedPasswordFor(UiStyle style) =>
      _storage.read(key: AppConstants.keyRememberedPasswordFor(style));

  Future<void> setRememberedPasswordFor(UiStyle style, String? password) async {
    final key = AppConstants.keyRememberedPasswordFor(style);
    if (password == null || password.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: password);
    }
  }

  Future<void> clearRememberedPasswordFor(UiStyle style) async {
    await _storage.delete(key: AppConstants.keyRememberedPasswordFor(style));
  }
}
