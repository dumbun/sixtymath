import 'question.dart';

class LogEntry {
  const LogEntry({
    required this.question,
    required this.ms,
    required this.ok,
    this.skipped = false,
    this.typed = '',
  });

  final Question question;
  final double ms;
  final bool ok;
  final bool skipped;
  final String typed;
}

class CategoryStat {
  const CategoryStat({
    required this.category,
    required this.correct,
    required this.missed,
    required this.avgMs,
  });

  final Category category;
  final int correct;
  final int missed;

  /// Average time of correct answers, null when none were correct.
  final double? avgMs;
}

class Analysis {
  const Analysis({
    required this.rows,
    required this.overallMs,
    required this.slowCategory,
    required this.slowFacts,
  });

  final List<CategoryStat> rows;
  final double overallMs;
  final Category? slowCategory;
  final List<String> slowFacts;
}

Analysis analyse(List<LogEntry> log) {
  final Map<Category, List<double>> times = <Category, List<double>>{};
  final Map<Category, int> misses = <Category, int>{};
  double totalMs = 0;
  int totalCorrect = 0;

  for (final LogEntry e in log) {
    final Category c = e.question.category;
    if (e.ok) {
      times.putIfAbsent(c, () => <double>[]).add(e.ms);
      totalMs += e.ms;
      totalCorrect++;
    } else {
      misses[c] = (misses[c] ?? 0) + 1;
    }
  }

  final double overall = totalCorrect == 0 ? 0 : totalMs / totalCorrect;

  final Set<Category> seen = <Category>{...times.keys, ...misses.keys};
  final List<CategoryStat> rows = <CategoryStat>[
    for (final Category c in seen)
      CategoryStat(
        category: c,
        correct: times[c]?.length ?? 0,
        missed: misses[c] ?? 0,
        avgMs: times[c] == null
            ? null
            : times[c]!.reduce((double a, double b) => a + b) /
                times[c]!.length,
      ),
  ];
  rows.sort((CategoryStat a, CategoryStat b) =>
      (b.avgMs ?? -1).compareTo(a.avgMs ?? -1));

  Category? slow;
  for (final CategoryStat r in rows) {
    if (slow == null &&
        r.avgMs != null &&
        r.correct >= 2 &&
        r.avgMs! > overall * 1.25) {
      slow = r.category;
    }
  }

  final Map<String, int> facts = <String, int>{};
  final double slowCut = overall * 1.6 > 2500 ? overall * 1.6 : 2500;
  for (final LogEntry e in log) {
    final String? key = e.question.factKey;
    if (key == null) continue;
    final bool slowAnswer = e.ok && overall > 0 && e.ms > slowCut;
    if (!e.ok || slowAnswer) {
      facts[key] = (facts[key] ?? 0) + (e.ok ? 1 : 2);
    }
  }
  final List<String> top = facts.keys.toList()
    ..sort((String a, String b) => facts[b]!.compareTo(facts[a]!));

  return Analysis(
    rows: rows,
    overallMs: overall,
    slowCategory: slow,
    slowFacts: top.take(5).toList(),
  );
}
