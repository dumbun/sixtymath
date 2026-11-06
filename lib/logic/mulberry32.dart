/// Seeded random numbers, bit-for-bit identical to the prototype's
/// `mulberry32`. The daily challenge and friend challenges depend on every
/// device (and the server) producing the same questions from the same seed.
class Mulberry32 {
  Mulberry32(int seed) : _a = seed & _mask;

  static const int _mask = 0xFFFFFFFF;
  int _a;

  /// 32-bit unsigned multiply that never overflows a double, so it also
  /// behaves on Flutter web.
  static int _imul(int x, int y) {
    final int a = x & _mask;
    final int b = y & _mask;
    final int ah = a >> 16;
    final int al = a & 0xFFFF;
    final int hi = ((ah * (b & 0xFFFF)) & 0xFFFF) * 65536;
    return (al * b + hi) & _mask;
  }

  /// Next value in [0, 1).
  double next() {
    _a = (_a + 0x6D2B79F5) & _mask;
    int t = _imul(_a ^ (_a >> 15), 1 | _a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & _mask) ^ t;
    return ((t ^ (t >> 14)) & _mask) / 4294967296;
  }

  /// Whole number in [lo, hi], both included.
  int range(int lo, int hi) => lo + (next() * (hi - lo + 1)).floor();
}
