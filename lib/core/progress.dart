import 'round_result.dart';
import 'scoring.dart';

/// Everything about the player that persists between launches.
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

  @override
  bool operator ==(Object other) =>
      other is Progress &&
      other.rating == rating &&
      other.best == best &&
      other.rounds == rounds &&
      other.dailyDate == dailyDate &&
      other.dailyBest == dailyBest &&
      other.streakLast == streakLast &&
      other.streakCount == streakCount;

  @override
  int get hashCode => Object.hash(
        rating,
        best,
        rounds,
        dailyDate,
        dailyBest,
        streakLast,
        streakCount,
      );
}

/// Sound and haptics switches.
class Settings {
  const Settings({this.sound = true, this.haptics = true});

  final bool sound;
  final bool haptics;

  Settings copyWith({bool? sound, bool? haptics}) =>
      Settings(sound: sound ?? this.sound, haptics: haptics ?? this.haptics);

  @override
  bool operator ==(Object other) =>
      other is Settings && other.sound == sound && other.haptics == haptics;

  @override
  int get hashCode => Object.hash(sound, haptics);
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
  bool get tierUp =>
      tierIndexFor(current.rating) > tierIndexFor(previous.rating);
}

DateTime _ist(DateTime now) =>
    now.toUtc().add(const Duration(hours: 5, minutes: 30));

String _two(int n) => n < 10 ? '0$n' : '$n';

/// Day id in India Standard Time (UTC+05:30), for example `2026-11-05`.
/// The daily challenge rolls over at midnight IST for everyone.
String dayIdIst(DateTime now) {
  final DateTime d = _ist(now);
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

/// Seed for the daily challenge, `20261105` for 5 November 2026.
int dailySeedFor(DateTime now) {
  final DateTime d = _ist(now);
  return d.year * 10000 + d.month * 100 + d.day;
}

/// Days in a row played, 0 if yesterday was missed.
int streakFor(Progress p, DateTime now) {
  final String today = dayIdIst(now);
  final String yesterday = dayIdIst(now.subtract(const Duration(days: 1)));
  return (p.streakLast == today || p.streakLast == yesterday)
      ? p.streakCount
      : 0;
}

/// Best daily score today, null if the daily has not been played today.
int? dailyBestFor(Progress p, DateTime now) =>
    p.dailyDate == dayIdIst(now) ? p.dailyBest : null;

/// The player's progress after one more round. Pure, so it is tested without
/// storage or a clock.
Progress applyRound(Progress prev, RoundResult result, DateTime now) {
  final String today = dayIdIst(now);
  final String yesterday = dayIdIst(now.subtract(const Duration(days: 1)));

  int streakCount = prev.streakCount;
  String streakLast = prev.streakLast;
  if (streakLast != today) {
    streakCount = streakLast == yesterday ? streakCount + 1 : 1;
    streakLast = today;
  }

  final Progress base = prev.copyWith(
    rounds: prev.rounds + 1,
    streakCount: streakCount,
    streakLast: streakLast,
  );

  if (result.mode == RoundMode.sprint) {
    final int raw = prev.rating + ratingDelta(result.score, prev.rating);
    return base.copyWith(
      rating: raw < 400 ? 400 : raw,
      best: result.score > prev.best ? result.score : prev.best,
    );
  }

  final bool sameDay = prev.dailyDate == today;
  return base.copyWith(
    dailyDate: today,
    dailyBest: sameDay && prev.dailyBest > result.score
        ? prev.dailyBest
        : result.score,
  );
}
