import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets.dart';
import '../../../../theme/tokens.dart';

/// The big round start button: a stopwatch face with a sweeping hand.
class StartDial extends StatefulWidget {
  const StartDial({super.key, required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  /// Space the dial needs including its press travel and shadow.
  static double footprint(double size) => size + 13;

  @override
  State<StartDial> createState() => _StartDialState();
}

class _StartDialState extends State<StartDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final double s = widget.size;
    final double box = StartDial.footprint(s);
    return SizedBox(
      width: box,
      height: box,
      child: Semantics(
        button: true,
        label: 'Start a 60 second sprint',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onPressed,
          child: Align(
            alignment: _down ? Alignment.bottomRight : Alignment.topLeft,
            child: HardBox(
              shape: BoxShape.circle,
              borderWidth: 3,
              shadow: _down ? const Offset(1, 1) : const Offset(6, 7),
              child: SizedBox(
                width: s,
                height: s,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Only the sweeping hand repaints each frame; the label
                    // below is built once and passed through `child`.
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _sweep,
                          builder: (BuildContext context, Widget? _) =>
                              CustomPaint(
                            painter: _DialPainter(
                              tick: t.edge,
                              hand: t.pen,
                              turns: _sweep.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('60',
                            style: t.display(s * 0.3, spacing: -s * 0.015)),
                        const SizedBox(height: 6),
                        Text(
                          'START SPRINT',
                          style: t.mono(11, color: t.pen, spacing: 1.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.tick, required this.hand, required this.turns});

  final Color tick;
  final Color hand;
  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 200;
    final Offset c = size.center(Offset.zero);
    final Paint minor = Paint()
      ..color = tick
      ..strokeWidth = 1.4 * k;
    final Paint major = Paint()
      ..color = tick
      ..strokeWidth = 3 * k;
    for (int i = 0; i < 60; i++) {
      final double a = i * math.pi / 30;
      final bool big = i % 5 == 0;
      final double r2 = big ? 80 : 87;
      final Offset dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * (94 * k), c + dir * (r2 * k), big ? major : minor);
    }
    final double a = turns * 2 * math.pi;
    final Offset dir = Offset(math.sin(a), -math.cos(a));
    canvas.drawLine(
      c + dir * (64 * k),
      c + dir * (92 * k),
      Paint()
        ..color = hand
        ..strokeWidth = 4 * k
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.turns != turns || old.tick != tick || old.hand != hand;
}
