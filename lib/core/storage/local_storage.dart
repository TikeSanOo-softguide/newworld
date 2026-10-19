import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
});

/// Thin SharedPreferences wrapper for UI style and remember-me prefs.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  UiStyle? getUiStyle() => UiStyle.fromId(_prefs.getString(AppConstants.keyUiStyle));

  Future<void> setUiStyle(UiStyle style) async {
    await _prefs.setString(AppConstants.keyUiStyle, style.id);
  }

  bool getRememberMeFor(UiStyle style) =>
      _prefs.getBool(AppConstants.keyRememberMeFor(style)) ?? false;

  Future<void> setRememberMeFor(UiStyle style, bool value) async {
    await _prefs.setBool(AppConstants.keyRememberMeFor(style), value);
  }

  String? getRememberedUsernameFor(UiStyle style) =>
      _prefs.getString(AppConstants.keyRememberedUsernameFor(style));

  Future<void> setRememberedUsernameFor(UiStyle style, String? username) async {
    final key = AppConstants.keyRememberedUsernameFor(style);
    if (username == null || username.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, username);
    }
  }

  /// Legacy global helpers (kept for older tests / migration).
  bool getRememberMe() => _prefs.getBool(AppConstants.keyRememberMe) ?? false;

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(AppConstants.keyRememberMe, value);
  }

  String? getRememberedUsername() =>
      _prefs.getString(AppConstants.keyRememberedUsername);

  Future<void> setRememberedUsername(String? username) async {
    if (username == null || username.isEmpty) {
      await _prefs.remove(AppConstants.keyRememberedUsername);
    } else {
      await _prefs.setString(AppConstants.keyRememberedUsername, username);
    }
  }
}
