import 'package:musiq_learning/models/pitch_point.dart';
import 'package:musiq_learning/models/song_section.dart';

class SongAnalysis {
  /// These points must be extracted from the isolated vocal stem only.
  final List<PitchPoint> referenceVocalPitch;
  final List<SongSection> sections;
  final String? lyrics;
  final bool lyricsConfident;

  const SongAnalysis({
    required this.referenceVocalPitch,
    this.sections = const [],
    this.lyrics,
    this.lyricsConfident = false,
  });
}
