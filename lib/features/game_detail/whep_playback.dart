import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/network/app_endpoints.dart';

/// Short-lived Vigilsyn playback grant from `GET /stream/token`.
class VigilPlaybackGrant {
  const VigilPlaybackGrant({
    required this.token,
    required this.playbackUrl,
    required this.expiresAt,
  });

  final String token;
  final Uri playbackUrl;
  final DateTime expiresAt;
}

class WhepAnswer {
  const WhepAnswer({required this.sdp, this.sessionUrl});

  final String sdp;
  final Uri? sessionUrl;
}

class WhepPlaybackException implements Exception {
  WhepPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// True when [playbackUrl] is an http(s) WHEP resource for [camera].
bool isAllowedWhepPlaybackUrl(Uri playbackUrl, String camera) {
  if (playbackUrl.scheme != 'https' && playbackUrl.scheme != 'http') {
    return false;
  }
  if (playbackUrl.userInfo.isNotEmpty) return false;
  final wanted = camera.trim().toLowerCase();
  if (wanted.isEmpty) return false;
  final path = Uri.decodeComponent(
    playbackUrl.path.replaceAll(RegExp(r'/+$'), ''),
  ).toLowerCase();
  return path.endsWith('/whep') && path.contains('/$wanted/');
}

/// Reads a WHEP answer without following a redirect.
WhepAnswer readWhepAnswer({
  required http.Response response,
  required Uri playbackUrl,
}) {
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw WhepPlaybackException('直播连接失败');
  }
  final type = (response.headers['content-type'] ?? '').toLowerCase();
  final sdp = type.contains('application/json')
      ? _sdpFromJson(response.body)
      : response.body.trim();
  if (sdp.isEmpty) throw WhepPlaybackException('直播连接失败');
  final normalized = normalizeSdp(sdp);
  final location = response.headers['location'];
  Uri? sessionUrl;
  if (location != null && location.trim().isNotEmpty) {
    sessionUrl = playbackUrl.resolve(location.trim());
  }
  return WhepAnswer(sdp: normalized, sessionUrl: sessionUrl);
}

/// Puts each media direction just after `a=mid` and ends lines with CRLF.
///
/// The tablet WebView rejects `a=sendonly` when it follows `a=ssrc`.
String normalizeSdp(String sdp) {
  final lines = sdp
      .split(RegExp(r'\r\n|\n|\r'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final sections = <List<String>>[];
  var current = <String>[];
  for (final line in lines) {
    if (line.startsWith('m=') && current.isNotEmpty) {
      sections.add(current);
      current = <String>[];
    }
    current.add(line);
  }
  if (current.isNotEmpty) sections.add(current);

  final out = <String>[];
  for (final section in sections) {
    if (section.isEmpty || !section.first.startsWith('m=')) {
      out.addAll(section.where((line) => !_isSdpDirection(line)));
      continue;
    }
    final directions = section.where(_isSdpDirection).toList();
    final body = section.where((line) => !_isSdpDirection(line)).toList();
    if (directions.isNotEmpty) {
      final mid = body.indexWhere((line) => line.startsWith('a=mid'));
      body.insertAll(mid >= 0 ? mid + 1 : 1, directions);
    }
    out.addAll(body);
  }
  return '${out.join('\r\n')}\r\n';
}

bool _isSdpDirection(String line) {
  return line == 'a=sendonly' ||
      line == 'a=recvonly' ||
      line == 'a=sendrecv' ||
      line == 'a=inactive';
}

String _sdpFromJson(String body) {
  final dynamic raw = jsonDecode(body);
  if (raw is! Map) return '';
  final nested = raw['data'];
  final candidates = [
    raw['sdp'],
    raw['answer'],
    if (nested is Map) nested['sdp'],
  ];
  for (final value in candidates) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

/// Member-authenticated WHEP session. The Vigil API key stays on the server.
class MemberWhepPlayback {
  MemberWhepPlayback({
    required this._api,
    required this.memberToken,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final String? Function() memberToken;
  final DateTime Function() _clock;
  final Map<String, VigilPlaybackGrant> _cache = {};

  Future<VigilPlaybackGrant> grant(String camera) async {
    final cached = _cache[camera];
    if (cached != null &&
        cached.expiresAt.difference(_clock()) > const Duration(seconds: 15)) {
      return cached;
    }
    final token = memberToken();
    if (token == null || token.isEmpty) {
      throw WhepPlaybackException('直播暂不可用');
    }
    final json = await _api.getJson(
      AppEndpoints.streamToken,
      query: {'camera': camera},
      token: token,
    );
    final data = json['data'];
    if (data is! Map) throw WhepPlaybackException('直播连接失败');
    final playbackToken = data['token']?.toString().trim() ?? '';
    final playbackUrl = Uri.tryParse(data['playbackUrl']?.toString() ?? '');
    if (playbackToken.isEmpty ||
        playbackUrl == null ||
        !isAllowedWhepPlaybackUrl(playbackUrl, camera)) {
      throw WhepPlaybackException('直播连接失败');
    }
    final expiresIn = data['expiresIn'];
    final seconds = expiresIn is num ? expiresIn.toInt() : 60;
    final grant = VigilPlaybackGrant(
      token: playbackToken,
      playbackUrl: playbackUrl,
      expiresAt: _clock().add(Duration(seconds: seconds)),
    );
    _cache[camera] = grant;
    return grant;
  }

  Future<WhepAnswer> postOffer({
    required VigilPlaybackGrant grant,
    required String sdp,
  }) async {
    if (!isAllowedWhepPlaybackUrl(grant.playbackUrl, _cameraFromUrl(grant))) {
      throw WhepPlaybackException('直播连接失败');
    }
    final request = http.Request('POST', grant.playbackUrl)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer ${grant.token}',
        'Content-Type': 'application/sdp',
        'Accept': 'application/sdp, application/json',
      })
      ..body = sdp;
    final streamed = await _api.client
        .send(request)
        .timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    return readWhepAnswer(response: response, playbackUrl: grant.playbackUrl);
  }

  Future<void> closeSession({
    required Uri sessionUrl,
    required String token,
  }) async {
    try {
      final request = http.Request('DELETE', sessionUrl)
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer $token';
      await _api.client.send(request).timeout(const Duration(seconds: 5));
    } catch (_) {
      // The live session expires on its own if the DELETE does not land.
    }
  }

  String _cameraFromUrl(VigilPlaybackGrant grant) {
    final path = Uri.decodeComponent(grant.playbackUrl.path);
    final match = RegExp(
      r'/([^/]+)/([^/]+)/(?:main|sub)/whep$',
      caseSensitive: false,
    ).firstMatch(path);
    if (match == null) return '';
    return '${match.group(1)}/${match.group(2)}';
  }
}
