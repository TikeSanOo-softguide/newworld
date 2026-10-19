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

/// Lightweight JSON HTTP client for the NEWSWORLD API.
class ApiClient {
  ApiClient({
    required this.client,
    required this.baseUrl,
  });

  final http.Client client;
  final String baseUrl;

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await client.post(
      _uri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      final dynamic raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      } else {
        decoded = {'data': raw};
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          '请求失败（${response.statusCode}）';
      throw ApiException(statusCode: response.statusCode, message: message);
    }

    return decoded;
  }
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
