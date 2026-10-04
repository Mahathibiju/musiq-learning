import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musiq_learning/models/song_track.dart';
import 'package:musiq_learning/services/song_separation_service.dart';

class SongLyricLine {
  final double start;
  final double end;
  final String text;

  const SongLyricLine({
    required this.start,
    required this.end,
    required this.text,
  });
}

class SongLyrics {
  final List<SongLyricLine> lines;
  final bool cached;
  String get text => lines.map((line) => line.text).join('\n');
  bool get confident => lines.isNotEmpty;

  const SongLyrics({required this.lines, this.cached = false});
}

abstract interface class SongLyricsService {
  Future<SongLyrics> transcribeVocalStem(VocalStem vocalStem);
}

/// Calls the backend's cached Whisper transcription endpoint using only the
/// separated vocal stem URL. No song audio is sent a second time from Android.
class FastApiSongLyricsService implements SongLyricsService {
  const FastApiSongLyricsService();

  @override
  Future<SongLyrics> transcribeVocalStem(VocalStem vocalStem) async {
    final vocalUrl = vocalStem.analysisUrl;
    if (vocalUrl == null || vocalUrl.isEmpty) {
      throw const SongIntegrationUnavailable(
        'The vocal stem has no backend URL. Separate the song again to transcribe its lyrics.',
      );
    }
    final baseUri = Uri.parse(FastApiSongSeparationService.backendBaseUrl);
    final endpoint = baseUri.replace(
      path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/transcribe-vocal',
      query: null,
      fragment: null,
    );
    final client = http.Client();
    try {
      final response = await client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'vocal_url': vocalUrl}),
          )
          .timeout(const Duration(minutes: 30));
      final decoded = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map<String, dynamic> ||
          decoded['success'] != true) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']?.toString()
            : response.body;
        throw SongIntegrationUnavailable(
          'Vocal transcription failed (${response.statusCode}): ${detail ?? response.body}',
        );
      }
      final rawLines = decoded['lyrics'];
      if (rawLines is! List) {
        throw const SongIntegrationUnavailable(
          'The transcription response did not contain timestamped lyrics.',
        );
      }
      final lines = <SongLyricLine>[];
      for (final raw in rawLines) {
        if (raw is! Map<String, dynamic> ||
            raw['start'] is! num ||
            raw['end'] is! num ||
            raw['text'] is! String) {
          throw const SongIntegrationUnavailable(
            'The backend returned an invalid timestamped lyric line.',
          );
        }
        final start = (raw['start'] as num).toDouble();
        final end = (raw['end'] as num).toDouble();
        final text = (raw['text'] as String).trim();
        if (start.isFinite && end > start && text.isNotEmpty) {
          lines.add(SongLyricLine(start: start, end: end, text: text));
        }
      }
      return SongLyrics(
        lines: List.unmodifiable(lines),
        cached: decoded['cached'] == true,
      );
    } on TimeoutException catch (error) {
      throw SongIntegrationUnavailable(
        'Lyrics transcription timed out. ($error)',
      );
    } on http.ClientException catch (error) {
      throw SongIntegrationUnavailable(
        'Could not reach the transcription backend. ($error)',
      );
    } on FormatException catch (error) {
      throw SongIntegrationUnavailable(
        'The transcription backend returned invalid data. ($error)',
      );
    } finally {
      client.close();
    }
  }
}
