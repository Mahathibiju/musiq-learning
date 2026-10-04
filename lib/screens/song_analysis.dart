import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:musiq_learning/models/pitch_point.dart';
import 'package:musiq_learning/models/song_analysis.dart' as model;
import 'package:musiq_learning/models/song_track.dart';
import 'package:musiq_learning/services/pitch_analysis_service.dart';
import 'package:musiq_learning/services/song_playback_service.dart';
import 'package:musiq_learning/services/song_progress_service.dart';
import 'package:musiq_learning/services/song_separation_service.dart';
import 'package:musiq_learning/widgets/song_pitch_graph.dart';

class SongAnalysisScreen extends StatefulWidget {
  final SongFile original;
  final SongProgressService progress;

  const SongAnalysisScreen({
    super.key,
    required this.original,
    required this.progress,
  });

  @override
  State<SongAnalysisScreen> createState() => _SongAnalysisScreenState();
}

class _SongAnalysisScreenState extends State<SongAnalysisScreen> {
  static const Color background = Color(0xFF0B0C0F);
  static const Color card = Color(0xFF17181C);
  static const Color border = Color(0xFF292B33);
  static const Color yellow = Color(0xFFFFD21F);
  static const Color lime = Color(0xFFD9E86C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);

  final SongSeparationService _separation =
      const FastApiSongSeparationService();
  final PitchAnalysisService _pitchAnalysis =
      const FastApiPitchAnalysisService();
  final UserPitchAnalysisService _userPitchAnalysis =
      MicrophonePitchAnalysisService();
  final SongPlaybackService _playback = SongPlaybackService();
  final SongPlaybackService _vocalPlayback = SongPlaybackService();
  final SongPlaybackService _recordingPlayback = SongPlaybackService();

  SeparatedSong? _separated;
  model.SongAnalysis? _analysis;
  bool _separating = false;
  bool _separationFailed = false;
  String? _separationFailureDetails;
  bool _analyzing = false;
  bool _referenceAnalysisFinished = false;
  String? _statusMessage;
  List<PitchPoint> _recordedPitchPoints = const [];
  List<double> _recordingWaveform = const [];
  bool _recordingAnalysisComplete = false;
  bool _recordingReady = false;
  bool _recordedTakeLoaded = false;
  bool _analyzingRecording = false;
  Duration _takeStartPosition = Duration.zero;
  Duration _takeEndPosition = Duration.zero;
  _SingingFeedback? _recordingFeedback;
  String? _recordingFeedbackError;
  String? _currentUserNote;
  bool _startingSinging = false;
  bool _originalVocalActive = false;
  bool _karaokeStarted = false;
  bool _manualLoopActive = false;
  bool _practiceSectionLoaded = false;
  bool _capturePausedByPlayer = false;
  Duration? _scrubbingTo;
  double _manualRangeStartSeconds = 0;
  late double _manualRangeEndSeconds;
  double _karaokeVolume = 1;
  double _originalVocalVolume = 0;
  double _playbackRate = 1;

  @override
  void initState() {
    super.initState();
    _manualRangeEndSeconds = widget.original.duration.inMilliseconds / 1000;
    _playback.addListener(_syncRecordingWithPlayback);
  }

  @override
  void dispose() {
    _playback.removeListener(_syncRecordingWithPlayback);
    unawaited(_userPitchAnalysis.dispose());
    _playback.dispose();
    _vocalPlayback.dispose();
    _recordingPlayback.dispose();
    super.dispose();
  }

  void _syncRecordingWithPlayback() {
    if (!_userPitchAnalysis.isRecording) return;
    if (_playback.isPlaying && _capturePausedByPlayer) {
      _capturePausedByPlayer = false;
      unawaited(_userPitchAnalysis.resumeCapture());
    } else if (!_playback.isPlaying && !_capturePausedByPlayer) {
      _capturePausedByPlayer = true;
      unawaited(_userPitchAnalysis.pauseCapture());
    }
  }

  Future<void> _separateSong() async {
    if (_separated != null ||
        _separating ||
        _analyzing ||
        _startingSinging ||
        _userPitchAnalysis.isRecording) {
      return;
    }
    debugPrint('SEPARATION: UI separation flow started');
    setState(() {
      _separating = true;
      _separationFailed = false;
      _separationFailureDetails = null;
      _separated = null;
      _analysis = null;
      _referenceAnalysisFinished = false;
      _statusMessage = null;
    });
    try {
      debugPrint('SEPARATION: stopping existing audio players started');
      await Future.wait([_playback.stop(), _vocalPlayback.stop()]);
      debugPrint('SEPARATION: stopping existing audio players completed');
      _karaokeStarted = false;
      _originalVocalActive = false;
      _manualLoopActive = false;
      _practiceSectionLoaded = false;

      debugPrint('SEPARATION: SongSeparationService.separate started');
      final separated = await _separation.separate(widget.original);
      debugPrint('SEPARATION: SongSeparationService.separate completed');
      debugPrint('SEPARATION: file verification started');
      await _verifySeparatedOutputs(separated);
      debugPrint('SEPARATION: file verification completed');
      if (!mounted) {
        debugPrint('SEPARATION: screen unmounted before UI success state');
        return;
      }
      setState(() {
        _separated = separated;
        _separationFailed = false;
        _separating = false;
      });
      debugPrint('SEPARATION: UI success state set; both stems verified');
      await _analyzeSong();
    } catch (error) {
      debugPrint('SEPARATION: UI separation flow failed: $error');
      if (mounted) {
        setState(() {
          _separated = null;
          _separationFailed = true;
          _separationFailureDetails = 'Please try again. If the problem continues, check the audio backend connection.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _separating = false);
        debugPrint('SEPARATION: UI loading state cleared');
      } else {
        debugPrint(
          'SEPARATION: UI loading state not cleared; screen unmounted',
        );
      }
    }
  }

  Future<void> _verifySeparatedOutputs(SeparatedSong separated) async {
    final vocalPath = File(separated.vocalStem.path).absolute.path;
    final instrumentalPath = File(separated.instrumental.path).absolute.path;
    final originalPath = File(widget.original.path).absolute.path;
    if (vocalPath == instrumentalPath ||
        vocalPath == originalPath ||
        instrumentalPath == originalPath) {
      throw const FormatException(
        'The separation service did not return two distinct stem files.',
      );
    }
    for (final file in [File(vocalPath), File(instrumentalPath)]) {
      debugPrint(
        'SEPARATION: UI verification exists check started (${file.path})',
      );
      final exists = await file.exists();
      debugPrint('SEPARATION: UI verification exists=$exists (${file.path})');
      if (!exists) {
        throw FormatException('A separated audio output is missing or empty.');
      }
      debugPrint(
        'SEPARATION: UI verification length check started (${file.path})',
      );
      final length = await file.length();
      debugPrint('SEPARATION: UI verification length=$length (${file.path})');
      if (length == 0) {
        throw FormatException('A separated audio output is missing or empty.');
      }
    }
  }

  Future<void> _previewSeparatedStem({required bool vocal}) async {
    final separated = _separated;
    if (separated == null || _separating) return;
    final selected = vocal ? _vocalPlayback : _playback;
    final other = vocal ? _playback : _vocalPlayback;
    if (selected.isPlaying) {
      await selected.toggle();
      return;
    }
    await other.stop();
    if (vocal) {
      await selected.setVolume(_originalVocalVolume);
      await selected.playVocal(separated.vocalStem);
    } else {
      await selected.setVolume(_karaokeVolume);
      await selected.playInstrumental(separated.instrumental);
    }
  }

  Future<void> _analyzeSong() async {
    final separated = _separated;
    if (separated == null || _separating || _userPitchAnalysis.isRecording) {
      return;
    }
    setState(() {
      _analyzing = true;
      _referenceAnalysisFinished = false;
      _statusMessage = null;
    });
    try {
      // Reference analysis is deliberately given only the isolated vocal stem.
      debugPrint('SONG PREP: vocal pitch analysis started');
      final analysis = await _pitchAnalysis.analyzeVocalStem(
        separated.vocalStem,
      );
      debugPrint(
        'SONG PREP: vocal pitch analysis returned ${analysis.referenceVocalPitch.length} points',
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
      });
    } catch (error) {
      debugPrint('SONG PREP: reference vocal analysis failed: $error');
      if (mounted) {
        setState(() {
          _analysis = null;
          _statusMessage = 'Reference pitch analysis is unavailable. You can still record and review your singing.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
          _referenceAnalysisFinished = true;
        });
      }
    }
  }

  Future<void> _startSinging() async {
    if (_analyzingRecording) return;
    if (_userPitchAnalysis.isRecording) {
      await _finishSingingRecording();
      return;
    }
    if (_separating) return;
    final separated = _separated;
    if (separated == null) {
      _showMessage('Separate the song into vocals and karaoke before singing.');
      return;
    }
    if (_startingSinging) return;
    setState(() {
      _startingSinging = true;
      _statusMessage = null;
      _recordedPitchPoints = const [];
      _recordingWaveform = const [];
      _recordingAnalysisComplete = false;
      _recordingReady = false;
      _recordedTakeLoaded = false;
      _recordingFeedback = null;
      _recordingFeedbackError = null;
      _currentUserNote = null;
    });
    try {
      if (!_playback.isPlaying) {
        if (_playback.position >= widget.original.duration ||
            !_karaokeStarted) {
          await _playTogether(separated);
        } else {
          await _playback.toggle();
        }
      }
      _takeStartPosition = _playback.position;
      _takeEndPosition = _takeStartPosition;
      _capturePausedByPlayer = false;
      await _recordingPlayback.stop();
      await _userPitchAnalysis.start(
        timestamp: () => _playback.position,
        onPitch: (point) {
          if (!mounted) return;
          setState(() {
            _recordedPitchPoints = [..._recordedPitchPoints, point];
            _currentUserNote = point.noteName;
          });
        },
        onWaveform: (waveform) {
          if (!mounted) return;
          setState(() => _recordingWaveform = waveform);
        },
        onError: (error) {
          unawaited(_handleMicrophoneFailure(error));
        },
      );
    } catch (error) {
      await _userPitchAnalysis.stop();
      debugPrint('MIC: recording startup failed: $error');
      if (mounted) {
        _showMessage(
          'Microphone recording could not start. Please check microphone access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _startingSinging = false);
    }
  }

  Future<void> _playTogether(SeparatedSong separated) async {
    await _playback.setVolume(_karaokeVolume);
    await _vocalPlayback.stop();
    await _playback.playInstrumental(separated.instrumental);
    _karaokeStarted = true;
    _originalVocalActive = false;
  }

  Future<void> _finishSingingRecording() async {
    _takeEndPosition = _playback.position;
    await _userPitchAnalysis.stop();
    _capturePausedByPlayer = false;
    _recordingWaveform = _userPitchAnalysis.waveform;
    final recording = _userPitchAnalysis.recordingFile;
    final recordingReady =
        recording != null &&
        await recording.exists() &&
        await recording.length() > 44;
    if (_playback.isPlaying) await _playback.toggle();
    if (!mounted) return;
    setState(() {
      _recordingReady = recordingReady;
      _recordingAnalysisComplete = false;
      _recordingFeedback = null;
      _statusMessage = recordingReady ? null : 'No microphone audio was captured. Check microphone access and try again.';
    });
    // Keep the completed take available so the singer can listen before
    // explicitly asking for analysis.
  }

  Future<void> _handleMicrophoneFailure(Object error) async {
    debugPrint('MIC: recording failed: $error');
    await _userPitchAnalysis.stop();
    final recording = _userPitchAnalysis.recordingFile;
    final ready =
        recording != null &&
        await recording.exists() &&
        await recording.length() > 44;
    if (!mounted) return;
    setState(() {
      _recordingReady = ready;
      _recordingWaveform = _userPitchAnalysis.waveform;
      _statusMessage = ready
          ? 'Microphone stopped early. Your captured take is ready to analyze.'
          : 'Microphone recording stopped. Check microphone access and try again.';
    });
  }

  Future<void> _analyzeRecordedSection() async {
    if (_userPitchAnalysis.isRecording || _analyzingRecording) {
      return;
    }
    setState(() => _analyzingRecording = true);
    try {
      final recording = _userPitchAnalysis.recordingFile;
      var analyzedPoints = const <PitchPoint>[];
      if (recording != null &&
          await recording.exists() &&
          await recording.length() > 44) {
        analyzedPoints = await _userPitchAnalysis.analyzeRecording();
      }
      // Live estimates use the backing-track timeline and remain useful if
      // writing the microphone WAV failed.
      final pointsForAnalysis = analyzedPoints.isNotEmpty
          ? analyzedPoints
          : List<PitchPoint>.unmodifiable(_recordedPitchPoints);
      final feedback = _buildSingingFeedback(pointsForAnalysis);
      if (!mounted) return;
      setState(() {
        if (pointsForAnalysis.isNotEmpty) {
          _recordedPitchPoints = List.unmodifiable(pointsForAnalysis);
        }
        _recordingAnalysisComplete = true;
        _recordingReady = false;
        _recordingFeedback = feedback;
        _recordingFeedbackError = null;
        _statusMessage = null;
      });
    } catch (error) {
      debugPrint('PITCH: recorded take analysis failed: $error');
      if (mounted) {
        setState(() {
          _recordingAnalysisComplete = true;
          _recordingFeedback = null;
          _recordingFeedbackError = 'The recording was saved, but pitch could not be analyzed. Try a louder, clearer take.';
        });
      }
    } finally {
      if (mounted) setState(() => _analyzingRecording = false);
    }
  }

  Future<void> _toggleRecordedTake() async {
    final recording = _userPitchAnalysis.recordingFile;
    if (recording == null ||
        !await recording.exists() ||
        await recording.length() <= 44) {
      _showMessage('The saved voice recording is unavailable.');
      return;
    }
    if (_recordingPlayback.isPlaying) {
      await _recordingPlayback.toggle();
      return;
    }
    final dataBytes = (await recording.length() - 44).clamp(0, 0x7fffffff);
    final duration = Duration(
      microseconds: (dataBytes / 22050 * Duration.microsecondsPerSecond)
          .round(),
    );
    if (_recordedTakeLoaded && _recordingPlayback.position < duration) {
      await _recordingPlayback.toggle();
      return;
    }
    await _recordingPlayback.previewUpload(
      SongFile(
        path: recording.path,
        fileName: 'Your recording.wav',
        mimeType: 'audio/wav',
        duration: duration,
      ),
    );
    _recordedTakeLoaded = true;
  }

  Future<void> _toggleKaraokePreview() async {
    final separated = _separated;
    if (separated == null) return;
    if (_karaokeStarted) {
      final jobs = <Future<void>>[_playback.toggle()];
      if (_originalVocalActive) jobs.add(_vocalPlayback.toggle());
      await Future.wait(jobs);
      if (_userPitchAnalysis.isRecording) {
        if (_playback.isPlaying) {
          _capturePausedByPlayer = false;
          await _userPitchAnalysis.resumeCapture();
        } else {
          _capturePausedByPlayer = true;
          await _userPitchAnalysis.pauseCapture();
        }
      }
    } else {
      await _playTogether(separated);
    }
  }

  Future<void> _setPlaybackSpeed(double rate) async {
    setState(() => _playbackRate = rate);
    await _vocalPlayback.setPlaybackRate(rate);
  }

  Future<void> _setOriginalVocalVolume(double value) async {
    setState(() => _originalVocalVolume = value);
    await _vocalPlayback.setVolume(value);
    if (_userPitchAnalysis.isRecording) {
      await _vocalPlayback.stop();
      _originalVocalActive = false;
      return;
    }
    final separated = _separated;
    if ((!_userPitchAnalysis.isRecording && !_playback.isPlaying) ||
        separated == null) {
      return;
    }
    if (value == 0) {
      await _vocalPlayback.stop();
    } else if (_originalVocalActive) {
      await _vocalPlayback.setVolume(value);
    } else if (_manualLoopActive) {
      await _vocalPlayback.playVocalSection(
        track: separated.vocalStem,
        start: Duration(
          milliseconds: (_manualRangeStartSeconds * 1000).round(),
        ),
        end: Duration(milliseconds: (_manualRangeEndSeconds * 1000).round()),
        loop: true,
        speed: _playbackRate,
      );
      _originalVocalActive = true;
    } else {
      await _vocalPlayback.playVocal(
        separated.vocalStem,
        start: _playback.position,
      );
      _originalVocalActive = true;
    }
  }

  Future<void> _playManualLoop() async {
    final separated = _separated;
    if (separated == null) return;
    if (_manualLoopActive) {
      _vocalPlayback.setSectionLooping(false);
      if (mounted) {
        setState(() => _manualLoopActive = false);
      }
      return;
    }
    if (_practiceSectionLoaded && _vocalPlayback.isPlaying) {
      _vocalPlayback.setSectionLooping(true);
      if (mounted) setState(() => _manualLoopActive = true);
      return;
    }
    await _startPracticeSection(loop: true);
  }

  Future<void> _startPracticeSection({required bool loop}) async {
    final separated = _separated;
    if (separated == null) return;
    final start = Duration(
      milliseconds: (_manualRangeStartSeconds * 1000).round(),
    );
    final end = Duration(milliseconds: (_manualRangeEndSeconds * 1000).round());
    await _vocalPlayback.setVolume(1);
    await _vocalPlayback.playVocalSection(
      track: separated.vocalStem,
      start: start,
      end: end,
      loop: loop,
      speed: _playbackRate,
    );
    if (!mounted) return;
    setState(() {
      _practiceSectionLoaded = true;
      _manualLoopActive = loop;
      _originalVocalActive = true;
    });
  }

  Future<void> _togglePracticePlayback() async {
    if (_vocalPlayback.isPlaying) {
      await _vocalPlayback.toggle();
    } else if (_practiceSectionLoaded) {
      final end = Duration(
        milliseconds: (_manualRangeEndSeconds * 1000).round(),
      );
      if (_vocalPlayback.position >= end) {
        await _startPracticeSection(loop: _manualLoopActive);
      } else {
        await _vocalPlayback.toggle();
      }
    } else {
      await _startPracticeSection(loop: _manualLoopActive);
    }
  }

  Future<void> _selectPracticeIssue(_SingingIssue issue) async {
    final maximum = widget.original.duration.inMilliseconds / 1000;
    if (maximum <= 1) return;
    final start = (issue.start.inMilliseconds / 1000)
        .clamp(0.0, maximum - 1)
        .toDouble();
    final end = (issue.end.inMilliseconds / 1000)
        .clamp(start + 1, maximum)
        .toDouble();
    await _vocalPlayback.stop();
    if (!mounted) return;
    setState(() {
      _manualRangeStartSeconds = start;
      _manualRangeEndSeconds = end;
      _practiceSectionLoaded = false;
      _manualLoopActive = false;
      _originalVocalActive = false;
    });
  }

  void _updatePracticeRange(RangeValues range) {
    if (_practiceSectionLoaded) {
      unawaited(_vocalPlayback.stop());
    }
    setState(() {
      _manualRangeStartSeconds = range.start;
      _manualRangeEndSeconds = range.end;
      _practiceSectionLoaded = false;
      _manualLoopActive = false;
      _originalVocalActive = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF25251B),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded, color: white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Song Workspace',
        style: TextStyle(
          color: white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.original.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDuration(widget.original.duration)}  ·  ${widget.original.mimeType}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 19),
            const Text(
              'MODULE 01  /  SONG & VOCAL ANALYSIS',
              style: TextStyle(
                color: lime,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            _buildSeparationCard(),
            if (_separated != null) ...[
              const SizedBox(height: 12),
              _buildAudioMixCard(),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              _buildMessage(_statusMessage!),
            ],
            const SizedBox(height: 20),
            const Text(
              'MODULE 02  /  SINGING & RECORDING ANALYSIS',
              style: TextStyle(
                color: lime,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your song’s melody',
                    style: TextStyle(
                      color: white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_separated != null)
                  AnimatedBuilder(
                    animation: _playback,
                    builder: (context, _) => IconButton(
                      tooltip: _playback.isPlaying
                          ? 'Pause backing track'
                          : 'Play backing track',
                      onPressed: _toggleKaraokePreview,
                      icon: Icon(
                        _playback.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: yellow,
                        size: 35,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            AnimatedBuilder(
              animation: _playback,
              builder: (context, _) => SongPitchGraph(
                reference: _analysis?.referenceVocalPitch ?? const [],
            user:
                _userPitchAnalysis.isRecording ||
                    _recordingReady ||
                    _recordingAnalysisComplete ||
                    _recordedPitchPoints.isNotEmpty
                    ? _recordedPitchPoints
                    : const [],
                duration: widget.original.duration,
                position: _playback.position,
              ),
            ),
            AnimatedBuilder(
              animation: _playback,
              builder: (context, _) {
                final totalMs = widget.original.duration.inMilliseconds;
                final shown = _scrubbingTo ?? _playback.position;
                final maxValue = totalMs > 0 ? totalMs.toDouble() : 1.0;
                final value = totalMs <= 0
                    ? 0.0
                    : shown.inMilliseconds.clamp(0, totalMs).toDouble();
                return Column(
                  children: [
                    Slider(
                      min: 0,
                      max: maxValue,
                      value: value.clamp(0, maxValue),
                      activeColor: yellow,
                      inactiveColor: border,
                      onChanged: totalMs <= 0 || _manualLoopActive
                          ? null
                          : (milliseconds) => setState(() {
                              _scrubbingTo = Duration(
                                milliseconds: milliseconds.round(),
                              );
                            }),
                      onChangeEnd: totalMs <= 0 || _manualLoopActive
                          ? null
                          : (milliseconds) {
                              final target = Duration(
                                milliseconds: milliseconds.round(),
                              );
                              setState(() => _scrubbingTo = null);
                              unawaited(_playback.seek(target));
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(shown),
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                          Text(
                            _formatDuration(widget.original.duration),
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed:
                    _separating ||
                        _startingSinging ||
                        _analyzingRecording ||
                        (_recordingReady && !_recordingAnalysisComplete)
                    ? null
                    : _userPitchAnalysis.isRecording || _separated != null
                    ? _startSinging
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _separating || _separated == null
                      ? const Color(0xFF34363D)
                      : yellow,
                  foregroundColor: _separating || _separated == null
                      ? muted
                      : buttonText,
                  shape: const StadiumBorder(),
                ),
                icon: Icon(
                  _userPitchAnalysis.isRecording
                      ? Icons.stop_circle_rounded
                      : Icons.mic_rounded,
                ),
                label: Text(
                  _separating
                      ? 'SEPARATING…'
                      : _startingSinging
                      ? 'CONNECTING MICROPHONE…'
                      : _userPitchAnalysis.isRecording
                      ? 'STOP SINGING'
                      : _recordingReady && !_recordingAnalysisComplete
                      ? 'ANALYZE YOUR TAKE'
                      : 'START SINGING',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
            if (_userPitchAnalysis.isRecording ||
                _separating ||
                _analyzing ||
                (_separated != null && _referenceAnalysisFinished)) ...[
              const SizedBox(height: 8),
              Text(
                _separating
                    ? 'Singing and analysis controls are paused while stems are prepared.'
                    : _userPitchAnalysis.isRecording
                    ? (_currentUserNote == null
                          ? 'Recording your voice…'
                          : 'Recording  ·  $_currentUserNote')
                    : _analyzing
                    ? 'Reference melody analysis is running; you can still use karaoke.'
                    : _referenceAnalysisFinished && _analysis == null
                    ? '✓ Karaoke ready · reference melody is unavailable for this song.'
                    : '✓ Karaoke and reference melody are ready.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
            ],
            if (_userPitchAnalysis.isRecording ||
                _userPitchAnalysis.recordingFile != null ||
                _recordedPitchPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRecordingCard(),
            ],
            if (_separated != null && _recordingAnalysisComplete) ...[
              const SizedBox(height: 12),
              const Text(
                'FEEDBACK',
                style: TextStyle(
                  color: lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              if (_recordingFeedback != null)
                _buildMatchFeedback(_recordingFeedback!)
              else if (_recordingFeedbackError != null)
                _buildMessage(_recordingFeedbackError!)
              else
                _buildMessage(
                  'The take was saved, but there is not enough reliable pitch data to show feedback.',
                ),
              const SizedBox(height: 16),
              const Text(
                'MODULE 03  /  PRACTICE A SESSION',
                style: TextStyle(
                  color: lime,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Practice the reference vocal, then review your results.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 8),
              _buildManualLoopCard(),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildSeparationCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SEPARATE THE MIX',
          style: TextStyle(
            color: lime,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: _StemTile(
                label: 'VOCAL STEM',
                icon: Icons.record_voice_over_rounded,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: _StemTile(
                label: 'BACKING TRACK',
                icon: Icons.piano_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed:
                _separating ||
                    _analyzing ||
                    _startingSinging ||
                    _userPitchAnalysis.isRecording
                ? null
                : _separateSong,
            style: OutlinedButton.styleFrom(
              foregroundColor: yellow,
              side: const BorderSide(color: yellow),
              shape: const StadiumBorder(),
            ),
            icon: _separating
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.call_split_rounded, size: 19),
            label: Text(
              _separating ? 'SEPARATING VOCALS…' : 'SEPARATE VOCALS',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        if (_separating) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: yellow),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Separating vocals…',
                  style: TextStyle(
                    color: white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            minHeight: 3,
            color: yellow,
            backgroundColor: Color(0xFF30323A),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Reference melody extraction is connected only to the vocal stem. Instrumental content is never used for reference pitch.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.4),
        ),
        if (_separated != null) ...[
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2823),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF416B59)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: lime, size: 19),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vocals separated successfully',
                    style: TextStyle(
                      color: white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _stemPreviewRow(
            label: 'Vocal Stem',
            icon: Icons.mic_rounded,
            vocal: true,
          ),
          const SizedBox(height: 5),
          _stemPreviewRow(
            label: 'Karaoke Track',
            icon: Icons.music_note_rounded,
            vocal: false,
          ),
        ],
        if (_separationFailed) ...[
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF30281B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF76613A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️  We couldn’t prepare the vocal stems yet. Please try again.',
                  style: TextStyle(
                    color: white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                if (_separationFailureDetails != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _separationFailureDetails!,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_separated != null) ...[
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _analyzing ? null : _analyzeSong,
              style: FilledButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor: buttonText,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.multiline_chart_rounded),
              label: Text(
                _analyzing ? 'ANALYZING VOCAL…' : 'ANALYZE MELODY',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _stemPreviewRow({
    required String label,
    required IconData icon,
    required bool vocal,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF202228),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFF343741)),
    ),
    child: Row(
      children: [
        Icon(icon, color: lime, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: vocal ? _vocalPlayback : _playback,
          builder: (context, _) {
            final playing = (vocal ? _vocalPlayback : _playback).isPlaying;
            return IconButton(
              tooltip: playing ? 'Pause $label' : 'Preview $label',
              onPressed: () => _previewSeparatedStem(vocal: vocal),
              icon: Icon(
                playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_outline_rounded,
                color: yellow,
              ),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ],
    ),
  );

  int? _measurePitchMatch({List<PitchPoint>? points}) {
    final reference = _analysis?.referenceVocalPitch
        .where((point) => point.confidence >= 0.55)
        .toList();
    final userPoints = (points ?? _recordedPitchPoints)
        .where((point) => point.confidence >= 0.55)
        .toList();
    if (reference == null || reference.isEmpty || userPoints.isEmpty) {
      return null;
    }

    var matchedCount = 0;
    var similaritySum = 0.0;
    for (final userPoint in userPoints) {
      PitchPoint? nearest;
      var nearestGapMs = 351;
      for (final referencePoint in reference) {
        final gap = (referencePoint.time - userPoint.time).inMilliseconds.abs();
        if (gap < nearestGapMs) {
          nearest = referencePoint;
          nearestGapMs = gap;
        }
      }
      if (nearest == null || nearestGapMs > 350) continue;

      var semitoneDistance = (userPoint.midiNote - nearest.midiNote).abs() % 12;
      if (semitoneDistance > 6) semitoneDistance = 12 - semitoneDistance;
      final pitchSimilarity = (1 - semitoneDistance / 3).clamp(0.0, 1.0);
      final timingSimilarity = 1 - nearestGapMs / 350;
      similaritySum += pitchSimilarity * timingSimilarity;
      matchedCount++;
    }
    if (matchedCount == 0) return null;
    final coverage = matchedCount / userPoints.length;
    return (100 * similaritySum / matchedCount * coverage).round();
  }

  _SingingFeedback _buildSingingFeedback(List<PitchPoint> points) {
    final reference = _analysis?.referenceVocalPitch
        .where((point) => point.confidence >= 0.55)
        .toList();
    final userPoints = points
        .where((point) => point.confidence >= 0.55)
        .toList();
    if (userPoints.isEmpty) {
      return const _SingingFeedback.unavailable(
        'No reliable sung pitch was detected, so an accuracy score is unavailable. The recorded audio is still saved.',
      );
    }
    if (reference == null || reference.isEmpty) {
      return const _SingingFeedback.unavailable(
        'Your detected notes remain on the graph, but reference vocal analysis is unavailable, so accuracy cannot be calculated.',
      );
    }

    final comparisons = <_PitchComparison>[];
    var pitchSum = 0.0;
    var timingSum = 0.0;
    for (final user in userPoints) {
      PitchPoint? nearest;
      var nearestGapMs = 351;
      for (final target in reference) {
        final gap = (target.time - user.time).inMilliseconds.abs();
        if (gap < nearestGapMs) {
          nearest = target;
          nearestGapMs = gap;
        }
      }
      if (nearest == null || nearestGapMs > 350) continue;
      final pitchDifference = _signedSemitoneDifference(
        user.midiNote - nearest.midiNote,
      );
      final pitchSimilarity = (1 - pitchDifference.abs() / 3)
          .clamp(0.0, 1.0)
          .toDouble();
      final timingSimilarity = (1 - nearestGapMs / 350).clamp(0.0, 1.0);
      pitchSum += pitchSimilarity;
      timingSum += timingSimilarity;
      comparisons.add(
        _PitchComparison(
          user: user,
          reference: nearest,
          semitoneDifference: pitchDifference,
          gapMilliseconds: nearestGapMs,
          pitchSimilarity: pitchSimilarity,
          timingSimilarity: timingSimilarity,
        ),
      );
    }
    comparisons.sort((a, b) => a.user.time.compareTo(b.user.time));

    final score = _measurePitchMatch(points: userPoints);
    if (score == null || comparisons.isEmpty) {
      return const _SingingFeedback.unavailable(
        'There was not enough overlapping pitch data to calculate accuracy. Try a longer take while the reference vocal is analyzed.',
      );
    }

    final pitchAccuracy = (pitchSum / userPoints.length * 100).round();
    final timing = (timingSum / userPoints.length * 100).round();
    final stability = _measurePitchStability(comparisons);
    final positive = <String>[];
    if (pitchAccuracy >= 80) {
      positive.add('Your detected notes stayed close to the reference pitch.');
    }
    if (stability != null && stability >= 80) {
      positive.add('Your pitch stayed steady on sustained reference notes.');
    }
    if (timing >= 80) {
      positive.add('Your note timing followed the reference closely.');
    }

    return _SingingFeedback(
      score: score,
      level: _performanceLevel(score),
      summary: _performanceSummary(score),
      pitchAccuracy: pitchAccuracy,
      pitchStability: stability,
      timing: timing,
      positiveFeedback: positive,
      issues: _findPitchIssues(comparisons),
    );
  }

  int? _measurePitchStability(List<_PitchComparison> comparisons) {
    var transitions = 0;
    var stableTransitions = 0;
    for (var index = 1; index < comparisons.length; index++) {
      final previous = comparisons[index - 1];
      final current = comparisons[index];
      final timeGap = (current.user.time - previous.user.time).inMilliseconds;
      final referenceStep =
          (current.reference.midiNote - previous.reference.midiNote).abs();
      if (timeGap <= 0 || timeGap > 350 || referenceStep > 0.3) continue;
      transitions++;
      if ((current.semitoneDifference - previous.semitoneDifference).abs() <=
          0.4) {
        stableTransitions++;
      }
    }
    if (transitions < 4) return null;
    return (stableTransitions / transitions * 100).round();
  }

  List<_SingingIssue> _findPitchIssues(List<_PitchComparison> comparisons) {
    final samples = <_SingingIssue>[];
    for (var index = 0; index < comparisons.length; index++) {
      final comparison = comparisons[index];
      final difference = comparison.semitoneDifference;
      if (difference.abs() >= 0.5) {
        final direction = difference < 0 ? 'flat' : 'sharp';
        final amount = difference.abs() >= 1.25
            ? 'off target'
            : 'slightly $direction';
        samples.add(
          _SingingIssue.sample(
            kind: 'PITCH',
            title: 'PITCH — ${amount.toUpperCase()}',
            description: difference < 0
                ? 'Your detected pitch fell below the vocal reference here.'
                : 'Your detected pitch rose above the vocal reference here.',
            practiceTip:
                'Listen to the target note, then sustain your pitch near it.',
            time: comparison.user.time,
          ),
        );
      } else if (comparison.gapMilliseconds >= 230) {
        samples.add(
          _SingingIssue.sample(
            kind: 'TIMING',
            title: 'TIMING — LATE OR EARLY',
            description: 'This detected note was farther from the reference timing than nearby notes.',
            practiceTip: 'Listen to the lead-in and enter with the reference.',
            time: comparison.user.time,
          ),
        );
      }

      if (index == 0) continue;
      final previous = comparisons[index - 1];
      final sameHeldTarget =
          (comparison.reference.midiNote - previous.reference.midiNote).abs() <=
              0.3 &&
          (comparison.user.time - previous.user.time).inMilliseconds <= 350;
      final pitchJump =
          (comparison.semitoneDifference - previous.semitoneDifference).abs();
      if (sameHeldTarget && pitchJump >= 0.65) {
        samples.add(
          _SingingIssue.sample(
            kind: 'STABILITY',
            title: 'PITCH — UNSTEADY',
            description:
                'Your pitch shifted while the reference note stayed steady.',
            practiceTip:
                'Practice the note slowly and keep the pitch centered.',
            time: comparison.user.time,
          ),
        );
      }
    }

    if (samples.isEmpty) return const [];
    samples.sort((a, b) => a.start.compareTo(b.start));
    final grouped = <_SingingIssue>[];
    var current = samples.first;
    for (final sample in samples.skip(1)) {
      final gap = sample.start - current.end;
      if (sample.title == current.title &&
          gap <= const Duration(milliseconds: 600)) {
        current = current.extendTo(sample.start);
      } else {
        grouped.add(current);
        current = sample;
      }
    }
    grouped.add(current);
    return grouped.take(5).toList(growable: false);
  }

  double _signedSemitoneDifference(double difference) {
    var normalized = difference % 12;
    if (normalized > 6) normalized -= 12;
    if (normalized < -6) normalized += 12;
    return normalized;
  }

  String _performanceLevel(int score) => switch (score) {
    >= 90 => 'EXCELLENT',
    >= 75 => 'GOOD',
    >= 60 => 'NEEDS PRACTICE',
    _ => 'KEEP PRACTICING',
  };

  String _performanceSummary(int score) => switch (score) {
    >= 90 => 'Excellent! Your pitch closely followed the reference vocal.',
    >= 75 =>
      'Good job! You stayed close to the reference for much of this take.',
    >= 60 => 'You’re getting there! Some detected notes matched the reference; keep working on the sections below.',
    _ => 'Nice attempt! This take gives you a useful starting point for focused practice.',
  };

  Widget _buildMatchFeedback(_SingingFeedback feedback) {
    const color = lime;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF17181C),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feedback.score != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${feedback.score}%',
                  style: const TextStyle(
                    color: yellow,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    feedback.level!,
                    style: const TextStyle(
                      color: lime,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
          Text(
            feedback.summary,
            style: const TextStyle(color: white, fontSize: 12, height: 1.4),
          ),
          if (feedback.pitchAccuracy != null ||
              feedback.pitchStability != null ||
              feedback.timing != null) ...[
            const SizedBox(height: 13),
            const Text(
              'PERFORMANCE DETAILS',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 6),
            _feedbackMetric('Pitch Accuracy', feedback.pitchAccuracy),
            if (feedback.pitchStability != null)
              _feedbackMetric('Pitch Stability', feedback.pitchStability),
            _feedbackMetric('Timing', feedback.timing),
          ],
          if (feedback.positiveFeedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'WHAT WENT WELL',
              style: TextStyle(
                color: lime,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 5),
            ...feedback.positiveFeedback.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '✓  $item',
                  style: const TextStyle(
                    color: white,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
          if (feedback.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'NEEDS IMPROVEMENT',
              style: TextStyle(
                color: yellow,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 6),
            ...feedback.issues.map(_buildPitchIssue),
          ],
          if (feedback.score != null && feedback.issues.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'No specific pitch or timing issue could be isolated in this take.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackMetric(String label, int? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
        Text(
          value == null ? 'Not enough data' : '$value%',
          style: const TextStyle(
            color: white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _buildPitchIssue(_SingingIssue issue) => InkWell(
    onTap: () => unawaited(_selectPracticeIssue(issue)),
    borderRadius: BorderRadius.circular(11),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF202228),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${issue.timeLabel()}   ${issue.title}',
            style: const TextStyle(
              color: yellow,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            issue.description,
            style: const TextStyle(color: white, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'Practice tip: ${issue.practiceTip} · Tap to practice this time',
            style: const TextStyle(color: muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    ),
  );

  Widget _buildAudioMixCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        _buildVolumeSlider(
          title: 'Karaoke Volume',
          icon: Icons.music_note_rounded,
          value: _karaokeVolume,
          onChanged: (value) {
            setState(() => _karaokeVolume = value);
            unawaited(_playback.setVolume(value));
          },
        ),
        const Divider(color: border, height: 12),
        _buildVolumeSlider(
          title: 'Original Vocal',
          icon: Icons.record_voice_over_rounded,
          value: _originalVocalVolume,
          onChanged: (value) => unawaited(_setOriginalVocalVolume(value)),
        ),
      ],
    ),
  );

  Widget _buildRecordingCard() {
    final recording = _userPitchAnalysis.isRecording;
    final hasAudioFile = _userPitchAnalysis.recordingFile != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                recording ? Icons.fiber_manual_record : Icons.graphic_eq,
                color: recording
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF79D8C5),
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  recording
                      ? 'RECORDING YOUR VOICE'
                      : hasAudioFile
                      ? 'TAKE READY TO ANALYZE'
                      : 'PITCH TAKE READY TO ANALYZE',
                  style: const TextStyle(
                    color: white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Text(
                '${_formatDuration(_takeStartPosition)} — ${_formatDuration(recording ? _playback.position : _takeEndPosition)}',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF111216),
                borderRadius: BorderRadius.circular(11),
              ),
              child: CustomPaint(
                painter: _RecordingWaveformPainter(_recordingWaveform),
              ),
            ),
          ),
          if (!recording &&
              hasAudioFile &&
              (_recordingReady || _recordingAnalysisComplete)) ...[
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _recordingPlayback,
              builder: (context, _) => SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _toggleRecordedTake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: yellow,
                    side: const BorderSide(color: yellow),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    _recordingPlayback.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _recordingPlayback.isPlaying
                        ? 'PAUSE YOUR RECORDING'
                        : 'PLAY YOUR RECORDING',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (!recording &&
              (_recordingReady ||
                  _recordedPitchPoints.isNotEmpty ||
                  _recordingAnalysisComplete)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                onPressed: _analyzingRecording ? null : _analyzeRecordedSection,
                style: FilledButton.styleFrom(
                  backgroundColor: yellow,
                  foregroundColor: buttonText,
                  shape: const StadiumBorder(),
                ),
                icon: _analyzingRecording
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: buttonText,
                        ),
                      )
                    : const Icon(Icons.multiline_chart_rounded, size: 18),
                label: Text(
                  _analyzingRecording ? 'ANALYZING TAKE…' : 'ANALYZE RECORDING',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualLoopCard() {
    final maximum = widget.original.duration.inMilliseconds / 1000;
    if (maximum <= 1) return const SizedBox.shrink();
    final values = RangeValues(
      _manualRangeStartSeconds.clamp(0.0, maximum - 1),
      _manualRangeEndSeconds.clamp(_manualRangeStartSeconds + 1, maximum),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRACTICE RANGE',
            style: TextStyle(
              color: lime,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDuration(Duration(milliseconds: (values.start * 1000).round()))}  —  ${_formatDuration(Duration(milliseconds: (values.end * 1000).round()))}',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Start: ${_formatDuration(Duration(milliseconds: (values.start * 1000).round()))}',
                  style: const TextStyle(color: white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'End: ${_formatDuration(Duration(milliseconds: (values.end * 1000).round()))}',
                style: const TextStyle(color: white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          RangeSlider(
            values: values,
            min: 0,
            max: maximum,
            divisions: maximum.round().clamp(1, 1000),
            labels: RangeLabels(
              _formatDuration(
                Duration(milliseconds: (values.start * 1000).round()),
              ),
              _formatDuration(
                Duration(milliseconds: (values.end * 1000).round()),
              ),
            ),
            onChanged: (_vocalPlayback.isPlaying || _manualLoopActive)
                ? null
                : _updatePracticeRange,
          ),
          const SizedBox(height: 3),
          AnimatedBuilder(
            animation: _vocalPlayback,
            builder: (context, _) {
              final position = _vocalPlayback.position.inMilliseconds / 1000;
              final seekValue = _practiceSectionLoaded
                  ? position.clamp(values.start, values.end).toDouble()
                  : values.start;
              return Column(
                children: [
                  Slider(
                    min: values.start,
                    max: values.end,
                    value: seekValue,
                    activeColor: yellow,
                    inactiveColor: border,
                    onChanged: !_practiceSectionLoaded
                        ? null
                        : (seconds) => unawaited(
                            _vocalPlayback.seek(
                              Duration(milliseconds: (seconds * 1000).round()),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_vocalPlayback.position),
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                        Text(
                          _formatDuration(
                            Duration(milliseconds: (values.end * 1000).round()),
                          ),
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PLAYBACK SPEED',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              DropdownButton<double>(
                value: _playbackRate,
                dropdownColor: card,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  color: white,
                  fontWeight: FontWeight.w800,
                ),
                items: const [1.0, 0.75, 0.5, 0.25]
                    .map(
                      (rate) => DropdownMenuItem<double>(
                        value: rate,
                        child: Text('$rate×'),
                      ),
                    )
                    .toList(),
                onChanged: (rate) {
                  if (rate != null) unawaited(_setPlaybackSpeed(rate));
                },
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _togglePracticePlayback,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: yellow,
                    side: const BorderSide(color: yellow),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    _vocalPlayback.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _vocalPlayback.isPlaying ? 'PAUSE' : 'PLAY',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _playManualLoop,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: yellow,
                    side: const BorderSide(color: yellow),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    _manualLoopActive
                        ? Icons.repeat_on_rounded
                        : Icons.repeat_rounded,
                  ),
                  label: Text(
                    _manualLoopActive ? 'LOOP ON' : 'LOOP OFF',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider({
    required String title,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) => Column(
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: yellow),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      Slider(
        value: value,
        onChanged: onChanged,
        activeColor: yellow,
        inactiveColor: border,
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('OFF', style: TextStyle(color: muted, fontSize: 9)),
          Text('MAX', style: TextStyle(color: muted, fontSize: 9)),
        ],
      ),
    ],
  );

  Widget _buildMessage(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF25251B),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: yellow.withAlpha(80)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: white, fontSize: 12, height: 1.4),
    ),
  );

  String _formatDuration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _SingingFeedback {
  final int? score;
  final String? level;
  final String summary;
  final int? pitchAccuracy;
  final int? pitchStability;
  final int? timing;
  final List<String> positiveFeedback;
  final List<_SingingIssue> issues;

  const _SingingFeedback({
    required this.score,
    required this.level,
    required this.summary,
    required this.pitchAccuracy,
    required this.pitchStability,
    required this.timing,
    required this.positiveFeedback,
    required this.issues,
  });

  const _SingingFeedback.unavailable(this.summary)
    : score = null,
      level = null,
      pitchAccuracy = null,
      pitchStability = null,
      timing = null,
      positiveFeedback = const [],
      issues = const [];
}

class _PitchComparison {
  final PitchPoint user;
  final PitchPoint reference;
  final double semitoneDifference;
  final int gapMilliseconds;
  final double pitchSimilarity;
  final double timingSimilarity;

  const _PitchComparison({
    required this.user,
    required this.reference,
    required this.semitoneDifference,
    required this.gapMilliseconds,
    required this.pitchSimilarity,
    required this.timingSimilarity,
  });
}

class _SingingIssue {
  static const Duration _pitchFrameDuration = Duration(milliseconds: 93);

  final String kind;
  final String title;
  final String description;
  final String practiceTip;
  final Duration start;
  final Duration end;

  const _SingingIssue({
    required this.kind,
    required this.title,
    required this.description,
    required this.practiceTip,
    required this.start,
    required this.end,
  });

  factory _SingingIssue.sample({
    required String kind,
    required String title,
    required String description,
    required String practiceTip,
    required Duration time,
  }) => _SingingIssue(
    kind: kind,
    title: title,
    description: description,
    practiceTip: practiceTip,
    start: time,
    end: time + _pitchFrameDuration,
  );

  _SingingIssue extendTo(Duration time) => _SingingIssue(
    kind: kind,
    title: title,
    description: description,
    practiceTip: practiceTip,
    start: start,
    end: time + _pitchFrameDuration,
  );

  String timeLabel() {
    final startLabel = _formatCoachTime(start);
    final endLabel = _formatCoachTime(end);
    return startLabel == endLabel ? startLabel : '$startLabel – $endLabel';
  }
}

String _formatCoachTime(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  return '${safeDuration.inMinutes.toString().padLeft(2, '0')}:${(safeDuration.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _StemTile extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StemTile({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFF202228),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFF343741)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFD9E86C), size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecordingWaveformPainter extends CustomPainter {
  final List<double> samples;

  const _RecordingWaveformPainter(this.samples);

  static const Color _waveColor = Color(0xFF79D8C5);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = const Color(0xFF292B33)
        ..strokeWidth = 1,
    );
    if (samples.isEmpty) return;

    final visible = samples.length > 100
        ? samples.sublist(samples.length - 100)
        : samples;
    final step = size.width / visible.length;
    final paint = Paint()
      ..color = _waveColor
      ..strokeWidth = math.max(1.0, step * 0.55)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < visible.length; index++) {
      final amplitude = visible[index].clamp(0.0, 1.0);
      if (amplitude < 0.002) continue;
      final halfHeight = (amplitude * size.height * 7).clamp(
        1.0,
        size.height * 0.45,
      );
      final x = (index + 0.5) * step;
      canvas.drawLine(
        Offset(x, centerY - halfHeight),
        Offset(x, centerY + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingWaveformPainter oldDelegate) =>
      !identical(oldDelegate.samples, samples);
}
