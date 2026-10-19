import 'dart:convert';

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

  AuthService buildService(http.Client client) {
    return AuthService(
      apiClient: ApiClient(client: client, baseUrl: 'https://example.test'),
      secureStorage: secureStorage,
      localStorage: localStorage,
    );
  }

  test('successful login stores token and returns result', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/auth/login');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['username'], 'alice');
      return http.Response(
        jsonEncode({'token': 'tok-123', 'userId': 'u1'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await buildService(client).login(
      username: 'alice',
      password: 'secret',
      rememberMe: true,
    );

    expect(result.token, 'tok-123');
    expect(await secureStorage.getAuthToken(), 'tok-123');
    expect(localStorage.getRememberedUsernameFor(UiStyle.u1), 'alice');
    expect(await secureStorage.getRememberedPasswordFor(UiStyle.u1), 'secret');
  });

  test('failed login shows Chinese error and does not store token', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'Invalid credentials'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(
      () => buildService(client).login(
        username: 'alice',
        password: 'wrong',
        rememberMe: false,
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '用户名或密码错误',
        ),
      ),
    );
    expect(await secureStorage.getAuthToken(), isNull);
  });

  test('empty username validation is Chinese', () async {
    final client = MockClient((_) async => http.Response('{}', 500));
    expect(
      () => buildService(client).login(
        username: '  ',
        password: 'x',
        rememberMe: false,
      ),
      throwsA(
        isA<AuthException>().having((e) => e.message, 'message', '请输入用户名'),
      ),
    );
  });

  test('fake user1 maps to U1 classic UI', () async {
    final client = MockClient((_) async => http.Response('should not call', 500));
    final result = await buildService(client).login(
      username: 'user1',
      password: '123456',
      rememberMe: false,
    );
    expect(result.uiStyle?.id, 'U1');
    expect(localStorage.getUiStyle()?.id, 'U1');
    expect(await secureStorage.getAuthToken(), isNotNull);
  });

  test('fake user2 maps to U2 upgrade UI', () async {
    final client = MockClient((_) async => http.Response('should not call', 500));
    final result = await buildService(client).login(
      username: 'user2',
      password: '123456',
      rememberMe: false,
    );
    expect(result.uiStyle?.id, 'U2');
    expect(localStorage.getUiStyle()?.id, 'U2');
  });
}
