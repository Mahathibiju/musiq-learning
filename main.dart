import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musiq_learning/screens/learning_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure Android system navigation and status bar harmonize with dark charcoal theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0E0E12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MusiqLearningApp());
}

class MusiqLearningApp extends StatelessWidget {
  const MusiqLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Musiq Learning',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF7CE46),
          secondary: Color(0xFFD4E767),
          surface: Color(0xFF18191E),
          onSurface: Colors.white,
        ),
      ),
      home: const LearningHomeScreen(),
    );
  }
}

