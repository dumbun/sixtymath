import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/progress.dart';
import '../../../core/round_result.dart';
import '../../../core/scoring.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets.dart';
import '../../../theme/tokens.dart';
import '../../play/presentation/play_screen.dart';
import 'widgets/start_dial.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static void _play(BuildContext context, RoundMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      builder: (BuildContext context, bool wide) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double dial = math.max(
              170.0,
              math.min(
                250.0,
                math.min(
                  box.maxWidth * (wide ? 0.4 : 0.62),
                  box.maxHeight * (wide ? 0.7 : 0.32),
                ),
              ),
            );
            final Widget startDial = StartDial(
              size: dial,
              onPressed: () => _play(context, RoundMode.sprint),
            );
            final Widget header = const _Header();
            final Widget rank = const _RatingBlock();
            final Widget daily = _DailyCard(
              onPressed: () => _play(context, RoundMode.daily),
            );

            if (wide) {
              return Row(
                children: <Widget>[
                  Expanded(child: Center(child: startDial)),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            header,
                            const SizedBox(height: 18),
                            rank,
                            const SizedBox(height: 16),
                            daily,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 14),
                    Center(child: startDial),
                    const SizedBox(height: 18),
                    rank,
                    const SizedBox(height: 16),
                    daily,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: 'Sixty', style: t.display(24)),
              TextSpan(text: 'Math', style: t.display(24, color: t.pen)),
            ],
          ),
        ),
        const _Toggles(),
      ],
    );
  }
}

/// Sound and haptics switches. Each chip watches only its own flag.
class _Toggles extends ConsumerWidget {
  const _Toggles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool sound = ref.watch(settingsProvider.select((Settings s) => s.sound));
    final bool haptics =
        ref.watch(settingsProvider.select((Settings s) => s.haptics));
    final SettingsNotifier settings = ref.read(settingsProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ToggleChip(label: 'Sound', on: sound, onTap: settings.toggleSound),
        const SizedBox(width: 8),
        _ToggleChip(
          label: 'Haptics',
          on: haptics,
          onTap: settings.toggleHaptics,
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Tokens t = Tokens.of(context);
    return Semantics(
      toggled: on,
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: HardBox(
              radius: 6,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                label.toUpperCase(),
                style: t.mono(11, spacing: 0.9, color: on ? t.ink : t.inkSoft).copyWith(
                      decoration: on ? null : TextDecoration.lineThrough,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingBlock extends ConsumerWidget {
  const _RatingBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Tokens t = Tokens.of(context);
    final Progress p = ref.watch(progressProvider);
    final int streak = ref.watch(streakProvider);
    final int tierIndex = tierIndexFor(p.rating);
    final bool top = tierIndex + 1 >= tiers.length;
    final String toNext = top
        ? 'Top tier'
        : '${tiers[tierIndex + 1].minRating - p.rating} to ${tiers[tierIndex + 1].name}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('RATING', style: t.label()),
                Text('${p.rating}', style: t.mono(40, spacing: -1.2)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(tiers[tierIndex].name, style: t.display(20, spacing: -0.2)),
                Text(toNext.toUpperCase(), style: t.label()),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        MeterBar(value: tierProgress(p.rating)),
        const SizedBox(height: 14),
        StatStrip(items: <(String, String)>[
          ('Best', p.best == 0 ? '–' : '${p.best}'),
          ('Rounds', '${p.rounds}'),
          ('Day streak', '$streak'),
        ]),
      ],
    );
  }
}

class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Tokens t = Tokens.of(context);
    final int? best = ref.watch(dailyBestTodayProvider);
    final DateTime now = ref.read(clockProvider)();
    return PressBox(
      onPressed: onPressed,
      shadow: const Offset(4, 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      semanticLabel: 'Daily challenge',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Daily challenge · ${_dateLabel(now)}',
                  style: t.display(17, spacing: -0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  'Same 60 seconds for everyone',
                  style: TextStyle(fontSize: 13, color: t.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            best == null ? 'Not played' : 'Best $best',
            style: t.mono(13, color: t.pen),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime now) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final DateTime ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${ist.day} ${months[ist.month - 1]}';
}
