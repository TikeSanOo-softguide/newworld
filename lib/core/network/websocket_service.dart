import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(url: AppConstants.wsUrl);
  ref.onDispose(service.dispose);
  return service;
});

/// WebSocket infrastructure reserved for future live news feeds.
/// Not connected from home pages yet.
class WebSocketService {
  WebSocketService({required this.url});

  final String url;
  WebSocketChannel? _channel;

  bool get isConnected => _channel != null;

  void connect({String? token}) {
    if (_channel != null) return;
    final uri = Uri.parse(url).replace(
      queryParameters: {
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
    _channel = WebSocketChannel.connect(uri);
  }

  Stream<dynamic>? get messages => _channel?.stream;

  void send(Object data) {
    _channel?.sink.add(data);
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
  }
}
