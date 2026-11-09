import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:newsworld/core/network/api_client.dart';

void main() {
  test('sends bearer and CSRF tokens in request headers', () async {
    final client = _CapturingClient();
    final api = ApiClient(client: client, baseUrl: 'https://api.example.test');

    await api.postJson(
      '/user/bet',
      body: const {'amount': 50},
      token: 'member-jwt',
      csrfToken: 'csrf-token',
    );

    expect(client.request?.headers['authorization'], 'Bearer member-jwt');
    expect(client.request?.headers['x-csrf-token'], 'csrf-token');
  });
}

class _CapturingClient extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream<List<int>>.value('{}'.codeUnits),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
