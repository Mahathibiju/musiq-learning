class SongFile {
  final String path;
  final String fileName;
  final String mimeType;
  final Duration duration;

  const SongFile({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.duration,
  });
}

class VocalStem {
  final String path;
  final Duration duration;
  final String? analysisUrl;

  const VocalStem({
    required this.path,
    required this.duration,
    this.analysisUrl,
  });
}

class InstrumentalTrack {
  final String path;
  final Duration duration;

  const InstrumentalTrack({required this.path, required this.duration});
}

class SeparatedSong {
  final VocalStem vocalStem;
  final InstrumentalTrack instrumental;

  const SeparatedSong({required this.vocalStem, required this.instrumental});
}
