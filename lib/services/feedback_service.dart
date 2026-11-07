import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/progress.dart';
import '../core/round_event.dart';
import '../data/providers.dart';
import 'sound_player.dart';

/// Turns round events into haptics and sound, honouring the player's
/// settings. Reads settings at call time, so toggles apply immediately.
class FeedbackService {
  FeedbackService({required SoundPlayer sound, required Settings Function() settings})
      : _sound = sound,
        _settings = settings;

  final SoundPlayer _sound;
  final Settings Function() _settings;

  void handle(RoundEvent event) {
    final Settings s = _settings();
    if (s.haptics) {
      switch (event) {
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
    if (s.sound) {
      _sound.play(switch (event) {
        RoundEvent.key => Sfx.key,
        RoundEvent.correct => Sfx.ok,
        RoundEvent.combo => Sfx.combo,
        RoundEvent.wrong => Sfx.wrong,
        RoundEvent.skip => Sfx.skip,
        RoundEvent.countdownTick => Sfx.tick,
        RoundEvent.go => Sfx.go,
        RoundEvent.end => Sfx.end,
      });
    }
  }
}

final Provider<FeedbackService> feedbackProvider = Provider<FeedbackService>(
  (Ref ref) => FeedbackService(
    sound: ref.watch(soundPlayerProvider),
    settings: () => ref.read(settingsProvider),
  ),
);
