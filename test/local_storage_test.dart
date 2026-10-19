import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newsworld/core/constants/app_constants.dart';
import 'package:newsworld/core/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists and restores UI style', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorage(prefs);

    expect(storage.getUiStyle(), isNull);

    await storage.setUiStyle(UiStyle.u1);
    expect(storage.getUiStyle(), UiStyle.u1);
    expect(prefs.getString(AppConstants.keyUiStyle), 'U1');

    await storage.setUiStyle(UiStyle.u2);
    expect(storage.getUiStyle(), UiStyle.u2);
  });
}
