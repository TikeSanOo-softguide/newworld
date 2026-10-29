import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(ref.watch(flutterSecureStorageProvider));
});

/// Token and member session values in secure storage.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> getAuthToken() =>
      _storage.read(key: AppConstants.keyAuthToken);

  Future<void> setAuthToken(String? token) =>
      _write(AppConstants.keyAuthToken, token);

  Future<String?> getUserId() => _storage.read(key: AppConstants.keyAuthUserId);

  Future<void> setUserId(String? userId) =>
      _write(AppConstants.keyAuthUserId, userId);

  Future<String?> getCsrfToken() =>
      _storage.read(key: AppConstants.keyCsrfToken);

  Future<void> setCsrfToken(String? token) =>
      _write(AppConstants.keyCsrfToken, token);

  Future<String?> getAccount() => _storage.read(key: AppConstants.keyAccount);

  Future<void> setAccount(String? account) =>
      _write(AppConstants.keyAccount, account);

  Future<String?> getDisplayName() =>
      _storage.read(key: AppConstants.keyDisplayName);

  Future<void> setDisplayName(String? name) =>
      _write(AppConstants.keyDisplayName, name);

  Future<bool> getOldUserFlag() async {
    final value = await _storage.read(key: AppConstants.keyOldUserFlg);
    return value != 'false';
  }

  Future<void> setOldUserFlag(bool value) =>
      _write(AppConstants.keyOldUserFlg, value ? 'true' : 'false');

  Future<bool> getTrialUser() async {
    final value = await _storage.read(key: AppConstants.keyTrialUser);
    return value == 'true';
  }

  Future<void> setTrialUser(bool value) =>
      _write(AppConstants.keyTrialUser, value ? 'true' : 'false');

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyAuthToken),
      _storage.delete(key: AppConstants.keyAuthUserId),
      _storage.delete(key: AppConstants.keyCsrfToken),
      _storage.delete(key: AppConstants.keyAccount),
      _storage.delete(key: AppConstants.keyDisplayName),
      _storage.delete(key: AppConstants.keyOldUserFlg),
      _storage.delete(key: AppConstants.keyTrialUser),
    ]);
  }

  Future<bool> hasValidSession() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }
}
