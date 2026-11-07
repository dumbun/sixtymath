import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/progress.dart';
import '../../../core/round_result.dart';
import '../../../core/scoring.dart';
import '../../../data/providers.dart';
import '../../../services/feedback_service.dart';
import '../../../shared/widgets.dart';
import '../../../theme/tokens.dart';
import '../../result/presentation/result_screen.dart';
import '../application/round_controller.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.mode});

  final RoundMode mode;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final RoundController _round;
  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch();
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = ref.read(clockProvider)();
    final int seed = widget.mode == RoundMode.daily
        ? dailySeedFor(now)
        : math.Random().nextInt(0x7FFFFFFF);
    _round = RoundController(
      mode: widget.mode,
      seed: seed,
      startLevel: levelForRating(ref.read(progressProvider).rating),
      onEvent: ref.read(feedbackProvider).handle,
    );
    _ticker = createTicker((Duration _) {
      _round.tick(_clock.elapsedMilliseconds);
      if (_round.phase == RoundPhase.finished) _finish();
    });
    _clock.start();
    _round.start(0);
    _ticker.start();
  }

  Future<void> _finish() async {
    if (_handedOff) return;
    _handedOff = true;
    _ticker.stop();
    final RoundSummary summary =
        await ref.read(progressProvider.notifier).apply(_round.result);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
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
    if (ch != null &&
        ch.length == 1 &&
        ch.codeUnitAt(0) >= 48 &&
        ch.codeUnitAt(0) <= 57) {
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
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: PaperScaffold(
        builder: (BuildContext context, bool wide) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              return ListenableBuilder(
                listenable: _round,
                builder: (BuildContext context, Widget? _) =>
                    _PlayBody(round: _round, wide: wide, box: box),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlayBody extends StatelessWidget {
  const _PlayBody({required this.round, required this.wide, required this.box});

  final RoundController round;
  final bool wide;
  final BoxConstraints box;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final RoundPhase phase = round.phase;
    final bool showQuestion =
        phase == RoundPhase.running || phase == RoundPhase.timeUp;

    // Key height comes from the space we have, not the device: the fixed
    // chrome (HUD, bar, stage minimum) is subtracted and the rest is shared
    // between four rows of keys.
    final double padSpace = wide ? box.maxHeight - 20 : box.maxHeight - 276;
    final double keyHeight = math.max(40.0, math.min(66.0, padSpace / 4 - 10));

    final Widget top = Column(
      children: <Widget>[
        const SizedBox(height: 10),
        _Hud(round: round, onQuit: () => Navigator.of(context).pop()),
        const SizedBox(height: 10),
        _TimeBar(round: round),
      ],
    );
    final Widget stage = _Stage(round: round, showQuestion: showQuestion);
    final Widget pad = _Numpad(round: round, keyHeight: keyHeight);

    final Widget layout = wide
        ? Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[top, Expanded(child: stage)],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(width: 340, child: Center(child: pad)),
            ],
          )
        : Column(
            children: <Widget>[
              top,
              Expanded(child: stage),
              pad,
              const SizedBox(height: 10),
            ],
          );

    return Stack(
      children: <Widget>[
        layout,
        if (phase == RoundPhase.countdown)
          _Overlay(text: '${round.countdownNumber}', size: 150, color: t.pen),
        if (phase == RoundPhase.timeUp)
          _Overlay(text: 'Time', size: 96, color: t.pen),
      ],
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
              child: ValueListenableBuilder<int>(
                valueListenable: round.timeLeftMs,
                builder: (BuildContext context, int ms, Widget? _) {
                  final int secs = (ms / 1000).ceil();
                  final bool low =
                      round.phase == RoundPhase.running && secs <= 10;
                  return Text(
                    '$secs',
                    style: t.mono(34, color: low ? t.bad : t.ink, spacing: -0.7),
                  );
                },
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

/// Shrinks every frame, so it listens to the time notifier on its own and
/// sits on its own paint layer. Nothing else on screen rebuilds with it.
class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: round.timeLeftMs,
        builder: (BuildContext context, int ms, Widget? _) {
          final bool low = ms <= 10000 && round.phase != RoundPhase.countdown;
          return MeterBar(value: ms / round.roundMs, color: low ? t.bad : t.pen);
        },
      ),
    );
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
  const _Numpad({required this.round, required this.keyHeight});

  final RoundController round;
  final double keyHeight;

  static const List<List<String>> _rows = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
    <String>['back', '0', 'skip'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final List<String> row in _rows)
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
      _ => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(keyName, style: t.mono(30)),
        ),
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
