import 'baccarat_detail_models.dart';

Uri? proxyHlsCameraUri({
  required String apiBaseUrl,
  required BaccaratCameraFeed camera,
}) {
  final upstream = Uri.tryParse(camera.url);
  if (upstream == null ||
      (upstream.scheme != 'http' && upstream.scheme != 'https')) {
    return null;
  }

  if (!upstream.path.contains('/hls/')) {
    return upstream.scheme == 'https' &&
            upstream.userInfo.isEmpty &&
            upstream.path.toLowerCase().endsWith('.m3u8')
        ? upstream
        : null;
  }

  final authority = [
    upstream.host,
    if (upstream.hasPort) ':${upstream.port}',
  ].join();
  if (authority.isEmpty) return null;

  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  final proxyPath =
      '$base/public/user/camera-proxy/${upstream.scheme}/'
      '${Uri.encodeComponent(authority)}${upstream.path}';
  final query = Map<String, String>.from(upstream.queryParameters);
  if (upstream.path.toLowerCase().endsWith('.ts')) {
    query['transcode'] = '1';
  }
  final uri = Uri.tryParse(proxyPath);
  if (uri == null) return null;
  return uri.replace(queryParameters: query.isEmpty ? null : query);
}
