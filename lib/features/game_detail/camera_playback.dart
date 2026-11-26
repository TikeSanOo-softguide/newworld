import '../../core/network/app_endpoints.dart';
import 'baccarat_detail_models.dart';

/// How a stored camera address is played. The original URL is kept.
enum CameraPlaybackKind { none, hls, whep, html }

class CameraPlayback {
  const CameraPlayback.none()
    : kind = CameraPlaybackKind.none,
      uri = null,
      vigilCamera = null;

  const CameraPlayback.hls(this.uri)
    : kind = CameraPlaybackKind.hls,
      vigilCamera = null;

  const CameraPlayback.whep(this.vigilCamera)
    : kind = CameraPlaybackKind.whep,
      uri = null;

  const CameraPlayback.html(this.uri)
    : kind = CameraPlaybackKind.html,
      vigilCamera = null;

  final CameraPlaybackKind kind;
  final Uri? uri;
  final String? vigilCamera;

  String get identity => switch (kind) {
    CameraPlaybackKind.none => 'none',
    CameraPlaybackKind.hls => 'hls:$uri',
    CameraPlaybackKind.whep => 'whep:$vigilCamera',
    CameraPlaybackKind.html => 'html:$uri',
  };
}

/// Chooses a player from the stored camera URL.
///
/// WHEP is identified by the Vigil camera slug and is never sent to the HLS
/// player. An HTML page is loaded only when its origin is allowlisted.
CameraPlayback resolveCameraPlayback({
  required String apiBaseUrl,
  required BaccaratCameraFeed camera,
}) {
  final slug = vigilCameraSlug(camera.url);
  if (slug != null) return CameraPlayback.whep(slug);
  final hls = proxyHlsCameraUri(apiBaseUrl: apiBaseUrl, camera: camera);
  if (hls != null) return CameraPlayback.hls(hls);
  final page = htmlCameraPageUri(camera.url);
  if (page != null) return CameraPlayback.html(page);
  return const CameraPlayback.none();
}

/// `vigil://site/camera` and `.../site/camera/main/whep` both yield the slug.
String? vigilCameraSlug(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final scheme = RegExp(
    '^vigil:/{0,2}($_cameraSegment(?:/$_cameraSegment)?)\$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (scheme != null) return scheme.group(1);
  final parsed = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'http://$trimmed',
  );
  if (parsed == null) return null;
  final fromQuery = parsed.queryParameters['camera'];
  if (fromQuery != null && _isCameraSlug(fromQuery)) return fromQuery;
  final path = Uri.decodeComponent(parsed.path.replaceAll(RegExp(r'/+$'), ''));
  final stream = RegExp(
    '^/($_cameraSegment)/($_cameraSegment)/(?:main|sub)(?:/whep)?\$',
    caseSensitive: false,
  ).firstMatch(path);
  if (stream == null) return null;
  return '${stream.group(1)}/${stream.group(2)}';
}

/// Allowlisted https HTML camera page, without added playback query flags.
Uri? htmlCameraPageUri(String url) {
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null ||
      parsed.scheme != 'https' ||
      parsed.userInfo.isNotEmpty) {
    return null;
  }
  final path = parsed.path.toLowerCase();
  if (!path.endsWith('.html') && !path.endsWith('.htm')) return null;
  return parsed;
}

/// Same playback flags the member site appends to an iframe camera page.
Uri htmlPlaybackUri(Uri page, {required bool audible}) {
  final params = Map<String, String>.from(page.queryParameters);
  params['showinfo'] = '0';
  params['controls'] = '0';
  params['autoplay'] = '1';
  if (audible) {
    params.remove('mute');
  } else {
    params['mute'] = '1';
  }
  return page.replace(queryParameters: params);
}

const _cameraSegment = '[A-Za-z0-9][A-Za-z0-9_-]{0,63}';

bool _isCameraSlug(String value) {
  return RegExp('^$_cameraSegment(?:/$_cameraSegment)?\$').hasMatch(value);
}

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

  final proxyPath = AppEndpoints.cameraProxy(
    apiBaseUrl: apiBaseUrl,
    scheme: upstream.scheme,
    authority: authority,
    upstreamPath: upstream.path,
  );
  final query = Map<String, String>.from(upstream.queryParameters);
  if (upstream.path.toLowerCase().endsWith('.ts')) {
    query['transcode'] = '1';
  }
  final uri = Uri.tryParse(proxyPath);
  if (uri == null) return null;
  return uri.replace(queryParameters: query.isEmpty ? null : query);
}
