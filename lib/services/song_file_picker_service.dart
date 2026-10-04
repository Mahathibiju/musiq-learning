import 'package:flutter/services.dart';
import 'package:musiq_learning/models/song_track.dart';

class SongFilePickerService {
  static const MethodChannel _channel = MethodChannel('musiq_learning/song_files');

  Future<SongFile?> pickAudioFile() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickAudioFile',
    );
    if (result == null) return null;
    return SongFile(
      path: result['path']! as String,
      fileName: result['fileName']! as String,
      mimeType: result['mimeType'] as String? ?? 'application/octet-stream',
      duration: Duration(milliseconds: result['durationMs'] as int? ?? 0),
    );
  }
}
