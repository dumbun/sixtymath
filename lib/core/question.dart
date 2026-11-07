import 'mulberry32.dart';
import 'scoring.dart' show clampInt;

enum Category { add, sub, mul, div, pct, sq }

extension CategoryLabel on Category {
  String get label => switch (this) {
        Category.add => 'Add',
        Category.sub => 'Subtract',
        Category.mul => 'Multiply',
        Category.div => 'Divide',
        Category.pct => 'Percent',
        Category.sq => 'Squares',
      };
}

class Question {
  const Question({
    required this.text,
    required this.answer,
    required this.category,
    this.factKey,
  });

  final String text;
  final int answer;
  final Category category;

  /// Names the specific fact (for example `7×8` or `15%`) so the weak-spot
  /// report can point at it. Null when the question is too varied to name.
  final String? factKey;
}

typedef _Range = List<int>;

const List<Map<Category, int>> _weights = <Map<Category, int>>[
  {Category.add: 4, Category.sub: 3, Category.mul: 2},
  {Category.add: 3, Category.sub: 3, Category.mul: 3, Category.div: 1},
  {Category.add: 3, Category.sub: 3, Category.mul: 3, Category.div: 2},
  {
    Category.add: 2,
    Category.sub: 2,
    Category.mul: 3,
    Category.div: 2,
    Category.pct: 2,
  },
  {
    Category.add: 2,
    Category.sub: 2,
    Category.mul: 3,
    Category.div: 2,
    Category.pct: 2,
    Category.sq: 1,
  },
  {
    Category.add: 2,
    Category.sub: 2,
    Category.mul: 3,
    Category.div: 2,
    Category.pct: 2,
    Category.sq: 2,
  },
];

// Each entry is [first operand range, second operand range], by level 0..8.
const List<List<_Range>> _add = <List<_Range>>[
  [[3, 12], [2, 9]],
  [[10, 40], [5, 19]],
  [[20, 99], [11, 99]],
  [[30, 199], [20, 99]],
  [[100, 499], [25, 199]],
  [[100, 999], [100, 499]],
  [[200, 999], [150, 999]],
  [[300, 1999], [200, 999]],
  [[1000, 4999], [300, 2999]],
];

const List<List<_Range>> _mul = <List<_Range>>[
  [[2, 5], [2, 9]],
  [[3, 9], [3, 9]],
  [[4, 12], [4, 12]],
  [[12, 49], [3, 9]],
  [[12, 99], [3, 9]],
  [[11, 25], [11, 25]],
  [[12, 39], [11, 29]],
  [[21, 59], [12, 49]],
  [[100, 300], [11, 29]],
];

// [divisor range, quotient range]. Level 0 reuses level 1.
const List<List<_Range>> _div = <List<_Range>>[
  [[2, 5], [2, 9]],
  [[2, 5], [2, 9]],
  [[3, 12], [3, 12]],
  [[4, 12], [10, 30]],
  [[6, 15], [12, 40]],
  [[7, 19], [15, 60]],
  [[7, 29], [20, 99]],
  [[12, 39], [20, 99]],
  [[13, 49], [30, 199]],
];

// Base range by level. Levels 0..3 reuse level 4.
const List<_Range> _sq = <_Range>[
  [11, 15],
  [11, 15],
  [11, 15],
  [11, 15],
  [11, 15],
  [12, 25],
  [16, 30],
  [21, 40],
  [25, 55],
];

class _PctConfig {
  const _PctConfig(this.percents, this.lo, this.hi);
  final List<int> percents;
  final int lo;
  final int hi;
}

// Levels 0..2 reuse level 3.
const List<_PctConfig> _pct = <_PctConfig>[
  _PctConfig([10, 50, 25], 40, 400),
  _PctConfig([10, 50, 25], 40, 400),
  _PctConfig([10, 50, 25], 40, 400),
  _PctConfig([10, 50, 25], 40, 400),
  _PctConfig([10, 20, 25, 50, 75, 5], 40, 400),
  _PctConfig([5, 10, 15, 20, 25, 30, 40, 60, 75], 60, 600),
  _PctConfig([5, 12, 15, 35, 45, 55, 65, 80, 90], 100, 800),
  _PctConfig([12, 15, 35, 45, 55, 65, 80, 85], 100, 1200),
  _PctConfig([12, 17, 35, 45, 55, 65, 85, 95], 200, 2000),
];

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

Category _pickCategory(Mulberry32 rng, Map<Category, int> weights) {
  int total = 0;
  for (final int w in weights.values) {
    total += w;
  }
  double r = rng.next() * total;
  for (final MapEntry<Category, int> e in weights.entries) {
    r -= e.value;
    if (r < 0) return e.key;
  }
  return Category.add;
}

/// Builds one question. The order of every `rng` call matches the prototype,
/// so a seed gives the same sequence in both.
Question generateQuestion(Mulberry32 rng, int level) {
  final int lvl = clampInt(level, 0, 8);
  final Category cat = _pickCategory(rng, _weights[lvl < 5 ? lvl : 5]);

  switch (cat) {
    case Category.add:
    case Category.sub:
      {
      final List<_Range> r = _add[lvl];
      int a = rng.range(r[0][0], r[0][1]);
      int b = rng.range(r[1][0], r[1][1]);
      if (cat == Category.add) {
        return Question(text: '$a + $b', answer: a + b, category: cat);
      }
      if (a < b) {
        final int t = a;
        a = b;
        b = t;
      }
      if (a == b) a += rng.range(1, 9);
      return Question(text: '$a − $b', answer: a - b, category: cat);
      }

    case Category.mul:
      {
      final List<_Range> r = _mul[lvl];
      final int a = rng.range(r[0][0], r[0][1]);
      final int b = rng.range(r[1][0], r[1][1]);
      String? key;
      if (a <= 12 && b <= 12) {
        key = '${a < b ? a : b}×${a < b ? b : a}';
      }
      return Question(
        text: '$a × $b',
        answer: a * b,
        category: cat,
        factKey: key,
      );
      }

    case Category.div:
      {
      final List<_Range> r = _div[lvl];
      final int b = rng.range(r[0][0], r[0][1]);
      final int q = rng.range(r[1][0], r[1][1]);
      return Question(
        text: '${b * q} ÷ $b',
        answer: q,
        category: cat,
        factKey: b <= 12 ? '÷$b' : null,
      );
      }

    case Category.pct:
      {
      final _PctConfig cfg = _pct[lvl];
      final int p = cfg.percents[rng.range(0, cfg.percents.length - 1)];
      final int step = 100 ~/ _gcd(p, 100);
      final int k = rng.range((cfg.lo + step - 1) ~/ step, cfg.hi ~/ step);
      final int n = step * k;
      return Question(
        text: '$p% of $n',
        answer: p * n ~/ 100,
        category: cat,
        factKey: '$p%',
      );
      }

    case Category.sq:
      {
      final _Range r = _sq[lvl];
      final int m = rng.range(r[0], r[1]);
      return Question(
        text: '$m²',
        answer: m * m,
        category: cat,
        factKey: '$m²',
      );
      }
  }
}
