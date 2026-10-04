import 'package:musiq_learning/models/pitch_point.dart';

enum SongFeedbackLevel { excellent, good, almostThere, keepGoing }

class SongSection {
  final String id;
  final String title;
  final String? lyrics;
  final Duration start;
  final Duration end;
  final List<PitchPoint> referencePitch;
  final List<PitchPoint> userPitch;
  final SongFeedbackLevel? feedback;

  const SongSection({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.lyrics,
    this.referencePitch = const [],
    this.userPitch = const [],
    this.feedback,
  });

  Duration get duration => end - start;
}

String feedbackTitle(SongFeedbackLevel level) => switch (level) {
      SongFeedbackLevel.excellent => 'Excellent!',
      SongFeedbackLevel.good => 'Good!',
      SongFeedbackLevel.almostThere => 'Almost There!',
      SongFeedbackLevel.keepGoing => 'Keep Going!',
    };

String feedbackMessage(SongFeedbackLevel level) => switch (level) {
      SongFeedbackLevel.excellent =>
        'Your pitch closely follows the original.',
      SongFeedbackLevel.good =>
        'Your melody is following the original nicely.',
      SongFeedbackLevel.almostThere =>
        "You're very close — a little more practice will make this section even smoother.",
      SongFeedbackLevel.keepGoing =>
        "You're building consistency with every attempt.",
    };
