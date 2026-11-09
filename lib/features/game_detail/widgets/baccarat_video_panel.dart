import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../lobby/widgets/lobby_dashboard_widgets.dart';

class BaccaratVideoPanel extends StatefulWidget {
  const BaccaratVideoPanel({
    super.key,
    required this.deskName,
    this.roundLabel,
    required this.status,
    required this.remainingSeconds,
    this.ticker,
    required this.streamUri,
    required this.cameraLabel,
    required this.cameraCount,
    required this.onBack,
    required this.onSwitchTable,
    required this.onSwitchCamera,
    required this.soundEnabled,
    required this.onSoundChanged,
  });

  final String deskName;
  final String? roundLabel;
  final String status;
  final int remainingSeconds;
  final String? ticker;
  final Uri? streamUri;
  final String cameraLabel;
  final int cameraCount;
  final VoidCallback onBack;
  final VoidCallback onSwitchTable;
  final VoidCallback onSwitchCamera;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;

  @override
  State<BaccaratVideoPanel> createState() => _BaccaratVideoPanelState();
}

class _BaccaratVideoPanelState extends State<BaccaratVideoPanel> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant BaccaratVideoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUri != widget.streamUri) {
      final oldController = _controller;
      _controller = null;
      unawaited(oldController?.dispose());
      _error = null;
      _initialize();
    } else if (oldWidget.soundEnabled != widget.soundEnabled) {
      unawaited(
        _controller?.setVolume(widget.soundEnabled ? 1 : 0) ??
            Future<void>.value(),
      );
    }
  }

  Future<void> _initialize() async {
    final uri = widget.streamUri;
    if (uri == null) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.soundEnabled ? 1 : 0);
      await controller.play();
      if (mounted && identical(_controller, controller)) setState(() {});
    } catch (error) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF07131F)),
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.streamUri == null
                            ? Icons.videocam_off_outlined
                            : _error == null
                            ? Icons.hourglass_top
                            : Icons.signal_wifi_connected_no_internet_4,
                        color: const Color(0xFF9AB3C8),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.streamUri == null
                            ? '此桌暂时没有可播放的 HLS 视频源'
                            : _error ?? '正在连接直播视频…',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD8E1EA),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 10,
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _VideoIconButton(
                    icon: Icons.arrow_back,
                    label: '返回',
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB9000A14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.deskName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.roundLabel?.isNotEmpty == true)
                            Text(
                              widget.roundLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD1DCE5),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _VideoIconButton(
                    icon: Icons.swap_horiz,
                    label: '切换台桌',
                    onPressed: widget.onSwitchTable,
                  ),
                ],
              ),
            ),
            if (widget.ticker?.trim().isNotEmpty == true)
              Positioned(
                top: 62,
                left: 0,
                right: 0,
                child: LobbyAnnouncementBanner(text: widget.ticker),
              ),
            Positioned(
              right: 10,
              top: 128,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB9000A14),
                  border: Border.all(
                    color: widget.status == 'betting'
                        ? const Color(0xFF52D475)
                        : const Color(0xFFE34242),
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 78,
                  height: 48,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _statusText,
                          style: TextStyle(
                            color: widget.status == 'betting'
                                ? const Color(0xFF8CFFA7)
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  if (widget.cameraCount > 1)
                    _VideoIconButton(
                      icon: Icons.cameraswitch_outlined,
                      label: widget.cameraLabel,
                      onPressed: widget.onSwitchCamera,
                    ),
                  const SizedBox(width: 8),
                  _VideoIconButton(
                    icon: widget.soundEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    label: '声音',
                    onPressed: () =>
                        widget.onSoundChanged(!widget.soundEnabled),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    if (widget.status == 'betting') {
      return '下注中${widget.remainingSeconds > 0 ? ' ${widget.remainingSeconds}s' : ''}';
    }
    if (widget.status == 'dealing') return '停止下注';
    if (widget.status == 'finished') return '本局已结束';
    return '等待开局';
  }
}

class _VideoIconButton extends StatelessWidget {
  const _VideoIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: const Color(0xB9000A14),
        borderRadius: BorderRadius.circular(24),
        child: IconButton(
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}
