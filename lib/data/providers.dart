import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/progress.dart';
import '../core/round_result.dart';
import 'progress_repository.dart';

/// Placeholder: throws until `bootstrap()` (or a test) overrides it with the
/// loaded instance. This is the only way async infra enters the graph.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('override in bootstrap()'),
);

/// The one source of "now". Tests override it to fix the date.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

final Provider<ProgressRepository> progressRepositoryProvider =
    Provider<ProgressRepository>(
  (Ref ref) => ProgressRepository(ref.watch(sharedPreferencesProvider)),
);

class ProgressNotifier extends Notifier<Progress> {
  @override
  Progress build() => ref.watch(progressRepositoryProvider).load();

  /// Saves first, then publishes, so a crash in between never shows progress
  /// that was not stored.
  Future<RoundSummary> apply(RoundResult result) async {
    final Progress previous = state;
    final Progress next =
        applyRound(previous, result, ref.read(clockProvider)());
    await ref.read(progressRepositoryProvider).save(next);
    state = next;
    return RoundSummary(result: result, previous: previous, current: next);
  }
}

final NotifierProvider<ProgressNotifier, Progress> progressProvider =
    NotifierProvider<ProgressNotifier, Progress>(ProgressNotifier.new);

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(progressRepositoryProvider).loadSettings();

  Future<void> toggleSound() => _set(state.copyWith(sound: !state.sound));

  Future<void> toggleHaptics() =>
      _set(state.copyWith(haptics: !state.haptics));

  Future<void> _set(Settings next) async {
    await ref.read(progressRepositoryProvider).saveSettings(next);
    state = next;
  }
}

final NotifierProvider<SettingsNotifier, Settings> settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

/// Derived, never stored: recomputed from progress and the clock.
final Provider<int> streakProvider = Provider<int>(
  (Ref ref) => streakFor(ref.watch(progressProvider), ref.read(clockProvider)()),
);

final Provider<int?> dailyBestTodayProvider = Provider<int?>(
  (Ref ref) =>
      dailyBestFor(ref.watch(progressProvider), ref.read(clockProvider)()),
);
