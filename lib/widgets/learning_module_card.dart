import 'package:flutter/material.dart';

/// A premium, dark-mode module card adhering strictly to the Musiq design system.
/// Features a dark card surface (#17181C), 30px rounded corners, crisp borders,
/// bold typography, minimal circular icon, and a pill-shaped start button (#FFD21F).
class LearningModuleCard extends StatelessWidget {
  final IconData icon;
  final String? tag;
  final String title;
  final String subtitle;
  final String? highlightBadge;
  final VoidCallback onStart;

  const LearningModuleCard({
    super.key,
    required this.icon,
    this.tag,
    required this.title,
    required this.subtitle,
    this.highlightBadge,
    required this.onStart,
  });

  // Design system constants
  static const Color darkCardBg = Color(0xFF17181C);
  static const Color cardBorderColor = Color(0xFF262830);
  static const Color primaryYellow = Color(0xFFFFD21F);
  static const Color secondaryLime = Color(0xFFD9E86C);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);
  static const Color iconContainerBg = Color(0xFF22242B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: cardBorderColor,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(26.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Minimal circular icon + Tag pill (if present)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: iconContainerBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: primaryYellow,
                    ),
                  ),
                  if (tag != null && tag!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
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
                        tag!,
                        style: const TextStyle(
                          color: secondaryLime,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Title: Bold modern typography
              Text(
                title,
                style: const TextStyle(
                  color: textWhite,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle: Core drill focus
              Text(
                subtitle,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  letterSpacing: 0.2,
                ),
              ),

              // Optional highlight badge (e.g. Sa Re Ga Ma Pa)
              if (highlightBadge != null && highlightBadge!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: iconContainerBg,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: secondaryLime.withAlpha(90),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.music_note_rounded,
                        size: 15,
                        color: secondaryLime,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        highlightBadge!,
                        style: const TextStyle(
                          color: secondaryLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // Pill-shaped START button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryYellow,
                    foregroundColor: buttonText,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 13,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: buttonText,
                  ),
                  label: const Text(
                    'START',
                    style: TextStyle(
                      color: buttonText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
