import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musiq_learning/screens/learning_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure Android system navigation and status bars match the #0B0C0F background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0C0F),
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
        scaffoldBackgroundColor: const Color(0xFF0B0C0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD21F),
          secondary: Color(0xFFD9E86C),
          surface: Color(0xFF17181C),
          onSurface: Color(0xFFFFFFFF),
        ),
      ),
      home: const LearningHomeScreen(),
    );
  }
}
