import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    client: ref.watch(httpClientProvider),
    baseUrl: AppConstants.apiBaseUrl,
  );
});

/// JSON HTTP client for the member API.
class ApiClient {
  ApiClient({
    required this.client,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
  });

  final http.Client client;
  final String baseUrl;
  final Duration timeout;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({String? token, String? csrfToken}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (csrfToken != null && csrfToken.isNotEmpty)
        'X-CSRF-Token': csrfToken,
    };
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? token,
  }) {
    return _send(
      () => client.get(
        _uri(path, query),
        headers: _headers(token: token),
      ),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    String? csrfToken,
  }) {
    return _send(
      () => client.post(
        _uri(path),
        headers: _headers(token: token, csrfToken: csrfToken),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    String? csrfToken,
  }) {
    return _send(
      () => client.patch(
        _uri(path),
        headers: _headers(token: token, csrfToken: csrfToken),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    String? csrfToken,
  }) {
    return _send(
      () => client.put(
        _uri(path),
        headers: _headers(token: token, csrfToken: csrfToken),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final response = await request().timeout(timeout);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      final dynamic raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      } else if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      } else {
        decoded = {'data': raw};
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage = decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          '请求失败（${response.statusCode}）';
      final locked = decoded['lockedUntil'];
      throw ApiException(
        statusCode: response.statusCode,
        message: chineseMessage(rawMessage),
        code: decoded['error']?.toString(),
        supersededIp: decoded['supersededIp']?.toString(),
        lockedUntil: locked is num ? locked.toInt() : null,
      );
    }

    return decoded;
  }
}

/// Uses the Chinese half of a `中文|||English` API message.
String chineseMessage(String message) {
  final parts = message.split('|||');
  return parts.first.trim();
}

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.supersededIp,
    this.lockedUntil,
  });

  final int statusCode;
  final String message;
  final String? code;
  final String? supersededIp;
  final int? lockedUntil;

  @override
  String toString() => message;
}
