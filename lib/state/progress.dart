import 'package:flutter/widgets.dart';

import '../game/round_controller.dart';
import '../logic/scoring.dart';

/// Everything that persists between launches.
class Progress {
  const Progress({
    this.rating = 700,
    this.best = 0,
    this.rounds = 0,
    this.dailyDate = '',
    this.dailyBest = 0,
    this.streakLast = '',
    this.streakCount = 0,
  });

  final int rating;
  final int best;
  final int rounds;
  final String dailyDate;
  final int dailyBest;
  final String streakLast;
  final int streakCount;

  Progress copyWith({
    int? rating,
    int? best,
    int? rounds,
    String? dailyDate,
    int? dailyBest,
    String? streakLast,
    int? streakCount,
  }) =>
      Progress(
        rating: rating ?? this.rating,
        best: best ?? this.best,
        rounds: rounds ?? this.rounds,
        dailyDate: dailyDate ?? this.dailyDate,
        dailyBest: dailyBest ?? this.dailyBest,
        streakLast: streakLast ?? this.streakLast,
        streakCount: streakCount ?? this.streakCount,
      );
}

/// Where [Progress] lives. The default keeps it in memory; swap in a
/// shared_preferences version before shipping.
abstract class ProgressStore {
  Future<Progress> load();
  Future<void> save(Progress progress);
}

class MemoryProgressStore implements ProgressStore {
  Progress _value = const Progress();

  @override
  Future<Progress> load() async => _value;

  @override
  Future<void> save(Progress progress) async => _value = progress;
}

/// What changed when a round was applied; the result screen reads this.
class RoundSummary {
  const RoundSummary({
    required this.result,
    required this.previous,
    required this.current,
  });

  final RoundResult result;
  final Progress previous;
  final Progress current;

  bool get isSprint => result.mode == RoundMode.sprint;
  int get ratingDelta => current.rating - previous.rating;
  bool get newBest => isSprint && result.score > previous.best;
  bool get tierUp => tierIndexFor(current.rating) > tierIndexFor(previous.rating);
}

/// Day id in India Standard Time (UTC+05:30), for example `2026-11-05`.
/// The daily challenge rolls over at midnight IST for everyone.
String dayIdIst(DateTime now) {
  final DateTime ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${ist.year}-${two(ist.month)}-${two(ist.day)}';
}

/// Seed for the daily challenge, `20261105` for 5 November 2026.
int dailySeedFor(DateTime now) {
  final DateTime ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return ist.year * 10000 + ist.month * 100 + ist.day;
}

class AppState extends ChangeNotifier {
  AppState(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ProgressStore _store;
  final DateTime Function() _clock;

  Progress progress = const Progress();
  bool loaded = false;

  DateTime get now => _clock();
  int get dailySeed => dailySeedFor(now);

  /// Days in a row played, 0 if yesterday was missed.
  int get streak {
    final DateTime n = now;
    final String today = dayIdIst(n);
    final String yesterday = dayIdIst(n.subtract(const Duration(days: 1)));
    if (progress.streakLast == today || progress.streakLast == yesterday) {
      return progress.streakCount;
    }
    return 0;
  }

  int? get dailyBestToday =>
      progress.dailyDate == dayIdIst(now) ? progress.dailyBest : null;

  Future<void> load() async {
    progress = await _store.load();
    loaded = true;
    notifyListeners();
  }

  RoundSummary apply(RoundResult result) {
    final Progress prev = progress;
    final DateTime n = now;
    final String today = dayIdIst(n);
    final String yesterday = dayIdIst(n.subtract(const Duration(days: 1)));

    int streakCount = prev.streakCount;
    String streakLast = prev.streakLast;
    if (streakLast != today) {
      streakCount = streakLast == yesterday ? streakCount + 1 : 1;
      streakLast = today;
    }

    Progress next = prev.copyWith(
      rounds: prev.rounds + 1,
      streakCount: streakCount,
      streakLast: streakLast,
    );

    if (result.mode == RoundMode.sprint) {
      final int delta = ratingDelta(result.score, prev.rating);
      final int rating = prev.rating + delta < 400 ? 400 : prev.rating + delta;
      next = next.copyWith(
        rating: rating,
        best: result.score > prev.best ? result.score : prev.best,
      );
    } else {
      final bool sameDay = prev.dailyDate == today;
      next = next.copyWith(
        dailyDate: today,
        dailyBest: sameDay && prev.dailyBest > result.score
            ? prev.dailyBest
            : result.score,
      );
    }

    progress = next;
    _store.save(next);
    notifyListeners();
    return RoundSummary(result: result, previous: prev, current: next);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Reads the state without subscribing; safe in `initState` and callbacks.
  static AppState read(BuildContext context) {
    final AppScope? scope =
        context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }

  static AppState of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}
