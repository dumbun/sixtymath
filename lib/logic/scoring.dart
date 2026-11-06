/// Combo multiplier: x1 for 0-4 in a row, x2 for 5-9, x3 from 10.
int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

int multiplierFor(int combo) => 1 + clampInt(combo ~/ 5, 0, 2);

class Tier {
  const Tier(this.name, this.minRating);
  final String name;
  final int minRating;
}

const List<Tier> tiers = <Tier>[
  Tier('Bronze', 400),
  Tier('Silver', 1000),
  Tier('Gold', 1400),
  Tier('Platinum', 1800),
  Tier('Diamond', 2200),
];

int tierIndexFor(int rating) {
  int index = 0;
  for (int i = 0; i < tiers.length; i++) {
    if (rating >= tiers[i].minRating) index = i;
  }
  return index;
}

/// Difficulty level (0..8) a given rating starts at.
int levelForRating(int rating) => clampInt((rating - 400) ~/ 250, 0, 8);

/// Score that holds the rating steady at a given rating.
double parFor(int rating) {
  final double steps = (rating - 400) / 250;
  return 34 - 2 * (steps < 0 ? 0 : steps);
}

/// Rounds half up, like JavaScript's Math.round, so results match the
/// prototype for negative values too.
int _roundHalfUp(double x) => (x + 0.5).floor();

int ratingDelta(int score, int rating) =>
    clampInt(_roundHalfUp((score - parFor(rating)) * 1.5), -20, 45);

/// Share of the way from this tier to the next, 0..1. Top tier is always 1.
double tierProgress(int rating) {
  final int i = tierIndexFor(rating);
  if (i + 1 >= tiers.length) return 1;
  final int lo = tiers[i].minRating;
  final int hi = tiers[i + 1].minRating;
  final double share = (rating - lo) / (hi - lo);
  return share < 0 ? 0 : (share > 1 ? 1 : share);
}
