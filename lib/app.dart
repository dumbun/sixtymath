import 'package:flutter/material.dart';

import 'features/home/presentation/home_screen.dart';
import 'theme/tokens.dart';

class SixtyMathApp extends StatelessWidget {
  const SixtyMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SixtyMath',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: Tokens.light.toTheme(Brightness.light),
      darkTheme: Tokens.dark.toTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
