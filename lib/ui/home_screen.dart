import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/round_controller.dart';
import '../logic/scoring.dart';
import '../state/progress.dart';
import '../theme/tokens.dart';
import 'play_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _play(BuildContext context, RoundMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final AppState app = AppScope.of(context);
    final Progress p = app.progress;
    final int tierIndex = tierIndexFor(p.rating);
    final Tier tier = tiers[tierIndex];
    final bool top = tierIndex + 1 >= tiers.length;
    final String toNext = top
        ? 'Top tier'
        : '${tiers[tierIndex + 1].minRating - p.rating} to ${tiers[tierIndex + 1].name}';
    final int? dailyBest = app.dailyBestToday;

    return PaperScaffold(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double dial =
              math.max(170.0, math.min(250.0, math.min(box.maxWidth * 0.62, box.maxHeight * 0.32)));
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: 'Sixty', style: t.display(24)),
                        TextSpan(
                          text: 'Math',
                          style: t.display(24, color: t.pen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SizedBox(
                      width: dial + 12,
                      height: dial + 13,
                      child: _StartDial(
                        size: dial,
                        onPressed: () => _play(context, RoundMode.sprint),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('RATING', style: t.label()),
                          Text('${p.rating}', style: t.mono(40, spacing: -1.2)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(tier.name, style: t.display(20, spacing: -0.2)),
                          Text(toNext.toUpperCase(), style: t.label()),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MeterBar(value: tierProgress(p.rating)),
                  const SizedBox(height: 14),
                  StatStrip(items: <(String, String)>[
                    ('Best', p.best == 0 ? '–' : '${p.best}'),
                    ('Rounds', '${p.rounds}'),
                    ('Day streak', '${app.streak}'),
                  ]),
                  const SizedBox(height: 16),
                  PressBox(
                    onPressed: () => _play(context, RoundMode.daily),
                    shadow: const Offset(4, 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    semanticLabel: 'Daily challenge',
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Daily challenge · ${_dateLabel(app.now)}',
                                style: t.display(17, spacing: -0.2),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Same 60 seconds for everyone',
                                style: TextStyle(fontSize: 13, color: t.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          dailyBest == null ? 'Not played' : 'Best $dailyBest',
                          style: t.mono(13, color: t.pen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _dateLabel(DateTime now) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final DateTime ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${ist.day} ${months[ist.month - 1]}';
}

/// The big round start button: a stopwatch face with a sweeping hand.
class _StartDial extends StatefulWidget {
  const _StartDial({required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  State<_StartDial> createState() => _StartDialState();
}

class _StartDialState extends State<_StartDial>
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
    return Semantics(
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
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _sweep,
                      builder: (BuildContext context, Widget? _) => CustomPaint(
                        painter: _DialPainter(
                          tick: t.edge,
                          hand: t.pen,
                          turns: _sweep.value,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('60', style: t.display(s * 0.3, spacing: -s * 0.015)),
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
