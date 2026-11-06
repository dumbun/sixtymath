import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/round_controller.dart';
import '../logic/analysis.dart';
import '../logic/question.dart';
import '../logic/scoring.dart';
import '../state/progress.dart';
import '../theme/tokens.dart';
import 'play_screen.dart';
import 'widgets.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.summary});

  final RoundSummary summary;

  RoundResult get _r => summary.result;

  void _retry(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => PlayScreen(mode: _r.mode)),
    );
  }

  Future<void> _share(BuildContext context) async {
    final Progress p = summary.current;
    final String text = summary.isSprint
        ? 'SixtyMath: I scored ${_r.score} in 60 seconds '
            '(${tiers[tierIndexFor(p.rating)].name} ${p.rating}). '
            'Think you can beat it?'
        : 'SixtyMath daily: I scored ${_r.score}. Same questions for '
            'everyone. Beat me in 60 seconds.';
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(content: Text('Copied. Paste it in your group chat.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    final Analysis an = _r.analysis;
    final Progress cur = summary.current;

    final String bestLine;
    Color bestColor = t.ink;
    if (!summary.isSprint) {
      bestLine = 'Today’s best ${cur.dailyBest}';
    } else if (summary.previous.best == 0) {
      bestLine = 'First score on the board';
      bestColor = t.ok;
    } else if (summary.newBest) {
      bestLine = 'New best! Was ${summary.previous.best}';
      bestColor = t.ok;
    } else if (_r.score == summary.previous.best) {
      bestLine = 'Matched your best';
    } else {
      bestLine = 'Your best is ${cur.best}. ${cur.best - _r.score} to beat it.';
    }

    final String retrySub = !summary.isSprint
        ? 'Same questions, one more go'
        : (cur.best > 0 ? 'Beat ${cur.best}' : 'One more sprint');

    return PaperScaffold(
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              children: <Widget>[
                Text(
                  summary.isSprint ? 'SPRINT COMPLETE' : 'DAILY CHALLENGE',
                  style: t.label(),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('${_r.score}', style: t.mono(104, spacing: -6, height: 0.85)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('SCORE', style: t.label()),
                          const SizedBox(height: 6),
                          Text(bestLine, style: t.mono(15, color: bestColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (summary.isSprint) ..._ratingBlock(t),
                StatStrip(items: <(String, String)>[
                  ('Correct', '${_r.correct}'),
                  ('Accuracy', _r.attempts == 0 ? '–' : '${(_r.accuracy * 100).round()}%'),
                  ('Avg time', an.overallMs == 0 ? '–' : '${(an.overallMs / 1000).toStringAsFixed(1)}s'),
                  ('Combo', '${_r.maxCombo}'),
                ]),
                const SizedBox(height: 18),
                Text('WEAK SPOTS', style: t.label()),
                const SizedBox(height: 10),
                ..._weakSpots(t, an),
                const SizedBox(height: 18),
                Text('MISSED THIS ROUND', style: t.label()),
                const SizedBox(height: 6),
                ..._misses(t),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.edge, width: 2)),
            ),
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: Column(
              children: <Widget>[
                PressBox(
                  onPressed: () => _retry(context),
                  color: t.pen,
                  radius: 10,
                  shadow: const Offset(0, 5),
                  semanticLabel: 'Retry',
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: <Widget>[
                        Text('Retry', style: t.display(28, color: t.onPen)),
                        const SizedBox(height: 2),
                        Text(
                          retrySub,
                          style: t.mono(12, weight: FontWeight.w500, color: t.onPen),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PressBox(
                        onPressed: () => _share(context),
                        shadow: const Offset(0, 3),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        semanticLabel: 'Challenge a friend',
                        child: Center(
                          child: Text('Challenge a friend', style: t.display(15, spacing: 0)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PressBox(
                        onPressed: () =>
                            Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst),
                        shadow: const Offset(0, 3),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        semanticLabel: 'Home',
                        child: Center(
                          child: Text('Home', style: t.display(15, spacing: 0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ratingBlock(Tokens t) {
    final Progress cur = summary.current;
    final int i = tierIndexFor(cur.rating);
    final bool top = i + 1 >= tiers.length;
    final int delta = summary.ratingDelta;
    return <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Rating ${summary.previous.rating} → ${cur.rating}',
            style: t.mono(15),
          ),
          Text(
            '${delta >= 0 ? '+' : ''}$delta',
            style: t.mono(15, color: delta >= 0 ? t.ok : t.bad),
          ),
        ],
      ),
      const SizedBox(height: 8),
      MeterBar(value: tierProgress(cur.rating)),
      const SizedBox(height: 6),
      Text(
        '${tiers[i].name}${top ? ' · Top tier' : ' · ${tiers[i + 1].minRating - cur.rating} to ${tiers[i + 1].name}'}'
            '${summary.tierUp ? ' · Tier up' : ''}'
            .toUpperCase(),
        style: t.label(),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _weakSpots(Tokens t, Analysis an) {
    if (an.rows.isEmpty) {
      return <Widget>[
        Text('No answers this round.', style: TextStyle(color: t.inkSoft)),
      ];
    }
    double maxAvg = 1;
    for (final CategoryStat s in an.rows) {
      if (s.avgMs != null && s.avgMs! > maxAvg) maxAvg = s.avgMs!;
    }
    return <Widget>[
      for (final CategoryStat s in an.rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 76,
                child: Text(
                  s.category.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: MeterBar(
                  value: s.avgMs == null ? 0 : s.avgMs! / maxAvg,
                  color: s.category == an.slowCategory ? t.bad : t.inkSoft,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  s.avgMs == null ? 'missed' : '${(s.avgMs! / 1000).toStringAsFixed(1)}s',
                  textAlign: TextAlign.right,
                  style: t.mono(
                    13,
                    color: s.category == an.slowCategory ? t.bad : t.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      Text(
        an.slowCategory != null
            ? 'Slowest on ${an.slowCategory!.label.toLowerCase()}. Drill it with Pro.'
            : 'Even pace across every type. Nothing stands out.',
        style: TextStyle(fontSize: 14, color: t.inkSoft),
      ),
      if (an.slowFacts.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final String f in an.slowFacts)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: t.bad, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(f, style: t.mono(13, color: t.bad)),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _misses(Tokens t) {
    final List<LogEntry> misses = _r.misses;
    if (misses.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text('Clean sprint · 0 misses', style: t.mono(14)),
        ),
      ];
    }
    return <Widget>[
      for (final LogEntry e in misses.take(6))
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(e.question.text, style: t.mono(14)),
                    Text(
                      e.skipped ? 'skipped' : 'you typed ${e.typed}',
                      style: t.mono(12, weight: FontWeight.w500, color: t.inkSoft),
                    ),
                  ],
                ),
              ),
              Text('= ${e.question.answer}', style: t.mono(14)),
            ],
          ),
        ),
      if (misses.length > 6)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '+${misses.length - 6} more',
            style: t.mono(12, weight: FontWeight.w500, color: t.inkSoft),
          ),
        ),
    ];
  }
}
