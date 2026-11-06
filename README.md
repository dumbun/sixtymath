# sixtymath

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## SixtyMath UI

Flutter port of the web prototype: home dial, 60-second play screen with an
auto-submit numpad, and a result screen with rating, weak spots and Retry.

- `lib/logic/` pure Dart: seeded RNG, question generator, scoring, analysis.
  `test/logic_test.dart` checks them against output from the prototype, so the
  daily challenge matches across devices.
- `lib/game/round_controller.dart` the round state machine. It takes `nowMs`
  from a ticker, so tests drive it with fake time.
- `lib/state/progress.dart` rating, best score, streak. Uses an in-memory
  store for now; replace `MemoryProgressStore` with shared_preferences.
- `lib/ui/` screens. `lib/theme/tokens.dart` holds the colours and type.

Run `flutter test`, then `flutter run`.
