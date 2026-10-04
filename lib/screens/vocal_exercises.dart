import 'package:flutter/material.dart';
import 'package:musiq_learning/screens/exercise_detail.dart';

/// The Vocal Exercises screen featuring four large exercise category cards:
/// 1. Chest Voice
/// 2. Head Voice
/// 3. Mixed Voice
/// 4. Swaras
class VocalExercisesScreen extends StatelessWidget {
  const VocalExercisesScreen({super.key});

  static const Color appBackground = Color(0xFF0B0C0F);
  static const Color darkCardBg = Color(0xFF17181C);
  static const Color cardBorderColor = Color(0xFF262830);
  static const Color primaryYellow = Color(0xFFFFD21F);
  static const Color secondaryLime = Color(0xFFD9E86C);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);
  static const Color iconContainerBg = Color(0xFF22242B);

  // The 4 core vocal exercise categories
  static const List<VocalExerciseCategory> categories = [
    VocalExerciseCategory(
      name: 'Chest Voice',
      description: 'Build strength and control in the lower register.',
      icon: Icons.record_voice_over_rounded,
      tag: 'LOWER REGISTER',
    ),
    VocalExerciseCategory(
      name: 'Head Voice',
      description: 'Develop control and stability in the upper register.',
      icon: Icons.graphic_eq_rounded,
      tag: 'UPPER REGISTER',
    ),
    VocalExerciseCategory(
      name: 'Mixed Voice',
      description: 'Practice connecting chest and head voice smoothly.',
      icon: Icons.sync_alt_rounded,
      tag: 'BLENDED REGISTER',
    ),
    VocalExerciseCategory(
      name: 'Swaras',
      description:
          'Practice Sa Re Ga Ma Pa and ascending/descending patterns.',
      icon: Icons.queue_music_rounded,
      tag: 'CLASSICAL SCALES',
    ),
  ];

  void _openExerciseDetail(
      BuildContext context, VocalExerciseCategory exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vocal Exercises',
          style: TextStyle(
            color: textWhite,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen header
              const Text(
                'VOICE TRAINING',
                style: TextStyle(
                  color: secondaryLime,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select Category',
                style: TextStyle(
                  color: textWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Train your vocal registers and pitch dexterity with structured exercises.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // The 4 Vocal Exercise Category Cards
              ...categories.map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: darkCardBg,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: cardBorderColor,
                        width: 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openExerciseDetail(context, exercise),
                      borderRadius: BorderRadius.circular(26),
                      child: Padding(
                        padding: const EdgeInsets.all(22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Icon + Category Tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: iconContainerBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    exercise.icon,
                                    size: 24,
                                    color: primaryYellow,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: iconContainerBg,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: const Color(0xFF2E313A),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    exercise.tag,
                                    style: const TextStyle(
                                      color: secondaryLime,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Exercise Name
                            Text(
                              exercise.name,
                              style: const TextStyle(
                                color: textWhite,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Short Description
                            Text(
                              exercise.description,
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Action: Pill-shaped "Practice" button
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _openExerciseDetail(context, exercise),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryYellow,
                                  foregroundColor: buttonText,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 11,
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 17,
                                  color: buttonText,
                                ),
                                label: const Text(
                                  'PRACTICE',
                                  style: TextStyle(
                                    color: buttonText,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Bottom clearance
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

