import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:musiq_learning/models/song_track.dart';

class SongPlaybackService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _loopEnabled = false;
  bool _hasLooped = false;
  bool _isSeekingToLoopStart = false;
  bool _disposed = false;
  Duration position = Duration.zero;
  bool isPlaying = false;
  double _volume = 1;
  double _playbackRate = 1;
  bool get hasLooped => _hasLooped;
  double get volume => _volume;
  double get playbackRate => _playbackRate;
  String? _currentPath;

  SongPlaybackService() {
    _positionSubscription = _player.onPositionChanged.listen(_onPosition);
    _player.onPlayerStateChanged.listen((state) {
      if (_disposed) return;
      isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
  }

  Future<void> previewUpload(SongFile song) => _playFile(song.path);

  Future<void> playInstrumental(InstrumentalTrack track) =>
      _playFile(track.path);

  Future<void> playVocal(VocalStem track, {Duration start = Duration.zero}) =>
      _playFile(track.path, start: start);

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> playSection({
    required InstrumentalTrack track,
    required Duration start,
    required Duration end,
    required bool loop,
    double speed = 1.0,
  }) async {
    await _playSectionPath(
      track.path,
      start: start,
      end: end,
      loop: loop,
      speed: speed,
    );
  }

  Future<void> playVocalSection({
    required VocalStem track,
    required Duration start,
    required Duration end,
    required bool loop,
    double speed = 1.0,
  }) async {
    await _playSectionPath(
      track.path,
      start: start,
      end: end,
      loop: loop,
      speed: speed,
    );
  }

  Future<void> _playSectionPath(
    String path, {
    required Duration start,
    required Duration end,
    required bool loop,
    required double speed,
  }) async {
    _playbackRate = speed;
    await stop();
    _loopStart = start;
    _loopEnd = end;
    _loopEnabled = loop;
    _hasLooped = false;
    await _player.setSource(DeviceFileSource(path));
    await _player.seek(start);
    await _player.resume();
    await _player.setPlaybackRate(_playbackRate);
    _currentPath = path;
    isPlaying = true;
    notifyListeners();
  }

  void setSectionLooping(bool enabled) {
    _loopEnabled = enabled;
  }

  Future<void> toggle() async {
    if (isPlaying) {
      await _player.pause();
      isPlaying = false;
      notifyListeners();
    } else if (_currentPath != null) {
      await _player.resume();
      await _player.setPlaybackRate(_playbackRate);
      isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> seek(Duration value) async {
    if (_currentPath == null) return;
    await _player.seek(value < Duration.zero ? Duration.zero : value);
  }

  Future<void> setPlaybackRate(double value) async {
    if (value < 0.25 || value > 2.0) {
      throw RangeError.value(
        value,
        'value',
        'Playback rate must be between 0.25 and 2.0.',
      );
    }
    _playbackRate = value;
    if (isPlaying) await _player.setPlaybackRate(value);
  }

  Future<void> stop() async {
    _loopStart = null;
    _loopEnd = null;
    _loopEnabled = false;
    _isSeekingToLoopStart = false;
    await _player.stop();
    position = Duration.zero;
    isPlaying = false;
    notifyListeners();
  }

  Future<void> _playFile(String path, {Duration start = Duration.zero}) async {
    await stop();
    _currentPath = path;
    await _player.setVolume(_volume);
    await _player.play(DeviceFileSource(path));
    await _player.setPlaybackRate(_playbackRate);
    if (start > Duration.zero) await _player.seek(start);
    isPlaying = true;
    notifyListeners();
  }

  void _onPosition(Duration newPosition) {
    if (_disposed) return;
    position = newPosition;
    final loopEnd = _loopEnd;
    final loopStart = _loopStart;
    if (loopEnd != null && newPosition >= loopEnd && !_isSeekingToLoopStart) {
      _isSeekingToLoopStart = true;
      if (_loopEnabled && loopStart != null) _hasLooped = true;
      final seek = _loopEnabled && loopStart != null
          ? _player.seek(loopStart)
          : _player.pause();
      unawaited(
        seek.whenComplete(() {
          _isSeekingToLoopStart = false;
        }),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }
}
