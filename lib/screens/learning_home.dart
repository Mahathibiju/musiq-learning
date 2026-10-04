import 'package:flutter/material.dart';
import 'package:musiq_learning/screens/breathing_lab.dart';
import 'package:musiq_learning/screens/learn_song.dart';
import 'package:musiq_learning/screens/vocal_exercises.dart';
import 'package:musiq_learning/widgets/learning_module_card.dart';

/// The Musiq Learning dashboard screen rendered with the exact design system:
/// deep black background (#0B0C0F), dark cards (#17181C), primary yellow (#FFD21F),
/// secondary lime (#D9E86C), and high-contrast typography.
class LearningHomeScreen extends StatelessWidget {
  const LearningHomeScreen({super.key});

  static const Color appBackground = Color(0xFF0B0C0F);
  static const Color primaryYellow = Color(0xFFFFD21F);
  static const Color secondaryLime = Color(0xFFD9E86C);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: primaryYellow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 19,
                color: buttonText,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'MUSIQ',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              const Text(
                'PRACTICE MODULES',
                style: TextStyle(
                  color: secondaryLime,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Master Your Voice',
                style: TextStyle(
                  color: textWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a module to build vocal range, breath stamina, and pitch accuracy.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // 1. VOCAL EXERCISES
              LearningModuleCard(
                icon: Icons.mic_rounded,
                tag: 'MODULE 01',
                title: 'Vocal Exercises',
                subtitle: 'Chest Voice • Head Voice • Mixed Voice',
                highlightBadge: 'Sa Re Ga Ma Pa',
                onStart: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VocalExercisesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 2. BREATHING EXERCISES
              LearningModuleCard(
                icon: Icons.air_rounded,
                tag: 'MODULE 02',
                title: 'Breathing Exercises',
                subtitle: 'Breath Control • Stamina',
                onStart: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BreathingLabScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // SONG STUDIO: singing analysis and practice live in its workspace.
              LearningModuleCard(
                icon: Icons.library_music_rounded,
                tag: 'SONG STUDIO',
                title: 'Learn a Song',
                subtitle:
                    'Turn any song into a personal vocal practice session.',
                onStart: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LearnSongScreen(),
                    ),
                  );
                },
              ),

              // Bottom padding for mobile gesture navigation bar
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
