import 'analysis.dart';

enum RoundMode { sprint, daily }

/// What a finished round produced.
class RoundResult {
  const RoundResult({
    required this.mode,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.maxCombo,
    required this.log,
  });

  final RoundMode mode;
  final int score;
  final int correct;
  final int wrong;
  final int skipped;
  final int maxCombo;
  final List<LogEntry> log;

  int get attempts => correct + wrong + skipped;
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  Analysis get analysis => analyse(log);
  List<LogEntry> get misses =>
      log.where((LogEntry e) => !e.ok).toList(growable: false);
}
