import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:musiq_learning/models/breathing_exercise.dart';

class BreathingSessionController extends ChangeNotifier {
  BreathingExerciseId _exerciseId = BreathingExerciseId.breathControl;
  BreathingExercise? _randomRoutine;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isComplete = false;
  bool _isSingerReplay = false;
  Duration _elapsed = Duration.zero;
  Duration _phaseElapsed = Duration.zero;
  int _phaseIndex = 0;
  int _round = 0;
  int _chromaticIndex = 0;

  static const int singerReplaySeconds = 5;
  static const int singerRangeLength = 36;

  static const List<String> _noteNames = [
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ];

  BreathingExerciseId get exerciseId => _exerciseId;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isComplete => _isComplete;
  Duration get elapsed => _elapsed;
  int get round => _round + 1;
  int get chromaticIndex => _chromaticIndex;
  bool get isSingerReplay => _isSingerReplay;
  String get chromaticNote {
    final midiNote = 48 + _chromaticIndex;
    return '${_noteNames[midiNote % 12]}${(midiNote ~/ 12) - 1}';
  }
  double get chromaticFrequencyHz {
    final midiNote = 48 + _chromaticIndex;
    return 440.0 * pow(2.0, (midiNote - 69) / 12);
  }

  BreathingExercise get exercise {
    if (_exerciseId == BreathingExerciseId.randomChallenge &&
        _randomRoutine != null) {
      return _randomRoutine!;
    }
    return BreathingExercise.all.firstWhere((item) => item.id == _exerciseId);
  }

  BreathingPhase get phase {
    if (_isComplete) return BreathingPhase.complete;
    if (_exerciseId == BreathingExerciseId.singersBreath) {
      return _isSingerReplay ? BreathingPhase.sustain : BreathingPhase.ready;
    }
    final phases = exercise.phases;
    if (phases.isEmpty) return BreathingPhase.ready;
    return phases[_phaseIndex].phase;
  }

  int get phaseSeconds {
    if (_isComplete) return 0;
    if (_isSingerReplay) return singerReplaySeconds;
    if (_exerciseId == BreathingExerciseId.singersBreath ||
        exercise.phases.isEmpty) {
      return 0;
    }
    final baseSeconds = exercise.phases[_phaseIndex].seconds;
    if (_exerciseId != BreathingExerciseId.breathControl) return baseSeconds;
    return switch (exercise.phases[_phaseIndex].phase) {
      BreathingPhase.inhale || BreathingPhase.exhale => baseSeconds + _round,
      BreathingPhase.hold => baseSeconds + (_round ~/ 2),
      _ => baseSeconds,
    };
  }

  int get phaseSecondsRemaining =>
      (phaseSeconds - _phaseElapsed.inSeconds).clamp(0, phaseSeconds);

  double get phaseProgress {
    if (phaseSeconds == 0) return 0;
    return (_phaseElapsed.inMilliseconds / (phaseSeconds * 1000))
        .clamp(0.0, 1.0);
  }

  double get sessionProgress {
    if (_exerciseId == BreathingExerciseId.singersBreath) {
      return _isComplete ? 1 : phaseProgress;
    }
    final totalMilliseconds = _totalSessionMilliseconds;
    if (totalMilliseconds == 0) return 0;
    return (_elapsed.inMilliseconds / totalMilliseconds).clamp(0.0, 1.0);
  }

  int get _totalSessionMilliseconds {
    if (_exerciseId != BreathingExerciseId.breathControl) {
      final roundSeconds = exercise.phases.fold<int>(
        0,
        (sum, step) => sum + step.seconds,
      );
      return roundSeconds * exercise.rounds * 1000;
    }
    final baseRound = exercise.phases.fold<int>(
      0,
      (sum, step) => sum + step.seconds,
    );
    var total = baseRound * exercise.rounds;
    for (var roundIndex = 0; roundIndex < exercise.rounds; roundIndex++) {
      total += roundIndex * 2 + (roundIndex ~/ 2);
    }
    return total * 1000;
  }

  void selectExercise(BreathingExerciseId id) {
    if (id == _exerciseId) return;
    _exerciseId = id;
    _chromaticIndex = 0;
    _randomRoutine = null;
    _resetState();
    notifyListeners();
  }

  void start() {
    if (_exerciseId == BreathingExerciseId.singersBreath) {
      replaySingerNote();
      return;
    }
    if (_isRunning) return;
    if (_isComplete) _resetState();
    if (_exerciseId == BreathingExerciseId.randomChallenge) {
      final choices = BreathingExercise.randomRoutines;
      var index = Random().nextInt(choices.length);
      if (choices.length > 1 &&
          choices[index].pattern == _randomRoutine?.pattern) {
        index = (index + 1) % choices.length;
      }
      _randomRoutine = choices[index];
    }
    _isRunning = true;
    _isPaused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    notifyListeners();
  }

  void pause() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (_isRunning || !_isPaused) return;
    _isPaused = false;
    _isRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    notifyListeners();
  }

  void previousSingerNote() {
    if (_exerciseId != BreathingExerciseId.singersBreath) return;
    _chromaticIndex = (_chromaticIndex - 1).clamp(0, singerRangeLength - 1);
    _resetState();
    notifyListeners();
  }

  void nextSingerNote() {
    if (_exerciseId != BreathingExerciseId.singersBreath) return;
    _chromaticIndex = (_chromaticIndex + 1).clamp(0, singerRangeLength - 1);
    _resetState();
    notifyListeners();
  }

  void replaySingerNote() {
    if (_exerciseId != BreathingExerciseId.singersBreath) return;
    _resetState();
    _isSingerReplay = true;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    notifyListeners();
  }

  void reset() {
    _resetState();
    notifyListeners();
  }

  void _resetState() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isPaused = false;
    _isComplete = false;
    _isSingerReplay = false;
    _elapsed = Duration.zero;
    _phaseElapsed = Duration.zero;
    _phaseIndex = 0;
    _round = 0;
  }

  void _onTick(Timer timer) {
    _elapsed += const Duration(milliseconds: 100);
    if (_isSingerReplay) {
      _phaseElapsed += const Duration(milliseconds: 100);
      if (_elapsed.inMilliseconds >= singerReplaySeconds * 1000) {
        _elapsed = const Duration(seconds: singerReplaySeconds);
        _timer?.cancel();
        _timer = null;
        _isRunning = false;
        _isPaused = false;
        _isComplete = true;
      }
      notifyListeners();
      return;
    }

    _phaseElapsed += const Duration(milliseconds: 100);
    while (_phaseElapsed.inMilliseconds >= phaseSeconds * 1000 &&
        !_isComplete) {
      _phaseElapsed -= Duration(seconds: phaseSeconds);
      _phaseIndex++;
      if (_phaseIndex >= exercise.phases.length) {
        _phaseIndex = 0;
        _round++;
        if (_round >= exercise.rounds) {
          _phaseElapsed = Duration.zero;
          _elapsed = Duration(milliseconds: _totalSessionMilliseconds);
          _isRunning = false;
          _isPaused = false;
          _isComplete = true;
          _timer?.cancel();
          _timer = null;
          break;
        }
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
