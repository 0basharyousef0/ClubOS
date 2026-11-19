import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen celebratory confirmation: purple liquid rises to fill the
/// screen, a check draws in with the message, then the liquid drains away
/// to reveal whatever is underneath.
///
/// Inserted into the ROOT overlay, so it survives the caller navigating
/// away. Callers should navigate immediately after calling this — the
/// liquid covers the route change and drains to reveal the destination,
/// which reads as one continuous motion.
///
/// Tapping anywhere skips ahead to the drain. With the system "Reduce
/// Motion" setting on, it becomes a plain fade.
///
/// ```dart
/// showSuccessOverlay(context, title: 'Task assigned');
/// context.pop();
/// ```
Future<void> showSuccessOverlay(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.check_rounded,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  late final OverlayEntry entry;
  final done = Completer<void>();

  entry = OverlayEntry(
    builder: (_) => _SuccessOverlay(
      title: title,
      subtitle: subtitle,
      icon: icon,
      reduceMotion: reduceMotion,
      onFinished: () {
        entry.remove();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  HapticFeedback.mediumImpact();
  return done.future;
}

class _SuccessOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool reduceMotion;
  final VoidCallback onFinished;

  const _SuccessOverlay({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.reduceMotion,
    required this.onFinished,
  });

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  // Timeline as fractions of the controller (2.4s total).
  static const _fillEnd = 0.25; // liquid has filled the screen
  static const _drainStart = 0.78; // content gone, liquid starts draining

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final Animation<double> _badge = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.18, 0.42, curve: Curves.elasticOut),
  );
  late final Animation<double> _checkDraw = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.30, 0.46, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _text = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.32, 0.50, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _contentOut = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.70, _drainStart, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onFinished);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0 → 1 while filling, holds at 1, then 1 → 0 while draining.
  double get _level {
    final t = _c.value;
    if (t <= _fillEnd) {
      return Curves.easeInOutCubic.transform(t / _fillEnd);
    }
    if (t < _drainStart) return 1;
    return 1 -
        Curves.easeInCubic.transform((t - _drainStart) / (1 - _drainStart));
  }

  void _skip() {
    if (_c.value < _drainStart) _c.value = _drainStart;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // swallow taps meant for the page
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final contentOpacity = (1 - _contentOut.value).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.reduceMotion)
                Opacity(
                  opacity: _level,
                  child: const DecoratedBox(decoration: _gradient),
                )
              else
                CustomPaint(
                  painter: _LiquidPainter(
                    level: _level,
                    phase: _c.value * math.pi * 2 * 3,
                  ),
                ),
              Opacity(
                opacity: contentOpacity * (widget.reduceMotion ? _level : 1),
                child: _buildContent(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    final textT = _text.value;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: widget.reduceMotion ? 1 : _badge.value,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: widget.icon == Icons.check_rounded
                    ? CustomPaint(
                        painter: _CheckPainter(
                          progress:
                              widget.reduceMotion ? 1 : _checkDraw.value,
                        ),
                      )
                    : Icon(widget.icon, color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 28),
            Opacity(
              opacity: widget.reduceMotion ? 1 : textT,
              child: Transform.translate(
                offset: Offset(0, widget.reduceMotion ? 0 : 16 * (1 - textT)),
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _gradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFF4C1D95)],
  ),
);

/// Two offset sine-wave layers whose surface rises with [level], plus a
/// few rising bubbles. Wave amplitude fades out as the screen fills so the
/// final state is a clean full-screen gradient.
class _LiquidPainter extends CustomPainter {
  final double level;
  final double phase;

  _LiquidPainter({required this.level, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    final w = size.width;
    final h = size.height;
    // Calm at the extremes, wavy in between.
    final amp = 22 * math.sin(math.pi * level.clamp(0.0, 1.0)) + 2;
    // Lerp from below the bottom edge to above the top edge so a full
    // level leaves no gap at the top.
    final surface = (h + amp) + (-amp * 2 - (h + amp)) * level;

    Path wave(double offset, double freq) {
      final p = Path()..moveTo(0, h);
      for (double x = 0; x <= w; x += 6) {
        final y = surface +
            amp * math.sin((x / w) * freq * 2 * math.pi + phase + offset);
        p.lineTo(x, y);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    // Back layer: lighter, slightly out of phase.
    canvas.drawPath(
      wave(math.pi * 0.8, 1.3),
      Paint()..color = const Color(0xFFA78BFA).withValues(alpha: 0.55),
    );

    // Front layer: the main gradient.
    final rect = Offset.zero & size;
    canvas.drawPath(
      wave(0, 1.0),
      Paint()..shader = _gradient.gradient!.createShader(rect),
    );

    // Bubbles, only within the liquid.
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 12; i++) {
      final seed = i * 97.0;
      final bx = (seed * 13) % w;
      final travel = ((phase / (math.pi * 2)) * (0.35 + (i % 4) * 0.12) +
              (i / 12)) %
          1.0;
      final by = h - travel * (h - surface + 40);
      if (by < surface + 8) continue;
      canvas.drawCircle(Offset(bx, by), 3.0 + (i % 3) * 2.5, bubble);
    }
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.level != level || old.phase != phase;
}

/// A checkmark stroked progressively from 0 to [progress].
class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
