import 'package:flutter/material.dart';
import 'package:musiq_learning/models/song_section.dart';

class SongSectionCard extends StatelessWidget {
  final SongSection section;
  final VoidCallback onTap;

  const SongSectionCard({
    super.key,
    required this.section,
    required this.onTap,
  });

  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA7A7A7);

  @override
  Widget build(BuildContext context) {
    final feedback = section.feedback;
    final feedbackColor = switch (feedback) {
      SongFeedbackLevel.excellent => const Color(0xFFD9E86C),
      SongFeedbackLevel.good => const Color(0xFF79D8C5),
      SongFeedbackLevel.almostThere => const Color(0xFFFFD21F),
      SongFeedbackLevel.keepGoing => const Color(0xFFB9A1FF),
      null => muted,
    };
    return Card(
      color: const Color(0xFF17181C),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFF292B33)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: const BoxDecoration(
                  color: Color(0xFF25251B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  section.title.replaceAll(RegExp(r'[^0-9]'), ''),
                  style: const TextStyle(
                    color: Color(0xFFFFD21F),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.lyrics?.trim().isNotEmpty == true
                          ? section.lyrics!
                          : section.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_time(section.start)} – ${_time(section.end)}  ·  ${section.duration.inSeconds}s',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (feedback != null) ...[
                const SizedBox(width: 7),
                Icon(Icons.stars_rounded, color: feedbackColor, size: 17),
                const SizedBox(width: 4),
                Text(
                  feedbackTitle(feedback),
                  style: TextStyle(
                    color: feedbackColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else
                const Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}
