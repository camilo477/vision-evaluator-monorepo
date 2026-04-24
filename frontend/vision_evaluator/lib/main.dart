import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const VisionEvaluatorApp());
}

class VisionEvaluatorApp extends StatelessWidget {
  const VisionEvaluatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4F46E5);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vision Evaluator',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        canvasColor: const Color(0xFF070B14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFF1F2937), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerColor: const Color(0xFF1F2937),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Color(0xFFCBD5E1),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF94A3B8),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            minimumSize: const Size.fromHeight(58),
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF0F172A),
          selectedColor: const Color(0xFF312E81),
          disabledColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFF334155)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF111827),
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
