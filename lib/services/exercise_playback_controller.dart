import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:musiq_learning/models/musical_note.dart';
import 'package:musiq_learning/services/tone_generator.dart';

enum PlaybackStatus {
  idle,
  playing,
  paused,
}

/// Coordinates sequential audio playback of musical notes and swaras,
/// notifying listeners of the currently active note index for visual synchronization.
class ExercisePlaybackController {
  final AudioPlayer _audioPlayer = AudioPlayer();

  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackStatus get status => _status;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isPaused => _status == PlaybackStatus.paused;

  List<MusicalNote> _notes = [];
  List<MusicalNote> get notes => _notes;

  int _bpm = 75;
  int get bpm => _bpm;

  int? _activeNoteIndex;
  int? get activeNoteIndex => _activeNoteIndex;

  // Stream / Callbacks for UI updates
  void Function(int? index)? onActiveIndexChanged;
  void Function(PlaybackStatus status)? onStatusChanged;

  // Execution control token to immediately abort delays on pause/stop
  int _sessionToken = 0;

  ExercisePlaybackController() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  /// Sets the tempo in beats per minute (BPM).
  void setBpm(int newBpm) {
    if (newBpm >= 40 && newBpm <= 200) {
      _bpm = newBpm;
    }
  }

  /// Starts or restarts playback from the beginning.
  Future<void> start({
    required List<MusicalNote> notes,
    required int bpm,
  }) async {
    if (notes.isEmpty) return;
    await stop();

    _notes = notes;
    _bpm = bpm;
    _status = PlaybackStatus.playing;
    _activeNoteIndex = 0;
    _sessionToken++;

    _notifyStatus();
    _runSequencer(_sessionToken, startIndex: 0);
  }

  /// Plays a reference pitch on a short loop until another playback action
  /// stops it. This reuses the existing player and generated tone path.
  Future<void> playReferenceNote({required double frequencyHz}) async {
    final token = ++_sessionToken;
    _status = PlaybackStatus.idle;
    _activeNoteIndex = null;
    _notifyActiveIndex(null);
    _notifyStatus();

    try {
      await _audioPlayer.stop();
      if (_sessionToken != token) return;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      if (_sessionToken != token) return;

      const durationMs = 1200;
      final bytes = ToneGenerator.generateToneBytes(
        frequencyHz: frequencyHz,
        durationMs: durationMs,
      );
      _notes = [
        MusicalNote(
          symbol: 'Reference',
          frequencyHz: frequencyHz,
          displayLabel: 'Reference',
        ),
      ];
      _status = PlaybackStatus.playing;
      _activeNoteIndex = 0;
      _notifyActiveIndex(0);
      _notifyStatus();
      await _audioPlayer.play(BytesSource(bytes));
    } catch (_) {
      if (_sessionToken == token) {
        _status = PlaybackStatus.idle;
        _activeNoteIndex = null;
        _notifyActiveIndex(null);
        _notifyStatus();
      }
    }
  }

  /// Pauses the current playback, maintaining the current note position.
  Future<void> pause() async {
    if (_status != PlaybackStatus.playing) return;
    _status = PlaybackStatus.paused;
    _sessionToken++;
    await _audioPlayer.stop();
    _notifyStatus();
  }

  /// Resumes playback from the paused note index.
  Future<void> resume() async {
    if (_status != PlaybackStatus.paused) return;
    if (_notes.isEmpty) return;

    final resumeIndex = _activeNoteIndex ?? 0;
    _status = PlaybackStatus.playing;
    _sessionToken++;
    _notifyStatus();
    _runSequencer(_sessionToken, startIndex: resumeIndex);
  }

  /// Stops playback completely and resets note index to null.
  Future<void> stop() async {
    _sessionToken++;
    _status = PlaybackStatus.idle;
    _activeNoteIndex = null;
    await _audioPlayer.stop();
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _notifyActiveIndex(null);
    _notifyStatus();
  }

  /// Internal playback loop that steps through each note synchronously.
  void _runSequencer(int token, {required int startIndex}) async {
    for (int i = startIndex; i < _notes.length; i++) {
      if (_sessionToken != token || _status != PlaybackStatus.playing) {
        return;
      }

      _activeNoteIndex = i;
      _notifyActiveIndex(i);

      final note = _notes[i];
      final int beatDurationMs = (60000.0 / _bpm).round();
      final int noteDurationMs = (beatDurationMs * note.durationBeats).round();
      // Slight 10% articulation release gap between consecutive notes
      final int toneDurationMs = (noteDurationMs * 0.90).round().clamp(50, 10000);

      // Synthesize and play the pitch
      final bytes = ToneGenerator.generateToneBytes(
        frequencyHz: note.frequencyHz,
        durationMs: toneDurationMs,
      );

      try {
        await _audioPlayer.stop();
        if (_sessionToken != token || _status != PlaybackStatus.playing) return;
        await _audioPlayer.play(BytesSource(bytes));
      } catch (_) {
        // Fallback gracefully on audio hardware interruption
      }

      // Interruptible delay that checks every 25ms so pause/stop is instant
      final int steps = (noteDurationMs / 25).ceil();
      for (int step = 0; step < steps; step++) {
        await Future.delayed(const Duration(milliseconds: 25));
        if (_sessionToken != token || _status != PlaybackStatus.playing) {
          return;
        }
      }
    }

    // Finished entire pattern
    if (_sessionToken == token) {
      await stop();
    }
  }

  void _notifyActiveIndex(int? index) {
    onActiveIndexChanged?.call(index);
  }

  void _notifyStatus() {
    onStatusChanged?.call(_status);
  }

  /// Disposes audio player resources.
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
  }
}
