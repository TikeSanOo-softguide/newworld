import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/network/api_client.dart';
import '../camera_playback.dart';
import '../whep_playback.dart';

const playbackConnectingText = '正在连接直播视频…';
const playbackUnavailableText = '直播暂不可用';
const playbackFailedText = '直播连接失败';

/// One live picture. Switching cameras disposes the previous player first.
class CameraSurface extends StatefulWidget {
  const CameraSurface({
    super.key,
    required this.playback,
    required this.soundEnabled,
    required this.onStatus,
    this.whep,
  });

  final CameraPlayback playback;
  final bool soundEnabled;
  final ValueChanged<String?> onStatus;
  final MemberWhepPlayback? whep;

  @override
  State<CameraSurface> createState() => _CameraSurfaceState();
}

class _CameraSurfaceState extends State<CameraSurface>
    with WidgetsBindingObserver {
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 2);
  static const _connectTimeout = Duration(seconds: 15);

  VideoPlayerController? _video;
  WebViewController? _web;
  int _generation = 0;
  int _attempt = 0;
  bool _attemptOpen = false;
  bool _frameFailed = false;
  bool _pictureVisible = false;
  String? _reported;
  String? _sessionUrl;
  String? _sessionToken;
  Timer? _retry;
  Timer? _connectTimer;
  VigilPlaybackGrant? _grant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  @override
  void didUpdateWidget(covariant CameraSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback.identity != widget.playback.identity) {
      unawaited(_open());
      return;
    }
    if (oldWidget.soundEnabled != widget.soundEnabled) {
      if (widget.playback.kind == CameraPlaybackKind.html) {
        unawaited(_open());
      } else {
        _applySound();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_video?.pause());
      unawaited(
        _runJs(
          "document.querySelectorAll('video').forEach(function(v){v.pause();})",
        ),
      );
      return;
    }
    if (state == AppLifecycleState.resumed && _pictureVisible) {
      unawaited(_video?.play());
      unawaited(
        _runJs(
          "document.querySelectorAll('video').forEach(function(v){v.play();})",
        ),
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    _retry?.cancel();
    _connectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final video = _video;
    _video = null;
    unawaited(video?.dispose());
    _closeSession();
    _web = null;
    super.dispose();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    _retry?.cancel();
    _connectTimer?.cancel();
    _attempt = 0;
    _attemptOpen = false;
    _pictureVisible = false;
    _grant = null;
    await _dropPlayers();
    if (!mounted || generation != _generation) return;
    switch (widget.playback.kind) {
      case CameraPlaybackKind.none:
        _report(playbackUnavailableText);
      case CameraPlaybackKind.hls:
        await _openHls(generation);
      case CameraPlaybackKind.whep:
        await _openWhep(generation);
      case CameraPlaybackKind.html:
        await _openHtml(generation);
    }
  }

  Future<void> _dropPlayers() async {
    final video = _video;
    _video = null;
    _web = null;
    if (mounted) setState(() {});
    await video?.dispose();
    _closeSession();
  }

  void _closeSession() {
    final url = _sessionUrl;
    final token = _sessionToken;
    final whep = widget.whep;
    _sessionUrl = null;
    _sessionToken = null;
    if (url == null || token == null || whep == null) return;
    unawaited(whep.closeSession(sessionUrl: Uri.parse(url), token: token));
  }

  Future<void> _openHls(int generation) async {
    final uri = widget.playback.uri;
    if (uri == null) {
      _report(playbackUnavailableText);
      return;
    }
    _beginAttempt(generation, _openHls);
    final previous = _video;
    _video = null;
    await previous?.dispose();
    if (!mounted || generation != _generation) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted ||
          generation != _generation ||
          !identical(_video, controller)) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(widget.soundEnabled ? 1 : 0);
      await controller.play();
      controller.addListener(() => _onHlsTick(generation, controller));
      _markPlaying(generation);
      if (mounted) setState(() {});
    } catch (_) {
      if (identical(_video, controller)) _video = null;
      await controller.dispose();
      _failAttempt(generation, _openHls);
    }
  }

  void _onHlsTick(int generation, VideoPlayerController controller) {
    if (generation != _generation || !identical(_video, controller)) return;
    if (!controller.value.hasError) return;
    _failAttempt(generation, _openHls);
  }

  Future<void> _openWhep(int generation) async {
    final camera = widget.playback.vigilCamera;
    final whep = widget.whep;
    if (camera == null || whep == null) {
      _report(playbackUnavailableText);
      return;
    }
    _beginAttempt(generation, _openWhep);
    try {
      final grant = await whep.grant(camera);
      if (!mounted || generation != _generation) return;
      _grant = grant;
      final web = _webController(generation, whep: true);
      _web = web;
      if (mounted) setState(() {});
      await web.loadFlutterAsset('assets/whep_player.html');
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 429) {
        _attemptOpen = false;
        _connectTimer?.cancel();
        _report(error.message);
        return;
      }
      _failAttempt(generation, _openWhep);
    } catch (_) {
      _failAttempt(generation, _openWhep);
    }
  }

  Future<void> _openHtml(int generation) async {
    final page = widget.playback.uri;
    if (page == null) {
      _report(playbackUnavailableText);
      return;
    }
    _beginAttempt(generation, _openHtml);
    final web = _webController(generation, whep: false);
    _web = web;
    if (mounted) setState(() {});
    try {
      await web.loadRequest(
        htmlPlaybackUri(page, audible: widget.soundEnabled),
      );
    } catch (_) {
      _failAttempt(generation, _openHtml);
    }
  }

  WebViewController _webController(int generation, {required bool whep}) {
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!identical(_web, controller) || _frameFailed) return;
            if (whep) {
              unawaited(_runJs('startOffer()'));
              return;
            }
            _markPlaying(generation);
          },
          onWebResourceError: (error) {
            if (!identical(_web, controller)) return;
            if (error.isForMainFrame == false) return;
            _frameFailed = true;
            _failAttempt(generation, whep ? _openWhep : _openHtml);
          },
          onNavigationRequest: (request) {
            if (whep) return NavigationDecision.navigate;
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'about') return NavigationDecision.navigate;
            return NavigationDecision.prevent;
          },
        ),
      );
    if (whep) {
      controller.addJavaScriptChannel(
        'WhepBridge',
        onMessageReceived: (message) {
          if (!identical(_web, controller)) return;
          unawaited(_onWhepMessage(generation, message.message));
        },
      );
    }
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    return controller;
  }

  Future<void> _onWhepMessage(int generation, String raw) async {
    if (generation != _generation || !mounted) return;
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      message = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    switch (message['type']) {
      case 'playing':
        _markPlaying(generation);
        _applySound();
      case 'failed':
        _failAttempt(generation, _openWhep);
      case 'offer':
        final sdp = message['sdp']?.toString() ?? '';
        final grant = _grant;
        final whep = widget.whep;
        if (sdp.isEmpty || grant == null || whep == null) {
          _failAttempt(generation, _openWhep);
          return;
        }
        try {
          final answer = await whep.postOffer(grant: grant, sdp: sdp);
          if (generation != _generation) {
            final session = answer.sessionUrl;
            if (session != null) {
              unawaited(
                whep.closeSession(sessionUrl: session, token: grant.token),
              );
            }
            return;
          }
          _sessionUrl = answer.sessionUrl?.toString();
          _sessionToken = grant.token;
          final payload = jsonEncode(answer.sdp);
          await _runJs('applyAnswer($payload)');
        } catch (_) {
          _failAttempt(generation, _openWhep);
        }
    }
  }

  void _beginAttempt(
    int generation,
    Future<void> Function(int generation) again,
  ) {
    _attemptOpen = true;
    _frameFailed = false;
    _report(playbackConnectingText);
    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () {
      _failAttempt(generation, again);
    });
  }

  void _failAttempt(
    int generation,
    Future<void> Function(int generation) again,
  ) {
    if (generation != _generation || !_attemptOpen) return;
    _attemptOpen = false;
    _frameFailed = true;
    _connectTimer?.cancel();
    if (_attempt >= _maxRetries) {
      _web = null;
      _pictureVisible = false;
      if (mounted) setState(() {});
      _report(playbackFailedText);
      return;
    }
    _attempt += 1;
    _report(playbackConnectingText);
    _retry?.cancel();
    _retry = Timer(_retryDelay, () {
      if (generation == _generation) unawaited(again(generation));
    });
  }

  void _markPlaying(int generation) {
    if (generation != _generation || _frameFailed) return;
    _attemptOpen = false;
    _connectTimer?.cancel();
    _attempt = 0;
    _pictureVisible = true;
    _report(null);
    if (mounted) setState(() {});
  }

  void _applySound() {
    final video = _video;
    if (video != null) {
      unawaited(video.setVolume(widget.soundEnabled ? 1 : 0));
    }
    unawaited(_runJs('setMuted(${widget.soundEnabled ? 'false' : 'true'})'));
  }

  Future<void> _runJs(String source) async {
    final web = _web;
    if (web == null) return;
    try {
      await web.runJavaScript(source);
    } catch (_) {
      // The page can be disposed while a camera switch is in flight.
    }
  }

  void _report(String? line) {
    if (_reported == line) return;
    _reported = line;
    final building =
        WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (building) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _reported != line) return;
        widget.onStatus(line);
      });
      return;
    }
    widget.onStatus(line);
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final ready = video?.value.isInitialized == true;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: video!.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          ),
        if (_web != null)
          Opacity(
            opacity: _pictureVisible ? 1 : 0,
            child: WebViewWidget(
              key: ValueKey('camera-web-$_generation'),
              controller: _web!,
            ),
          ),
      ],
    );
  }
}
