import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newsworld/core/constants/app_constants.dart';
import 'package:newsworld/core/network/api_client.dart';
import 'package:newsworld/core/storage/local_storage.dart';
import 'package:newsworld/core/storage/secure_storage.dart';
import 'package:newsworld/features/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorage localStorage;
  late SecureStorage secureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    localStorage = LocalStorage(prefs);
    secureStorage = SecureStorage(const FlutterSecureStorage());
  });

  AuthService buildService() {
    return AuthService(
      apiClient: ApiClient(
        client: MockClient((_) async => http.Response('nope', 500)),
        baseUrl: 'https://example.test',
      ),
      secureStorage: secureStorage,
      localStorage: localStorage,
    );
  }

  test('user1 and user2 remember credentials separately by UI style', () async {
    final auth = buildService();

    await auth.login(
      username: 'user1',
      password: '123456',
      rememberMe: true,
    );
    await auth.login(
      username: 'user2',
      password: '123456',
      rememberMe: true,
    );

    final u1 = await auth.loadRememberedCredentials(UiStyle.u1);
    final u2 = await auth.loadRememberedCredentials(UiStyle.u2);

    expect(u1.remember, isTrue);
    expect(u1.username, 'user1');
    expect(u1.password, '123456');

    expect(u2.remember, isTrue);
    expect(u2.username, 'user2');
    expect(u2.password, '123456');
  });

  test('unchecking remember clears only that UI style', () async {
    final auth = buildService();

    await auth.login(
      username: 'user1',
      password: '123456',
      rememberMe: true,
    );
    await auth.login(
      username: 'user2',
      password: '123456',
      rememberMe: true,
    );
    await auth.login(
      username: 'user1',
      password: '123456',
      rememberMe: false,
    );

    final u1 = await auth.loadRememberedCredentials(UiStyle.u1);
    final u2 = await auth.loadRememberedCredentials(UiStyle.u2);

    expect(u1.remember, isFalse);
    expect(u1.username, isNull);
    expect(u1.password, isNull);

    expect(u2.remember, isTrue);
    expect(u2.username, 'user2');
    expect(u2.password, '123456');
  });
}
