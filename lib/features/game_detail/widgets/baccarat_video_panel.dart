import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../camera_playback.dart';
import '../whep_playback.dart';
import 'camera_surface.dart';

class BaccaratVideoPanel extends StatefulWidget {
  const BaccaratVideoPanel({
    super.key,
    required this.deskName,
    this.roundLabel,
    required this.status,
    required this.remainingSeconds,
    this.countdownSeconds = 0,
    this.ticker,
    this.playback = const CameraPlayback.none(),
    this.whep,
    required this.cameraLabel,
    required this.cameraCount,
    this.cameraMenuOpen = false,
    this.cameraOptions = const [],
    this.onSelectCameraOption,
    required this.onBack,
    required this.onSwitchTable,
    required this.onSwitchCamera,
    required this.soundEnabled,
    required this.onSoundChanged,
    this.onToggleLimits,
    this.limitsOpen = false,
    this.limitLines = const [],
    this.onVideoTap,
    this.landscape = false,
    this.onExitLandscape,
    this.cameraSurfaceKey,
  });

  final String deskName;
  final String? roundLabel;
  final String status;
  final int remainingSeconds;

  /// Desk betting window. The ring uses this, or the highest tick seen.
  final int countdownSeconds;
  final String? ticker;
  final CameraPlayback playback;
  final MemberWhepPlayback? whep;
  final String cameraLabel;
  final int cameraCount;
  final bool cameraMenuOpen;
  final List<String> cameraOptions;
  final ValueChanged<String>? onSelectCameraOption;
  final VoidCallback onBack;
  final VoidCallback onSwitchTable;
  final VoidCallback onSwitchCamera;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback? onToggleLimits;
  final bool limitsOpen;
  final List<String> limitLines;

  /// Set only while the existing portrait 全屏 mode is showing.
  final VoidCallback? onVideoTap;

  /// Device landscape. The same [CameraSurface] key keeps the player.
  final bool landscape;
  final VoidCallback? onExitLandscape;
  final Key? cameraSurfaceKey;

  @override
  State<BaccaratVideoPanel> createState() => _BaccaratVideoPanelState();
}

class _BaccaratVideoPanelState extends State<BaccaratVideoPanel> {
  String? _playbackStatus;
  int _countdownWindow = 0;

  static const TextStyle _headerStyle = TextStyle(
    // match the reference screenshot: white text, 12‑sp, medium weight
    color: Colors.white,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  @override
  void initState() {
    super.initState();
    _trackCountdown();
  }

  @override
  void didUpdateWidget(covariant BaccaratVideoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _trackCountdown();
  }

  void _trackCountdown() {
    final counting = widget.status == 'betting' && widget.remainingSeconds > 0;
    if (!counting) {
      _countdownWindow = 0;
      return;
    }
    if (widget.remainingSeconds > _countdownWindow) {
      _countdownWindow = widget.remainingSeconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.landscape) return _landscapeVideo(context);
    final statusLine = _playbackStatus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 390.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : width * 0.62;
        return SizedBox(
          width: constraints.maxWidth.isFinite ? width : null,
          height: height,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _videoPicture(),
                if (statusLine != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 72),
                      child: Text(
                        statusLine,
                        key: const ValueKey('video-playback-status'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB7C3CE),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if (widget.onVideoTap != null)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('video-landscape-tap'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onVideoTap,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: MediaQuery.of(context).padding.top,
                  height: 27,
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        // Fixed desk name
                        Text(
                          widget.deskName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Fixed round label (may be null/empty)
                        if (widget.roundLabel != null &&
                            widget.roundLabel!.trim().isNotEmpty)
                          Text(
                            widget.roundLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        if (widget.roundLabel != null &&
                            widget.roundLabel!.trim().isNotEmpty)
                          const SizedBox(width: 8),
                        // Scrolling ticker
                        Expanded(
                          child: IgnorePointer(
                            ignoring: true,
                            child: _AnnouncementMarquee(text: widget.ticker),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: MediaQuery.of(context).padding.top + 22 + 4,
                  child: _LimitButton(onPressed: widget.onToggleLimits),
                ),
                if (widget.cameraMenuOpen && widget.cameraOptions.isNotEmpty)
                  Positioned(
                    left: 4,
                    right: 52,
                    top: (height * 0.29 - 14.0)
                        .clamp(18.0, math.max(18.0, height - 30.0))
                        .toDouble(),
                    height: 28.0,
                    child: _CameraOptionRow(
                      options: widget.cameraOptions,
                      onSelected: widget.onSelectCameraOption,
                    ),
                  ),
                if (widget.limitsOpen)
                  Positioned(
                    left: 8,
                    top: 64,
                    child: _LimitList(lines: widget.limitLines),
                  ),
                Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  width: 50,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _railAt(
                        height,
                        0.17,
                        32,
                        _RailTap(
                          label: '返回',
                          onPressed: widget.onBack,
                          child: const SizedBox(
                            width: 34,
                            height: 30,
                            child: CustomPaint(painter: _ReturnArrowPainter()),
                          ),
                        ),
                      ),
                      _railAt(
                        height,
                        0.29,
                        28,
                        _CameraSwapButton(
                          label: widget.cameraCount > 1
                              ? widget.cameraLabel
                              : '切换画面',
                          onPressed: widget.onSwitchCamera,
                        ),
                      ),
                      _railAt(
                        height,
                        0.45,
                        38,
                        _StatusOrb(
                          label: _statusText,
                          countdown: _greenNumber,
                          progress: _ringProgress,
                        ),
                      ),
                      _railAt(
                        height,
                        0.60,
                        34,
                        _RailTap(
                          label: '声音',
                          onPressed: () =>
                              widget.onSoundChanged(!widget.soundEnabled),
                          child: SizedBox(
                            width: 36,
                            height: 32,
                            child: CustomPaint(
                              painter: _SpeakerPainter(
                                muted: !widget.soundEnabled,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _railAt(
                        height,
                        0.75,
                        44,
                        _TableSwitchButton(onPressed: widget.onSwitchTable),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Existing method signature follows

  bool get _greenNumber =>
      widget.status == 'betting' && widget.remainingSeconds > 0;

  double get _ringProgress {
    if (!_greenNumber) return 0;
    final total = math.max(
      widget.countdownSeconds,
      math.max(_countdownWindow, widget.remainingSeconds),
    );
    if (total <= 0) return 0;
    return (widget.remainingSeconds / total).clamp(0.0, 1.0);
  }

  String get _statusText {
    if (widget.status == 'betting') return '${widget.remainingSeconds}';
    if (widget.status == 'dealing') return '停止';
    if (widget.status == 'finished' ||
        widget.status == 'active' ||
        widget.status.isEmpty) {
      return '等待';
    }
    return widget.status;
  }

  Widget _videoPicture() {
    return CameraSurface(
      key: widget.cameraSurfaceKey,
      playback: widget.playback,
      whep: widget.whep,
      soundEnabled: widget.soundEnabled,
      onStatus: (line) {
        if (!mounted || _playbackStatus == line) return;
        setState(() => _playbackStatus = line);
      },
    );
  }

  /// Landscape shows the current picture and a way back to portrait 全屏.
  Widget _landscapeVideo(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _videoPicture(),
          Positioned(
            top: padding.top + 8,
            left: padding.left + 8,
            child: _RailTap(
              label: '退出全屏',
              onPressed: widget.onExitLandscape ?? () {},
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xCC000000),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: SizedBox(
                  key: ValueKey('exit-landscape-video'),
                  width: 44,
                  height: 36,
                  child: CustomPaint(painter: _ReturnArrowPainter()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Places one rail control at [center] of the video height.
Widget _railAt(double videoHeight, double center, double slot, Widget child) {
  final top = (videoHeight * center - slot / 2)
      .clamp(18.0, math.max(18.0, videoHeight - slot - 2))
      .toDouble();
  return Positioned(
    top: top,
    left: 0,
    right: 0,
    height: slot,
    child: Center(child: child),
  );
}

class _AnnouncementMarquee extends StatefulWidget {
  const _AnnouncementMarquee({required this.text});

  final String? text;

  @override
  State<_AnnouncementMarquee> createState() => _AnnouncementMarqueeState();
}

class _AnnouncementMarqueeState extends State<_AnnouncementMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Member site marquee: `max(10, length * 0.2 + 5)` seconds.
  static Duration _durationFor(String? text) {
    final length = text?.trim().length ?? 0;
    final seconds = math.max(10.0, length * 0.2 + 5);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.text),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AnnouncementMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    final duration = _durationFor(widget.text);
    if (_controller.duration != duration) {
      _controller.duration = duration;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _BaccaratVideoPanelState._headerStyle;
    final message = widget.text?.trim() ?? '';
    if (message.isEmpty) return const SizedBox.expand();
    final painter = TextPainter(
      text: TextSpan(text: message, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final textWidth = painter.width + 4;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final start = viewport;
              final end = -textWidth;
              return Transform.translate(
                offset: Offset(start + (end - start) * _controller.value, 0),
                child: child,
              );
            },
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Text(message, maxLines: 1, style: style),
            ),
          );
        },
      ),
    );
  }
}

class _LimitButton extends StatelessWidget {
  const _LimitButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3BE83),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '限红',
            style: TextStyle(
              color: Color(0xFF3E2A12),
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitList extends StatelessWidget {
  const _LimitList({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final rows = lines.isEmpty ? const ['限红以服务器设置为准'] : lines;
    return Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xCC101418),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in rows)
            Text(
              line,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _StatusOrb extends StatelessWidget {
  const _StatusOrb({
    required this.label,
    required this.countdown,
    required this.progress,
  });

  final String label;
  final bool countdown;
  final double progress;

  static const _green = Color(0xFF3DDC6A);
  static const _red = Color(0xFFE34242);

  @override
  Widget build(BuildContext context) {
    final number = int.tryParse(label) != null;
    return SizedBox(
      key: ValueKey(countdown ? 'video-countdown' : 'video-status'),
      width: 38,
      height: 38,
      child: CustomPaint(
        painter: countdown
            ? _CountdownArcPainter(progress: progress, color: _green)
            : const _StatusRingPainter(color: _red),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: number ? 16 : (label.length > 2 ? 11 : 13),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownArcPainter extends CustomPainter {
  const _CountdownArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.5;
    final rect = Offset.zero & size;
    final sweep = -2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep == 0) return;
    canvas.drawArc(
      rect.deflate(stroke),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _StatusRingPainter extends CustomPainter {
  const _StatusRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.5;
    final rect = (Offset.zero & size).deflate(stroke);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _StatusRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TableSwitchButton extends StatelessWidget {
  const _TableSwitchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RailTap(
      label: '切换台桌',
      onPressed: onPressed,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: CustomPaint(
          painter: _CycleArrowPainter(),
          child: Center(
            child: Text(
              '切换\n台桌',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1.05,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraOptionRow extends StatelessWidget {
  const _CameraOptionRow({required this.options, required this.onSelected});

  final List<String> options;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = options.length;
        if (count == 0) return const SizedBox.shrink();

        const gap = 5.0;
        final totalGaps = gap * (count - 1);
        final available = constraints.maxWidth - totalGaps;
        final maxBtnWidth = count <= 4 ? 64.0 : 58.0;
        final btnWidth = (available / count).clamp(40.0, maxBtnWidth);

        return Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _CameraOptionButton(
                  label: options[i],
                  width: btnWidth,
                  onPressed: onSelected == null
                      ? null
                      : () => onSelected!(options[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CameraOptionButton extends StatelessWidget {
  const _CameraOptionButton({
    required this.label,
    required this.width,
    required this.onPressed,
  });

  final String label;
  final double width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 28.0,
      child: Material(
        color: const Color(0xA68FCB6A),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.0,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraSwapButton extends StatelessWidget {
  const _CameraSwapButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RailTap(
      label: label,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(
          width: 42,
          height: 26,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: Size(30, 8),
                painter: _FlatArrowPainter(pointsRight: true),
              ),
              SizedBox(height: 3),
              CustomPaint(
                size: Size(30, 8),
                painter: _FlatArrowPainter(pointsRight: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailTap extends StatelessWidget {
  const _RailTap({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(onTap: onPressed, child: child),
    );
  }
}

class _ReturnArrowPainter extends CustomPainter {
  const _ReturnArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(w, h) * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, h * 0.24)
        ..lineTo(w * 0.68, h * 0.24)
        ..quadraticBezierTo(w * 0.90, h * 0.24, w * 0.90, h * 0.46)
        ..lineTo(w * 0.90, h * 0.56)
        ..quadraticBezierTo(w * 0.90, h * 0.78, w * 0.66, h * 0.78)
        ..lineTo(w * 0.18, h * 0.78),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.08, h * 0.24)
        ..lineTo(w * 0.42, h * 0.04)
        ..lineTo(w * 0.42, h * 0.44)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlatArrowPainter extends CustomPainter {
  const _FlatArrowPainter({required this.pointsRight});

  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final y = size.height / 2;
    final head = size.height * 0.95;
    final thick = size.height * 0.38;
    if (pointsRight) {
      canvas.drawRect(
        Rect.fromLTWH(0, y - thick / 2, size.width - head, thick),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width - head, y - head * 0.72)
          ..lineTo(size.width, y)
          ..lineTo(size.width - head, y + head * 0.72)
          ..close(),
        paint,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(head, y - thick / 2, size.width - head, thick),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(head, y - head * 0.72)
          ..lineTo(0, y)
          ..lineTo(head, y + head * 0.72)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlatArrowPainter oldDelegate) {
    return oldDelegate.pointsRight != pointsRight;
  }
}

class _CycleArrowPainter extends CustomPainter {
  const _CycleArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2.4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweep = 2.35;
    canvas.drawArc(rect, -2.55, sweep, false, paint);
    canvas.drawArc(rect, 0.59, sweep, false, paint);
    _head(canvas, center, radius, -2.55 + sweep, clockwise: true);
    _head(canvas, center, radius, 0.59 + sweep, clockwise: true);
  }

  void _head(
    Canvas canvas,
    Offset center,
    double radius,
    double angle, {
    required bool clockwise,
  }) {
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final tangent = clockwise ? angle + math.pi / 2 : angle - math.pi / 2;
    const length = 7.0;
    final base = tip - Offset(math.cos(tangent), math.sin(tangent)) * length;
    final normal = Offset(-math.sin(tangent), math.cos(tangent)) * 3.6;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + normal.dx, base.dy + normal.dy)
        ..lineTo(base.dx - normal.dx, base.dy - normal.dy)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeakerPainter extends CustomPainter {
  const _SpeakerPainter({required this.muted});

  final bool muted;

  static const _orange = Color(0xFFFF8A2B);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _orange;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.18, h * 0.38)
        ..lineTo(w * 0.34, h * 0.38)
        ..lineTo(w * 0.52, h * 0.22)
        ..lineTo(w * 0.52, h * 0.78)
        ..lineTo(w * 0.34, h * 0.62)
        ..lineTo(w * 0.18, h * 0.62)
        ..close(),
      fill,
    );
    if (muted) {
      final x = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w * 0.60, h * 0.34),
        Offset(w * 0.86, h * 0.66),
        x,
      );
      canvas.drawLine(
        Offset(w * 0.86, h * 0.34),
        Offset(w * 0.60, h * 0.66),
        x,
      );
      return;
    }
    final wave = Paint()
      ..color = _orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final scale in [0.62, 0.82]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.50),
          width: w * scale,
          height: h * scale,
        ),
        -0.9,
        1.8,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakerPainter oldDelegate) {
    return oldDelegate.muted != muted;
  }
}
