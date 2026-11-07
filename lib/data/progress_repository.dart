import 'package:shared_preferences/shared_preferences.dart';

import '../core/progress.dart';

/// Stores [Progress] and [Settings] on the device. It is the single write
/// path: a notifier saves here first and only then publishes new state.
///
/// Concrete on purpose. `SharedPreferences.setMockInitialValues` lets tests
/// run it without a platform channel, so no interface is needed.
class ProgressRepository {
  ProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _rating = 'rating';
  static const String _best = 'best';
  static const String _rounds = 'rounds';
  static const String _dailyDate = 'dailyDate';
  static const String _dailyBest = 'dailyBest';
  static const String _streakLast = 'streakLast';
  static const String _streakCount = 'streakCount';
  static const String _sound = 'sound';
  static const String _haptics = 'haptics';

  Progress load() {
    const Progress defaults = Progress();
    final int rating = _prefs.getInt(_rating) ?? defaults.rating;
    return Progress(
      rating: rating < 400 ? 400 : rating,
      best: _prefs.getInt(_best) ?? defaults.best,
      rounds: _prefs.getInt(_rounds) ?? defaults.rounds,
      dailyDate: _prefs.getString(_dailyDate) ?? defaults.dailyDate,
      dailyBest: _prefs.getInt(_dailyBest) ?? defaults.dailyBest,
      streakLast: _prefs.getString(_streakLast) ?? defaults.streakLast,
      streakCount: _prefs.getInt(_streakCount) ?? defaults.streakCount,
    );
  }

  Future<void> save(Progress p) async {
    await Future.wait(<Future<bool>>[
      _prefs.setInt(_rating, p.rating),
      _prefs.setInt(_best, p.best),
      _prefs.setInt(_rounds, p.rounds),
      _prefs.setString(_dailyDate, p.dailyDate),
      _prefs.setInt(_dailyBest, p.dailyBest),
      _prefs.setString(_streakLast, p.streakLast),
      _prefs.setInt(_streakCount, p.streakCount),
    ]);
  }

  Settings loadSettings() => Settings(
        sound: _prefs.getBool(_sound) ?? true,
        haptics: _prefs.getBool(_haptics) ?? true,
      );

  Future<void> saveSettings(Settings s) async {
    await Future.wait(<Future<bool>>[
      _prefs.setBool(_sound, s.sound),
      _prefs.setBool(_haptics, s.haptics),
    ]);
  }
}
