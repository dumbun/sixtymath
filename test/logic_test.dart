import 'package:flutter_test/flutter_test.dart';
import 'package:sixtymath/logic/mulberry32.dart';
import 'package:sixtymath/logic/question.dart';
import 'package:sixtymath/logic/scoring.dart';
import 'package:sixtymath/state/progress.dart';

// Expected values below were produced by running the web prototype's own
// generator in Node. If one fails, the Dart port has drifted from it, and
// daily boards and challenges would stop matching across devices.
void main() {
  group('Mulberry32', () {
    test('matches the prototype for seed 20261105', () {
      final Mulberry32 rng = Mulberry32(20261105);
      const List<double> expected = <double>[
        0.10204124473966658,
        0.6270352604333311,
        0.22736229840666056,
        0.42496274085715413,
        0.29522614018060267,
        0.5719205481000245,
      ];
      for (final double e in expected) {
        expect(rng.next(), closeTo(e, 1e-15));
      }
    });
  });

  group('generateQuestion', () {
    test('daily ramp for seed 20261105 matches the prototype', () {
      const List<(String, int)> expected = <(String, int)>[
        ('29 + 8', 37),
        ('19 − 13', 6),
        ('38 + 7', 45),
        ('39 + 5', 44),
        ('19 − 15', 4),
        ('57 + 85', 142),
        ('53 + 52', 105),
        ('9 × 4', 36),
        ('42 − 39', 3),
        ('49 + 45', 94),
        ('35 × 7', 245),
        ('194 + 32', 226),
        ('95 ÷ 5', 19),
        ('25% of 100', 25),
        ('50% of 88', 44),
        ('510 ÷ 15', 34),
        ('20 × 7', 140),
        ('314 − 69', 245),
        ('389 − 45', 344),
        ('495 ÷ 15', 33),
        ('613 + 260', 873),
        ('23²', 529),
        ('102 + 333', 435),
        ('661 − 245', 416),
      ];
      final Mulberry32 rng = Mulberry32(20261105);
      for (int i = 0; i < expected.length; i++) {
        final int level = 1 + i ~/ 5 > 7 ? 7 : 1 + i ~/ 5;
        final Question q = generateQuestion(rng, level);
        expect(q.text, expected[i].$1, reason: 'question $i');
        expect(q.answer, expected[i].$2, reason: 'answer $i');
      }
    });

    test('one question per level for seed 77 matches the prototype', () {
      const List<(int, String, int)> expected = <(int, String, int)>[
        (0, '3 + 7', 10),
        (1, '17 − 13', 4),
        (2, '30 ÷ 10', 3),
        (3, '184 + 66', 250),
        (4, '72 × 5', 360),
        (5, '217 + 129', 346),
        (6, '26 × 29', 754),
        (7, '790 + 399', 1189),
        (8, '1831 + 888', 2719),
      ];
      final Mulberry32 rng = Mulberry32(77);
      for (final (int level, String text, int answer) in expected) {
        final Question q = generateQuestion(rng, level);
        expect(q.text, text, reason: 'level $level');
        expect(q.answer, answer, reason: 'level $level');
      }
    });

    test('every answer is a positive whole number', () {
      final Mulberry32 rng = Mulberry32(1);
      for (int level = 0; level <= 8; level++) {
        for (int i = 0; i < 2000; i++) {
          final Question q = generateQuestion(rng, level);
          expect(q.answer, greaterThan(0), reason: q.text);
        }
      }
    });
  });

  group('scoring', () {
    test('combo multiplier steps at 5 and 10', () {
      expect(<int>[0, 4, 5, 9, 10, 25].map(multiplierFor).toList(),
          <int>[1, 1, 2, 2, 3, 3]);
    });

    test('tiers change at their thresholds', () {
      String tier(int r) => tiers[tierIndexFor(r)].name;
      expect(tier(999), 'Bronze');
      expect(tier(1000), 'Silver');
      expect(tier(1400), 'Gold');
      expect(tier(2200), 'Diamond');
    });

    test('rating change matches the prototype', () {
      expect(ratingDelta(5, 700), -20);
      expect(ratingDelta(34, 700), 4);
      expect(ratingDelta(50, 700), 28);
      expect(ratingDelta(38, 1000), 13);
      expect(ratingDelta(41, 1400), 23);
    });
  });

  group('daily day id', () {
    test('rolls over at midnight India time', () {
      expect(dayIdIst(DateTime.utc(2026, 11, 5, 18, 29)), '2026-11-05');
      expect(dayIdIst(DateTime.utc(2026, 11, 5, 18, 30)), '2026-11-06');
      expect(dailySeedFor(DateTime.utc(2026, 11, 5, 6)), 20261105);
    });
  });
}
