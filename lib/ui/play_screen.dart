import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/round_controller.dart';
import '../logic/scoring.dart';
import '../state/progress.dart';
import '../theme/tokens.dart';
import 'result_screen.dart';
import 'widgets.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.mode});

  final RoundMode mode;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final RoundController _round;
  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch();
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    final AppState app = AppScope.read(context);
    final int seed = widget.mode == RoundMode.daily
        ? app.dailySeed
        : math.Random().nextInt(0x7FFFFFFF);
    _round = RoundController(
      mode: widget.mode,
      seed: seed,
      startLevel: levelForRating(app.progress.rating),
      onEvent: _feedback,
    );
    _ticker = createTicker((Duration _) {
      _round.tick(_clock.elapsedMilliseconds);
      if (_round.phase == RoundPhase.finished) _finish();
    });
    _clock.start();
    _round.start(0);
    _ticker.start();
  }

  void _feedback(RoundEvent e) {
    switch (e) {
      case RoundEvent.key:
      case RoundEvent.skip:
        HapticFeedback.selectionClick();
      case RoundEvent.correct:
      case RoundEvent.countdownTick:
        HapticFeedback.lightImpact();
      case RoundEvent.combo:
      case RoundEvent.go:
        HapticFeedback.mediumImpact();
      case RoundEvent.wrong:
      case RoundEvent.end:
        HapticFeedback.heavyImpact();
    }
  }

  void _finish() {
    if (_handedOff) return;
    _handedOff = true;
    _ticker.stop();
    final RoundSummary summary = AppScope.read(context).apply(_round.result);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(summary: summary)),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _round.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final String? ch = event.character;
    if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
      _round.press(ch);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _round.press('back');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _round.press('skip');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: PaperScaffold(
        child: ListenableBuilder(
          listenable: _round,
          builder: (BuildContext context, Widget? _) {
            final RoundPhase phase = _round.phase;
            final bool live = phase == RoundPhase.running;
            final bool showQuestion =
                live || phase == RoundPhase.timeUp;
            return Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const SizedBox(height: 10),
                    _Hud(round: _round, onQuit: () => Navigator.of(context).pop()),
                    const SizedBox(height: 10),
                    _TimeBar(round: _round),
                    Expanded(child: _Stage(round: _round, showQuestion: showQuestion)),
                    _Numpad(round: _round),
                    const SizedBox(height: 10),
                  ],
                ),
                if (phase == RoundPhase.countdown)
                  _Overlay(text: '${_round.countdownNumber}', size: 150, color: t.pen),
                if (phase == RoundPhase.timeUp)
                  _Overlay(text: 'Time', size: 96, color: t.pen),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.text, required this.size, required this.color});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: t.paper.withAlpha(220),
        child: Center(child: Text(text, style: t.display(size, color: color))),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.round, required this.onQuit});

  final RoundController round;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final int secs = (round.timeLeftMs / 1000).ceil();
    final bool low = round.phase == RoundPhase.running && secs <= 10;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Row(
          children: <Widget>[
            PressBox(
              onPressed: onQuit,
              shadow: Offset.zero,
              radius: 6,
              semanticLabel: 'Quit sprint',
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.close, size: 18, color: t.ink),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Text(
                '$secs',
                style: t.mono(34, color: low ? t.bad : t.ink, spacing: -0.7),
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            CustomPaint(
              size: const Size(46, 28),
              painter: _TallyPainter(
                filled: round.combo == 0 ? 0 : ((round.combo - 1) % 5) + 1,
                on: t.ink,
                off: t.line,
              ),
            ),
            const SizedBox(width: 6),
            Text('×${round.multiplier}', style: t.mono(22, color: t.pen)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('SCORE', style: t.label()),
            Text('${round.score}', style: t.mono(34, spacing: -0.7)),
          ],
        ),
      ],
    );
  }
}

/// Four upright strokes and a diagonal: one mark per correct answer in the
/// current run of five.
class _TallyPainter extends CustomPainter {
  _TallyPainter({required this.filled, required this.on, required this.off});

  final int filled;
  final Color on;
  final Color off;

  @override
  void paint(Canvas canvas, Size size) {
    Paint pen(int i) => Paint()
      ..color = i < filled ? on : off
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final double x = 7 + i * 10;
      canvas.drawLine(Offset(x, 4), Offset(x, 24), pen(i));
    }
    canvas.drawLine(const Offset(2, 21), const Offset(42, 7), pen(4));
  }

  @override
  bool shouldRepaint(_TallyPainter old) =>
      old.filled != filled || old.on != on || old.off != off;
}

class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final double left = round.timeLeftMs / round.roundMs;
    final bool low = round.timeLeftMs <= 10000 && round.phase != RoundPhase.countdown;
    return MeterBar(value: left, color: low ? t.bad : t.pen);
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.round, required this.showQuestion});

  final RoundController round;
  final bool showQuestion;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final bool locked = showQuestion && round.locked;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 72,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                showQuestion ? round.question.text : 'Ready',
                style: t.display(64, spacing: -2.2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 58,
            child: showQuestion
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (int i = 0; i < round.answerLength; i++)
                        _Slot(
                          char: i < round.typed.length ? round.typed[i] : '',
                          current: !locked && i == round.typed.length,
                          wrong: locked,
                        ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 26,
            child: locked
                ? Text(
                    '= ${round.question.answer}',
                    style: t.mono(20, color: t.bad),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.char, required this.current, required this.wrong});

  final String char;
  final bool current;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final Color line = wrong ? t.bad : (current ? t.pen : t.edge);
    return Container(
      width: 40,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: 4)),
      ),
      child: Text(
        char,
        style: t.mono(38, color: wrong ? t.bad : t.ink).copyWith(
              decoration: wrong ? TextDecoration.lineThrough : null,
              decorationColor: t.bad,
              decorationThickness: 2,
            ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.sizeOf(context).height;
    final double keyHeight = math.max(50.0, math.min(66.0, h * 0.085));
    const List<List<String>> rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
      <String>['back', '0', 'skip'],
    ];
    return Column(
      children: <Widget>[
        for (final List<String> row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < row.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _Key(
                      keyName: row[i],
                      height: keyHeight,
                      onPressed: () => round.press(row[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.keyName,
    required this.height,
    required this.onPressed,
  });

  final String keyName;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final bool action = keyName == 'back' || keyName == 'skip';
    final Widget label = switch (keyName) {
      'back' => Icon(Icons.backspace_outlined, size: 24, color: t.ink),
      'skip' => Text('SKIP', style: t.mono(12, spacing: 1.4)),
      _ => Text(keyName, style: t.mono(30)),
    };
    return PressBox(
      fireOnDown: true,
      onPressed: onPressed,
      color: action ? Colors.transparent : null,
      semanticLabel: switch (keyName) {
        'back' => 'Delete last digit',
        'skip' => 'Skip this question',
        _ => keyName,
      },
      child: SizedBox(height: height - 4, child: Center(child: label)),
    );
  }
}
