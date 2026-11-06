import 'package:flutter_test/flutter_test.dart';
import 'package:sixtymath/main.dart';
import 'package:sixtymath/state/progress.dart';

void main() {
  testWidgets('home shows the dial, rating and daily card', (tester) async {
    final AppState state = AppState(MemoryProgressStore());
    await tester.pumpWidget(SixtyMathApp(state: state));
    await tester.pump();

    expect(find.text('START SPRINT'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.textContaining('Daily challenge'), findsOneWidget);
  });

  testWidgets('tapping the dial opens the countdown', (tester) async {
    final AppState state = AppState(MemoryProgressStore());
    await tester.pumpWidget(SixtyMathApp(state: state));
    await tester.tap(find.text('START SPRINT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
  });
}
