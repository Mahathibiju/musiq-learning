import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:musiq_learning/models/musical_note.dart';
import 'package:musiq_learning/services/tone_generator.dart';

enum PlaybackStatus { idle, playing, paused }

/// Coordinates exercise notes and metronome clicks on one absolute beat clock.
class ExercisePlaybackController {
  final AudioPlayer _referencePlayer = AudioPlayer();
  final AudioPlayer _metronomePlayer = AudioPlayer();

  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackStatus get status => _status;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isPaused => _status == PlaybackStatus.paused;

  List<MusicalNote> _notes = [];
  List<MusicalNote> get notes => _notes;
  List<double> _noteStartBeats = [];

  int _bpm = 75;
  int get bpm => _bpm;
  int? _activeNoteIndex;
  int? get activeNoteIndex => _activeNoteIndex;
  int _nextNoteIndex = 0;
  int _nextMetronomeBeat = 0;
  double _totalBeats = 0;
  bool _metronomeEnabled = false;
  bool _clickPrepared = false;
  bool get metronomeEnabled => _metronomeEnabled;

  final Map<String, _PreparedTone> _preparedTones = {};
  final Stopwatch _clock = Stopwatch();
  Future<void> _startQueue = Future<void>.value();
  Timer? _clockTimer;
  int _sessionToken = 0;
  bool _disposed = false;

  void Function(int? index)? onActiveIndexChanged;
  void Function(PlaybackStatus status)? onStatusChanged;
  void Function(bool enabled)? onMetronomeChanged;

  /// Updates the shared exercise/metronome tempo without leaving an old clock
  /// or timer active. A playing exercise continues at its next unplayed note.
  void setBpm(int newBpm) {
    if (newBpm < 40 || newBpm > 200 || newBpm == _bpm) return;
    _bpm = newBpm;
    if (_clock.isRunning || _status == PlaybackStatus.paused) {
      unawaited(_restartAtCurrentNote());
    }
  }

  Future<void> setMetronomeEnabled(bool enabled) async {
    if (_disposed || enabled == _metronomeEnabled) return;
    _metronomeEnabled = enabled;
    onMetronomeChanged?.call(enabled);
    if (enabled) {
      if (!_clock.isRunning && _status != PlaybackStatus.paused) {
        if (!_clickPrepared) await _prepareClick();
        _notes = [];
        _noteStartBeats = [];
        _nextNoteIndex = 0;
        _totalBeats = double.infinity;
        _nextMetronomeBeat = 0;
        _clock
          ..reset()
          ..start();
        _dispatchDueEvents(_sessionToken);
      } else {
        _nextMetronomeBeat = _elapsedBeats.floor() + 1;
        _armNextEvent(_sessionToken);
      }
    } else {
      if (_notes.isEmpty) {
        _sessionToken++;
        _clockTimer?.cancel();
        _clockTimer = null;
        _clock.stop();
      } else {
        _armNextEvent(_sessionToken);
      }
      await _metronomePlayer.stop();
    }
  }

  Future<void> start({
    required List<MusicalNote> notes,
    required int bpm,
  }) async {
    if (_disposed || notes.isEmpty) return;
    final token = ++_sessionToken;
    _clockTimer?.cancel();
    _clockTimer = null;
    _clock
      ..stop()
      ..reset();
    final previousStart = _startQueue;
    final startComplete = Completer<void>();
    _startQueue = startComplete.future;
    await previousStart;
    try {
      if (token != _sessionToken || _disposed) return;
      await _metronomePlayer.stop();
      await _disposePreparedTones();
      if (token != _sessionToken || _disposed) return;
      await _referencePlayer.stop();
      if (token != _sessionToken || _disposed) return;

      _notes = List.unmodifiable(notes);
      _bpm = bpm.clamp(40, 200).toInt();
      _buildNoteTimeline(0);
      _nextNoteIndex = 0;
      _nextMetronomeBeat = 0;
      _activeNoteIndex = null;
      _status = PlaybackStatus.idle;
      await _prepareClick();
      if (token != _sessionToken || _disposed) return;
      await _prepareNoteTones(token, 0);
      if (token != _sessionToken || _disposed) return;

      _status = PlaybackStatus.playing;
      _clock.start();
      _notifyStatus();
      _dispatchDueEvents(token);
    } catch (_) {
      if (token == _sessionToken) {
        _status = PlaybackStatus.idle;
        _activeNoteIndex = null;
        _notifyActiveIndex(null);
        _notifyStatus();
        await _stopPreparedTones();
      }
    } finally {
      startComplete.complete();
    }
  }

  void _buildNoteTimeline(int firstNote) {
    _noteStartBeats = List<double>.filled(_notes.length, 0);
    var beat = 0.0;
    for (var i = firstNote; i < _notes.length; i++) {
      _noteStartBeats[i] = beat;
      beat += _notes[i].durationBeats;
    }
    _totalBeats = beat;
  }

  Future<void> _prepareClick() async {
    await _metronomePlayer.setReleaseMode(ReleaseMode.stop);
    await _metronomePlayer.setSource(
      BytesSource(
        ToneGenerator.generateToneBytes(
          frequencyHz: 1400,
          durationMs: 45,
          volume: 0.55,
        ),
      ),
    );
    _clickPrepared = true;
  }

  Future<void> _prepareNoteTones(int token, int firstNote) async {
    for (var i = firstNote; i < _notes.length; i++) {
      if (token != _sessionToken || _disposed) return;
      final note = _notes[i];
      final durationMs =
          (_beatIntervalMicros / 1000 * note.durationBeats * 0.90)
              .round()
              .clamp(50, 10000);
      final key = _toneKey(note.frequencyHz, durationMs);
      if (_preparedTones.containsKey(key)) continue;
      final player = AudioPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(
          BytesSource(
            ToneGenerator.generateToneBytes(
              frequencyHz: note.frequencyHz,
              durationMs: durationMs,
            ),
          ),
        );
        if (token != _sessionToken || _disposed) {
          await player.dispose();
          return;
        }
        _preparedTones[key] = _PreparedTone(player);
      } catch (_) {
        await player.dispose();
        rethrow;
      }
    }
  }

  Future<void> _restartAtCurrentNote() async {
    final token = ++_sessionToken;
    final wasRunning = _clock.isRunning;
    final wasPaused = _status == PlaybackStatus.paused;
    _clockTimer?.cancel();
    _clockTimer = null;
    _clock
      ..stop()
      ..reset();
    await _stopPreparedTones();
    await _metronomePlayer.stop();
    await _disposePreparedTones();
    if (token != _sessionToken || _disposed) return;
    _buildNoteTimeline(_nextNoteIndex);
    _nextMetronomeBeat = 0;
    await _prepareClick();
    if (token != _sessionToken || _disposed) return;
    await _prepareNoteTones(token, _nextNoteIndex);
    if (token != _sessionToken || _disposed) return;
    if (wasRunning) {
      _clock.start();
      _dispatchDueEvents(token);
    } else if (wasPaused) {
      _status = PlaybackStatus.paused;
    }
  }

  Future<void> playReferenceNote({required double frequencyHz}) async {
    await stop();
    final token = ++_sessionToken;
    try {
      await _referencePlayer.stop();
      if (_sessionToken != token || _disposed) return;
      await _referencePlayer.setReleaseMode(ReleaseMode.loop);
      if (_sessionToken != token || _disposed) return;
      await _referencePlayer.play(
        BytesSource(
          ToneGenerator.generateToneBytes(
            frequencyHz: frequencyHz,
            durationMs: 1200,
          ),
        ),
      );
      if (_sessionToken != token || _disposed) return;
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
    } catch (_) {
      if (_sessionToken == token) {
        _status = PlaybackStatus.idle;
        _activeNoteIndex = null;
        _notifyActiveIndex(null);
        _notifyStatus();
      }
    }
  }

  Future<void> pause() async {
    if (_status != PlaybackStatus.playing) return;
    _sessionToken++;
    _status = PlaybackStatus.paused;
    _clockTimer?.cancel();
    _clockTimer = null;
    _clock.stop();
    await _stopPreparedTones();
    await _metronomePlayer.stop();
    await _referencePlayer.stop();
    _notifyStatus();
  }

  Future<void> resume() async {
    if (_status != PlaybackStatus.paused || _disposed) return;
    final token = _sessionToken;
    _status = PlaybackStatus.playing;
    _clock.start();
    if (token != _sessionToken || _status != PlaybackStatus.playing) return;
    _notifyStatus();
    _dispatchDueEvents(token);
  }

  Future<void> stop() async {
    _sessionToken++;
    _clockTimer?.cancel();
    _clockTimer = null;
    _clock
      ..stop()
      ..reset();
    _metronomeEnabled = false;
    onMetronomeChanged?.call(false);
    _status = PlaybackStatus.idle;
    _activeNoteIndex = null;
    _nextNoteIndex = 0;
    await _metronomePlayer.stop();
    await _referencePlayer.stop();
    await _stopPreparedTones();
    _notifyActiveIndex(null);
    _notifyStatus();
  }

  void _dispatchDueEvents(int token) {
    if (token != _sessionToken || _disposed || !_clock.isRunning) return;
    final elapsed = _elapsedBeats;
    if (_notes.isNotEmpty &&
        _nextNoteIndex >= _notes.length &&
        elapsed >= _totalBeats) {
      unawaited(stop());
      return;
    }
    while (true) {
      final noteBeat = _nextNoteIndex < _notes.length
          ? _noteStartBeats[_nextNoteIndex]
          : double.infinity;
      final metronomeBeat =
          _metronomeEnabled &&
              (_notes.isEmpty || _nextMetronomeBeat <= _totalBeats)
          ? _nextMetronomeBeat.toDouble()
          : double.infinity;
      final nextBeat = math.min(noteBeat, metronomeBeat);
      if (nextBeat > elapsed + 0.000001) break;

      if (metronomeBeat <= noteBeat) {
        _nextMetronomeBeat++;
        _playMetronomeClick(token);
      } else {
        final noteIndex = _nextNoteIndex++;
        _activeNoteIndex = noteIndex;
        _notifyActiveIndex(noteIndex);
        _playPreparedNote(_notes[noteIndex], token);
      }
    }

    if (_notes.isNotEmpty &&
        _nextNoteIndex >= _notes.length &&
        elapsed >= _totalBeats) {
      unawaited(stop());
      return;
    }
    _armNextEvent(token);
  }

  void _armNextEvent(int token) {
    if (token != _sessionToken || !_clock.isRunning || _disposed) return;
    final noteBeat = _nextNoteIndex < _notes.length
        ? _noteStartBeats[_nextNoteIndex]
        : double.infinity;
    final metronomeBeat =
        _metronomeEnabled &&
            (_notes.isEmpty || _nextMetronomeBeat <= _totalBeats)
        ? _nextMetronomeBeat.toDouble()
        : double.infinity;
    final completionBeat = _notes.isNotEmpty && _nextNoteIndex >= _notes.length
        ? _totalBeats
        : double.infinity;
    final nextBeat = math.min(
      math.min(noteBeat, metronomeBeat),
      completionBeat,
    );
    if (nextBeat.isInfinite) return;
    final dueMicros = (nextBeat * _beatIntervalMicros).round();
    final delayMicros = math.max(0, dueMicros - _clock.elapsedMicroseconds);
    _clockTimer?.cancel();
    _clockTimer = Timer(Duration(microseconds: delayMicros), () {
      _clockTimer = null;
      _dispatchDueEvents(token);
    });
  }

  void _playMetronomeClick(int token) {
    if (token != _sessionToken || !_metronomeEnabled) return;
    unawaited(() async {
      try {
        if (token != _sessionToken || !_metronomeEnabled) return;
        await _metronomePlayer.seek(Duration.zero);
        if (token != _sessionToken || !_metronomeEnabled) return;
        await _metronomePlayer.resume();
      } catch (_) {
        // The clock continues if the audio device briefly refuses a click.
      }
    }());
  }

  void _playPreparedNote(MusicalNote note, int token) {
    final durationMs = (_beatIntervalMicros / 1000 * note.durationBeats * 0.90)
        .round()
        .clamp(50, 10000);
    final tone = _preparedTones[_toneKey(note.frequencyHz, durationMs)];
    if (tone == null) return;
    tone.pending = tone.pending.catchError((_) {}).then((_) async {
      if (token != _sessionToken || _disposed) return;
      try {
        await tone.player.seek(Duration.zero);
        if (token != _sessionToken || _disposed) return;
        await tone.player.resume();
      } catch (_) {
        // A failed note does not block later scheduled notes.
      }
    });
  }

  Future<void> _stopPreparedTones() async => Future.wait(
    _preparedTones.values.map((tone) => tone.player.stop().catchError((_) {})),
  );

  Future<void> _disposePreparedTones() async {
    final tones = _preparedTones.values.toList(growable: false);
    _preparedTones.clear();
    await Future.wait(
      tones.map((tone) async {
        await tone.pending.catchError((_) {});
        await tone.player.dispose();
      }),
    );
  }

  double get _beatIntervalMicros => 60000000 / _bpm;
  double get _elapsedBeats => _clock.elapsedMicroseconds / _beatIntervalMicros;
  String _toneKey(double frequency, int durationMs) =>
      '${frequency.toStringAsFixed(2)}-$durationMs';

  void _notifyActiveIndex(int? index) => onActiveIndexChanged?.call(index);
  void _notifyStatus() => onStatusChanged?.call(_status);

  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _disposePreparedTones();
    await _metronomePlayer.dispose();
    await _referencePlayer.dispose();
  }
}

class _PreparedTone {
  final AudioPlayer player;
  Future<void> pending = Future<void>.value();

  _PreparedTone(this.player);
}
