import 'package:flutter/foundation.dart';

import '../logic/analysis.dart';
import '../logic/mulberry32.dart';
import '../logic/question.dart';
import '../logic/scoring.dart';

enum RoundMode { sprint, daily }

enum RoundPhase { idle, countdown, running, timeUp, finished }

/// Things the UI turns into haptics or sound.
enum RoundEvent { key, correct, combo, wrong, skip, countdownTick, go, end }

class RoundResult {
  const RoundResult({
    required this.mode,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.maxCombo,
    required this.log,
  });

  final RoundMode mode;
  final int score;
  final int correct;
  final int wrong;
  final int skipped;
  final int maxCombo;
  final List<LogEntry> log;

  int get attempts => correct + wrong + skipped;
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  Analysis get analysis => analyse(log);
  List<LogEntry> get misses =>
      log.where((LogEntry e) => !e.ok).toList(growable: false);
}

/// The whole 60-second round as a state machine. It never reads the clock:
/// the screen feeds it `nowMs` from a ticker, so tests can drive it with
/// fake time.
class RoundController extends ChangeNotifier {
  RoundController({
    required this.mode,
    required int seed,
    required this.startLevel,
    this.stepMs = 420,
    this.roundMs = 60000,
    this.lockMs = 420,
    this.timeUpMs = 700,
    this.onEvent,
  }) : _rng = Mulberry32(seed);

  final RoundMode mode;
  final int startLevel;
  final int stepMs;
  final int roundMs;
  final int lockMs;
  final int timeUpMs;
  final void Function(RoundEvent event)? onEvent;

  final Mulberry32 _rng;
  final List<LogEntry> _log = <LogEntry>[];

  RoundPhase phase = RoundPhase.idle;
  int countdownNumber = 3;

  late Question question;
  String typed = '';
  bool locked = false;
  int score = 0;
  int combo = 0;
  int maxCombo = 0;
  int correct = 0;
  int wrong = 0;
  int skipped = 0;
  int timeLeftMs = 0;

  int _questionIndex = 0;
  String? _lastText;
  int _t0 = 0;
  int _runStart = 0;
  int _runEnd = 0;
  int _questionStart = 0;
  int _lockUntil = 0;
  int _timeUpAt = 0;
  int _now = 0;

  int get multiplier => multiplierFor(combo);
  int get answerLength => question.answer.toString().length;

  RoundResult get result => RoundResult(
        mode: mode,
        score: score,
        correct: correct,
        wrong: wrong,
        skipped: skipped,
        maxCombo: maxCombo,
        log: List<LogEntry>.unmodifiable(_log),
      );

  void start(int nowMs) {
    _now = nowMs;
    _t0 = nowMs;
    phase = RoundPhase.countdown;
    countdownNumber = 3;
    timeLeftMs = roundMs;
    onEvent?.call(RoundEvent.countdownTick);
    notifyListeners();
  }

  /// Advance time. Safe to call every frame.
  void tick(int nowMs) {
    _now = nowMs;
    switch (phase) {
      case RoundPhase.idle:
      case RoundPhase.finished:
        return;
      case RoundPhase.countdown:
        final int elapsed = nowMs - _t0;
        if (elapsed >= stepMs * 3) {
          _runStart = _t0 + stepMs * 3;
          _runEnd = _runStart + roundMs;
          phase = RoundPhase.running;
          _questionStart = nowMs;
          onEvent?.call(RoundEvent.go);
          _nextQuestion();
          timeLeftMs = roundMs;
        } else {
          final int n = 3 - elapsed ~/ stepMs;
          if (n != countdownNumber) {
            countdownNumber = n;
            onEvent?.call(RoundEvent.countdownTick);
          }
        }
        notifyListeners();
      case RoundPhase.running:
        if (locked && nowMs >= _lockUntil) {
          _nextQuestion();
        }
        if (nowMs >= _runEnd) {
          timeLeftMs = 0;
          phase = RoundPhase.timeUp;
          _timeUpAt = nowMs;
          onEvent?.call(RoundEvent.end);
        } else {
          timeLeftMs = _runEnd - nowMs;
        }
        notifyListeners();
      case RoundPhase.timeUp:
        if (nowMs - _timeUpAt >= timeUpMs) {
          phase = RoundPhase.finished;
          notifyListeners();
        }
    }
  }

  int _levelNow() {
    if (mode == RoundMode.daily) {
      final int l = 1 + _questionIndex ~/ 5;
      return l > 7 ? 7 : l;
    }
    int l = startLevel;
    if (_questionIndex < 3) {
      l = l - 1 < 0 ? 0 : l - 1;
    } else if (combo >= 15) {
      l = l + 1 > 8 ? 8 : l + 1;
    }
    return l;
  }

  void _nextQuestion() {
    Question q = generateQuestion(_rng, _levelNow());
    int tries = 1;
    while (q.text == _lastText && tries < 6) {
      q = generateQuestion(_rng, _levelNow());
      tries++;
    }
    _lastText = q.text;
    question = q;
    _questionIndex++;
    typed = '';
    locked = false;
    _questionStart = _now;
  }

  /// A digit '0'..'9', 'back' or 'skip'.
  void press(String key) {
    if (phase != RoundPhase.running || locked) return;
    if (key == 'skip') {
      _skip();
      return;
    }
    if (key == 'back') {
      if (typed.isNotEmpty) {
        typed = typed.substring(0, typed.length - 1);
        onEvent?.call(RoundEvent.key);
        notifyListeners();
      }
      return;
    }
    final String answer = question.answer.toString();
    if (typed.length >= answer.length) return;
    if (typed.isEmpty && key == '0') return;
    typed += key;
    onEvent?.call(RoundEvent.key);
    if (typed.length == answer.length) {
      if (typed == answer) {
        _onCorrect();
      } else {
        _onWrong();
      }
    }
    notifyListeners();
  }

  void _onCorrect() {
    final int pts = multiplier;
    _log.add(LogEntry(
      question: question,
      ms: (_now - _questionStart).toDouble(),
      ok: true,
    ));
    combo++;
    if (combo > maxCombo) maxCombo = combo;
    correct++;
    score += pts;
    onEvent?.call(combo % 5 == 0 ? RoundEvent.combo : RoundEvent.correct);
    _nextQuestion();
  }

  void _onWrong() {
    _log.add(LogEntry(
      question: question,
      ms: (_now - _questionStart).toDouble(),
      ok: false,
      typed: typed,
    ));
    wrong++;
    combo = 0;
    locked = true;
    _lockUntil = _now + lockMs;
    onEvent?.call(RoundEvent.wrong);
  }

  void _skip() {
    _log.add(LogEntry(
      question: question,
      ms: (_now - _questionStart).toDouble(),
      ok: false,
      skipped: true,
    ));
    skipped++;
    combo = 0;
    onEvent?.call(RoundEvent.skip);
    _nextQuestion();
    notifyListeners();
  }
}
