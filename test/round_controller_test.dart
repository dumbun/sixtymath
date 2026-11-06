import 'package:flutter_test/flutter_test.dart';
import 'package:sixtymath/game/round_controller.dart';

void solve(RoundController c) {
  for (final String ch in c.question.answer.toString().split('')) {
    c.press(ch);
  }
}

void main() {
  RoundController daily() => RoundController(
        mode: RoundMode.daily,
        seed: 20261105,
        startLevel: 0,
      );

  test('counts down 3-2-1 then starts on the first fixture question', () {
    final RoundController c = daily()..start(0);
    expect(c.phase, RoundPhase.countdown);
    expect(c.countdownNumber, 3);
    c.tick(430);
    expect(c.countdownNumber, 2);
    c.tick(1260);
    expect(c.phase, RoundPhase.running);
    expect(c.question.text, '29 + 8');
  });

  test('correct answers score, wrong answers break the combo and lock', () {
    final RoundController c = daily()..start(0);
    c.tick(1260);
    solve(c); // 29 + 8
    solve(c); // 19 - 13
    expect(c.score, 2);
    expect(c.combo, 2);
    expect(c.question.text, '38 + 7');

    c.tick(1300);
    c.press('4');
    c.press('4'); // wrong, the answer is 45
    expect(c.wrong, 1);
    expect(c.combo, 0);
    expect(c.locked, isTrue);
    c.press('5'); // ignored while locked
    expect(c.typed, '44');

    c.tick(1300 + 419);
    expect(c.locked, isTrue);
    c.tick(1300 + 420);
    expect(c.locked, isFalse);
    expect(c.question.text, '39 + 5');
  });

  test('five in a row doubles the points', () {
    final RoundController c = daily()..start(0);
    c.tick(1260);
    for (int i = 0; i < 5; i++) {
      solve(c);
    }
    expect(c.score, 5);
    expect(c.multiplier, 2);
    solve(c);
    expect(c.score, 7);
  });

  test('skip breaks the combo and logs a miss', () {
    final RoundController c = daily()..start(0);
    c.tick(1260);
    solve(c);
    c.press('skip');
    expect(c.skipped, 1);
    expect(c.combo, 0);
    expect(c.result.misses.single.skipped, isTrue);
  });

  test('round ends after 60 seconds and then finishes', () {
    final RoundController c = daily()..start(0);
    c.tick(1260);
    c.tick(1260 + 59000);
    expect(c.phase, RoundPhase.running);
    expect(c.timeLeftMs, 1000);
    c.tick(1260 + 60000);
    expect(c.phase, RoundPhase.timeUp);
    c.press('1');
    expect(c.typed, '');
    c.tick(1260 + 60000 + 700);
    expect(c.phase, RoundPhase.finished);
  });
}
