import 'package:musiq_learning/models/pitch_point.dart';
import 'package:musiq_learning/models/song_section.dart';

class PracticeResult {
  final String sectionId;
  final List<PitchPoint> userPitch;
  final SongFeedbackLevel feedback;
  final DateTime completedAt;

  const PracticeResult({
    required this.sectionId,
    required this.userPitch,
    required this.feedback,
    required this.completedAt,
  });
}
