import 'package:musiq_learning/models/pitch_point.dart';
import 'package:musiq_learning/models/song_section.dart';
import 'package:musiq_learning/services/song_separation_service.dart';

abstract interface class SongSectionService {
  Future<List<SongSection>> identifySections({
    required List<PitchPoint> vocalReferencePitch,
    String? lyrics,
  });
}

class UnconfiguredSongSectionService implements SongSectionService {
  const UnconfiguredSongSectionService();

  @override
  Future<List<SongSection>> identifySections({
    required List<PitchPoint> vocalReferencePitch,
    String? lyrics,
  }) =>
      throw const SongIntegrationUnavailable(
        'Musical phrase detection will be available with the song-analysis engine.',
      );
}
