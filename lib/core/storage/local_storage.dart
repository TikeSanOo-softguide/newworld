import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
});

/// SharedPreferences wrapper for the login remember-account flag.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  bool getRememberMe() => _prefs.getBool(AppConstants.keyRememberMe) ?? false;

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(AppConstants.keyRememberMe, value);
  }

  String? getRememberedAccount() =>
      _prefs.getString(AppConstants.keyRememberedAccount);

  Future<void> setRememberedAccount(String? account) async {
    if (account == null || account.isEmpty) {
      await _prefs.remove(AppConstants.keyRememberedAccount);
    } else {
      await _prefs.setString(AppConstants.keyRememberedAccount, account);
    }
  }
}
