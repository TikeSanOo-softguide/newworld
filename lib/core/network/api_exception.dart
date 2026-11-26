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
