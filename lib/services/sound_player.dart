import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short sound effects. Each maps to `assets/sounds/<name>.wav`.
enum Sfx { key, ok, combo, wrong, skip, tick, go, end }

/// Port over the audio plugin, which cannot run in `flutter test`.
abstract interface class SoundPlayer {
  Future<void> play(Sfx sfx);
  void dispose();
}

/// Used in tests and when audio is unavailable.
class SilentSoundPlayer implements SoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> play(Sfx sfx) async {}

  @override
  void dispose() {}
}

class AudioplayersSoundPlayer implements SoundPlayer {
  final Map<Sfx, AudioPlayer> _players = <Sfx, AudioPlayer>{};

  AudioPlayer _playerFor(Sfx sfx) {
    return _players.putIfAbsent(sfx, () {
      final AudioPlayer p = AudioPlayer();
      p.setPlayerMode(PlayerMode.lowLatency);
      return p;
    });
  }

  @override
  Future<void> play(Sfx sfx) async {
    try {
      await _playerFor(sfx).play(AssetSource('sounds/${sfx.name}.wav'));
    } catch (error) {
      // A missing sound must never interrupt a round.
      debugPrint('Sound ${sfx.name} failed: $error');
    }
  }

  @override
  void dispose() {
    for (final AudioPlayer p in _players.values) {
      p.dispose();
    }
    _players.clear();
  }
}

final Provider<SoundPlayer> soundPlayerProvider = Provider<SoundPlayer>((Ref ref) {
  final AudioplayersSoundPlayer player = AudioplayersSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});
