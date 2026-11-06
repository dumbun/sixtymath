import 'package:flutter/material.dart';

import 'state/progress.dart';
import 'theme/tokens.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState state = AppState(MemoryProgressStore());
  await state.load();
  runApp(SixtyMathApp(state: state));
}

class SixtyMathApp extends StatelessWidget {
  const SixtyMathApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'SixtyMath',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: Tokens.light.toTheme(Brightness.light),
        darkTheme: Tokens.dark.toTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
