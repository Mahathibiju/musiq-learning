import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:musiq_learning/models/pitch_point.dart';
import 'package:musiq_learning/models/song_analysis.dart';
import 'package:musiq_learning/models/song_track.dart';
import 'package:musiq_learning/services/song_separation_service.dart';
import 'package:record/record.dart';

abstract interface class PitchAnalysisService {
  /// Accepts a vocal stem by type so the original mixed song or backing track
  /// cannot accidentally become the reference-pitch source.
  Future<SongAnalysis> analyzeVocalStem(VocalStem vocalStem);
}

/// Requests real pYIN pitch points for the generated vocal stem on FastAPI.
/// The endpoint only accepts backend-generated `*_vocals.mp3` files.
class FastApiPitchAnalysisService implements PitchAnalysisService {
  const FastApiPitchAnalysisService();

  static const Duration _analysisTimeout = Duration(minutes: 20);

  @override
  Future<SongAnalysis> analyzeVocalStem(VocalStem vocalStem) async {
    final vocalUrl = vocalStem.analysisUrl;
    if (vocalUrl == null || vocalUrl.isEmpty) {
      throw const SongIntegrationUnavailable(
        'The vocal stem is missing its backend analysis URL. Separate the song again, then retry.',
      );
    }
    final baseUri = Uri.parse(FastApiSongSeparationService.backendBaseUrl);
    final endpoint = baseUri.replace(
      path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/analyze-vocal',
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
          .timeout(_analysisTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw SongIntegrationUnavailable(
          _analysisError(response.body, response.statusCode),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw const SongIntegrationUnavailable(
          'The backend did not confirm vocal pitch analysis.',
        );
      }
      final rawPoints = decoded['pitch_points'];
      if (rawPoints is! List) {
        throw const SongIntegrationUnavailable(
          'The backend response did not contain vocal pitch points.',
        );
      }

      final pitchPoints = <PitchPoint>[];
      for (final rawPoint in rawPoints) {
        if (rawPoint is! Map<String, dynamic> ||
            rawPoint['time'] is! num ||
            rawPoint['frequency'] is! num ||
            rawPoint['confidence'] is! num) {
          throw const SongIntegrationUnavailable(
            'The backend returned an invalid vocal pitch point.',
          );
        }
        final timeSeconds = (rawPoint['time']! as num).toDouble();
        final frequencyHz = (rawPoint['frequency']! as num).toDouble();
        final confidence = (rawPoint['confidence']! as num).toDouble();
        if (!timeSeconds.isFinite ||
            !frequencyHz.isFinite ||
            frequencyHz <= 0 ||
            !confidence.isFinite ||
            confidence < 0 ||
            confidence > 1) {
          throw const SongIntegrationUnavailable(
            'The backend returned an out-of-range vocal pitch point.',
          );
        }
        final midiNote = 69 + 12 * (math.log(frequencyHz / 440) / math.ln2);
        pitchPoints.add(
          PitchPoint(
            time: Duration(milliseconds: (timeSeconds * 1000).round()),
            midiNote: midiNote,
            confidence: confidence,
          ),
        );
      }
      if (pitchPoints.isEmpty) {
        throw const SongIntegrationUnavailable(
          'No reliable sung pitch was detected in this vocal stem.',
        );
      }
      return SongAnalysis(referenceVocalPitch: pitchPoints);
    } on TimeoutException catch (error) {
      throw SongIntegrationUnavailable(
        'Vocal pitch analysis took longer than 20 minutes. Please retry. ($error)',
      );
    } on http.ClientException catch (error) {
      throw SongIntegrationUnavailable(
        'Could not reach the vocal pitch-analysis backend. Check the Mac server and Wi-Fi. ($error)',
      );
    } on FormatException catch (error) {
      throw SongIntegrationUnavailable(
        'The vocal pitch-analysis backend returned invalid data. ($error)',
      );
    } finally {
      client.close();
    }
  }

  String _analysisError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return 'Vocal pitch analysis returned $statusCode: ${decoded['detail']}';
      }
    } on FormatException {
      // Include the response text when the error isn't JSON.
    }
    return 'Vocal pitch analysis returned $statusCode: $body';
  }
}

abstract interface class UserPitchAnalysisService {
  bool get isRecording;
  File? get recordingFile;
  List<double> get waveform;

  Future<void> start({
    required Duration Function() timestamp,
    required void Function(PitchPoint point) onPitch,
    required void Function(List<double> waveform) onWaveform,
    required void Function(Object error) onError,
  });

  Future<List<PitchPoint>> analyzeRecording();

  Future<void> pauseCapture();

  Future<void> resumeCapture();

  Future<void> stop();

  Future<void> dispose();
}

class MicrophonePermissionDenied implements Exception {
  const MicrophonePermissionDenied();

  @override
  String toString() =>
      'Microphone permission was denied. Allow microphone access in Android settings to track your singing.';
}

/// Captures mono PCM during singing. YIN pitch analysis is deliberately deferred
/// until the user asks to analyze the completed take.
class MicrophonePitchAnalysisService implements UserPitchAnalysisService {
  static const int _sampleRate = 22050;
  static const int _frameSize = 4096;
  static const int _hopSize = 2048;
  static const double _minimumFrequency = 65;
  static const double _maximumFrequency = 1000;
  static const double _minimumRms = 0.006;
  static const double _minimumConfidence = 0.72;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  static const int _waveformWindowSamples = 2205;
  final List<int> _pitchPendingBytes = [];
  final List<int> _waveformPendingBytes = [];
  bool _isRecording = false;
  bool _recorderStarted = false;
  bool _disposed = false;
  bool _capturePaused = false;
  File? _recordingFile;
  IOSink? _recordingSink;
  int _recordedPcmBytes = 0;
  final List<double> _waveform = [];
  int _receivedChunks = 0;
  int _receivedBytes = 0;
  int _processedFrames = 0;
  final List<_TimelineMarker> _timelineMarkers = [];

  @override
  bool get isRecording => _isRecording;

  @override
  File? get recordingFile => _recordingFile;

  @override
  List<double> get waveform => List.unmodifiable(_waveform);

  @override
  Future<void> start({
    required Duration Function() timestamp,
    required void Function(PitchPoint point) onPitch,
    required void Function(List<double> waveform) onWaveform,
    required void Function(Object error) onError,
  }) async {
    if (_disposed) throw StateError('Microphone pitch service is disposed.');
    await stop();
    if (!await _recorder.hasPermission()) {
      _logDiagnostic('MIC: permission denied');
      throw const MicrophonePermissionDenied();
    }
    _logDiagnostic('MIC: permission granted');
    _logDiagnostic('MIC: requesting mono PCM16 audio at $_sampleRate Hz');

    _waveformPendingBytes.clear();
    _pitchPendingBytes.clear();
    _timelineMarkers.clear();
    final previousRecording = _recordingFile;
    if (previousRecording != null && await previousRecording.exists()) {
      await previousRecording.delete();
    }
    _recordingFile = File(
      '${Directory.systemTemp.path}/musiq_take_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    _recordedPcmBytes = 0;
    _capturePaused = false;
    _waveform.clear();
    _recordingSink = _recordingFile!.openWrite();
    _recordingSink!.add(List<int>.filled(44, 0));
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
    );
    _recorderStarted = true;
    _isRecording = true;
    _receivedChunks = 0;
    _receivedBytes = 0;
    _processedFrames = 0;
    _logDiagnostic(
      'MIC: stream started sampleRate=$_sampleRate Hz channels=1 format=PCM16',
    );
    _subscription = stream.listen(
      (bytes) {
        _receivedChunks++;
        _receivedBytes += bytes.length;
        if (bytes.isEmpty) {
          _logDiagnostic('MIC: received empty audio chunk');
          return;
        }
        if (_receivedChunks == 1 || _receivedChunks % 50 == 0) {
          _logDiagnostic(
            'MIC: received samples=${_receivedBytes ~/ 2} bytes=$_receivedBytes chunks=$_receivedChunks',
          );
        }
        if (_capturePaused) return;
        _timelineMarkers.add(
          _TimelineMarker(_recordedPcmBytes ~/ 2, timestamp()),
        );
        _recordingSink?.add(bytes);
        _recordedPcmBytes += bytes.length;
        _pitchPendingBytes.addAll(bytes);
        final pitchFrameBytes = _frameSize * 2;
        while (_pitchPendingBytes.length >= pitchFrameBytes) {
          final samples = _decodeFrame(_pitchPendingBytes, _frameSize);
          _pitchPendingBytes.removeRange(0, _hopSize * 2);
          final estimate = _estimatePitch(samples);
          if (estimate != null) {
            final midi =
                69 + 12 * (math.log(estimate.frequency / 440) / math.ln2);
            onPitch(
              PitchPoint(
                time: timestamp(),
                midiNote: midi,
                confidence: estimate.confidence,
              ),
            );
          }
        }
        _waveformPendingBytes.addAll(bytes);
        final waveformFrameBytes = _waveformWindowSamples * 2;
        while (_waveformPendingBytes.length >= waveformFrameBytes) {
          final samples = _decodeFrame(
            _waveformPendingBytes,
            _waveformWindowSamples,
          );
          _waveformPendingBytes.removeRange(0, waveformFrameBytes);
          final energy = samples.fold<double>(
            0,
            (total, sample) => total + sample * sample,
          );
          _waveform.add(
            math.sqrt(energy / samples.length).clamp(0.0, 1.0).toDouble(),
          );
          if (_waveform.length % 3 == 0) {
            onWaveform(List.unmodifiable(_waveform));
          }
        }
      },
      onError: (Object error) {
        _isRecording = false;
        _logDiagnostic('MIC: stream error: $error');
        onError(error);
      },
      onDone: () {
        final wasRecording = _isRecording;
        _isRecording = false;
        _logDiagnostic(
          'MIC: stream ended; bytes=$_receivedBytes waveformFrames=${_waveform.length}',
        );
        if (wasRecording) {
          onError(StateError('The microphone stream ended unexpectedly.'));
        }
      },
      cancelOnError: true,
    );
  }

  List<double> _decodeFrame(List<int> bytes, int sampleCount) {
    final frame = Uint8List.fromList(bytes.sublist(0, sampleCount * 2));
    final data = ByteData.sublistView(frame);
    return List<double>.generate(
      sampleCount,
      (index) => data.getInt16(index * 2, Endian.little) / 32768.0,
      growable: false,
    );
  }

  _PitchEstimate? _estimatePitch(List<double> samples) {
    _processedFrames++;
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    final rms = math.sqrt(energy / samples.length);
    if (!rms.isFinite || rms < _minimumRms) {
      if (_processedFrames == 1 || _processedFrames % 25 == 0) {
        _logDiagnostic(
          'PITCH: frame rejected by RMS=${rms.toStringAsFixed(4)} (minimum=$_minimumRms)',
        );
      }
      return null;
    }

    final minimumLag = (_sampleRate / _maximumFrequency).floor();
    final maximumLag = (_sampleRate / _minimumFrequency).ceil();
    final comparisonLength = samples.length - maximumLag;
    final differences = List<double>.filled(maximumLag + 1, 0);
    for (var lag = 1; lag <= maximumLag; lag++) {
      var difference = 0.0;
      for (var i = 0; i < comparisonLength; i++) {
        final delta = samples[i] - samples[i + lag];
        difference += delta * delta;
      }
      differences[lag] = difference;
    }

    final cumulativeMean = List<double>.filled(maximumLag + 1, 1);
    var runningSum = 0.0;
    for (var lag = 1; lag <= maximumLag; lag++) {
      runningSum += differences[lag];
      cumulativeMean[lag] = runningSum == 0
          ? 1
          : differences[lag] * lag / runningSum;
    }

    var selectedLag = -1;
    for (var lag = minimumLag; lag < maximumLag; lag++) {
      if (cumulativeMean[lag] < 0.22 &&
          cumulativeMean[lag] <= cumulativeMean[lag + 1]) {
        selectedLag = lag;
        while (selectedLag + 1 < maximumLag &&
            cumulativeMean[selectedLag + 1] < cumulativeMean[selectedLag]) {
          selectedLag++;
        }
        break;
      }
    }
    if (selectedLag < 0) {
      if (_processedFrames == 1 || _processedFrames % 25 == 0) {
        _logDiagnostic(
          'PITCH: no YIN periodicity candidate in frame $_processedFrames (RMS=${rms.toStringAsFixed(4)})',
        );
      }
      return null;
    }

    final left = cumulativeMean[selectedLag - 1];
    final center = cumulativeMean[selectedLag];
    final right = cumulativeMean[selectedLag + 1];
    final denominator = left - 2 * center + right;
    final adjustment = denominator.abs() < 1e-9
        ? 0.0
        : 0.5 * (left - right) / denominator;
    final refinedLag = selectedLag + adjustment.clamp(-1.0, 1.0);
    final frequency = _sampleRate / refinedLag;
    final confidence = 1 - center;
    if (_processedFrames == 1 || _processedFrames % 25 == 0) {
      _logDiagnostic(
        'PITCH: candidate ${frequency.toStringAsFixed(1)} Hz confidence=${confidence.toStringAsFixed(2)} RMS=${rms.toStringAsFixed(4)}',
      );
    }
    if (frequency < _minimumFrequency ||
        frequency > _maximumFrequency ||
        confidence < _minimumConfidence) {
      return null;
    }
    return _PitchEstimate(frequency, confidence.clamp(0.0, 1.0));
  }

  @override
  Future<void> pauseCapture() async {
    if (!_isRecording || _capturePaused) return;
    _capturePaused = true;
    _pitchPendingBytes.clear();
    _waveformPendingBytes.clear();
  }

  @override
  Future<void> resumeCapture() async {
    if (!_isRecording || !_capturePaused) return;
    _pitchPendingBytes.clear();
    _waveformPendingBytes.clear();
    _capturePaused = false;
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_recorderStarted) {
      await _recorder.stop();
      _recorderStarted = false;
    }
    _isRecording = false;
    _capturePaused = false;
    _pitchPendingBytes.clear();
    _waveformPendingBytes.clear();
    final sink = _recordingSink;
    _recordingSink = null;
    if (sink != null) {
      await sink.flush();
      await sink.close();
      final file = _recordingFile;
      if (file != null && _recordedPcmBytes > 0) {
        final handle = await file.open(mode: FileMode.writeOnly);
        await handle.setPosition(0);
        await handle.writeFrom(_wavHeader(_recordedPcmBytes));
        await handle.close();
      } else if (file != null) {
        await file.delete();
        _recordingFile = null;
      }
    }
  }

  @override
  Future<List<PitchPoint>> analyzeRecording() async {
    if (_isRecording) {
      throw StateError('Stop the microphone recording before analyzing it.');
    }
    final file = _recordingFile;
    if (file == null || !await file.exists() || await file.length() <= 44) {
      return const [];
    }
    final handle = await file.open(mode: FileMode.read);
    final points = <PitchPoint>[];
    var sampleOffset = 0;
    _processedFrames = 0;
    try {
      await handle.setPosition(44);
      final pending = <int>[];
      final frameBytes = _frameSize * 2;
      while (true) {
        final chunk = await handle.read(8192);
        if (chunk.isEmpty) break;
        pending.addAll(chunk);
        while (pending.length >= frameBytes) {
          final samples = _decodeFrame(pending, _frameSize);
          final estimate = _estimatePitch(samples);
          if (estimate != null) {
            final midi =
                69 + 12 * (math.log(estimate.frequency / 440) / math.ln2);
            final time = _timelinePositionAt(sampleOffset + _frameSize ~/ 2);
            points.add(
              PitchPoint(
                time: time,
                midiNote: midi,
                confidence: estimate.confidence,
              ),
            );
          }
          pending.removeRange(0, _hopSize * 2);
          sampleOffset += _hopSize;
        }
      }
    } finally {
      await handle.close();
    }
    _logDiagnostic(
      'PITCH: analyzed take frames=$_processedFrames accepted=${points.length}',
    );
    return List.unmodifiable(points);
  }

  Duration _timelinePositionAt(int sampleOffset) {
    if (_timelineMarkers.isEmpty) return Duration.zero;
    final target = sampleOffset.toDouble();
    var nextIndex = _timelineMarkers.indexWhere(
      (marker) => marker.sampleOffset >= target,
    );
    if (nextIndex < 0) return _timelineMarkers.last.position;
    if (nextIndex == 0) return _timelineMarkers.first.position;
    final before = _timelineMarkers[nextIndex - 1];
    final after = _timelineMarkers[nextIndex];
    final sampleSpan = after.sampleOffset - before.sampleOffset;
    if (sampleSpan <= 0) return before.position;
    final fraction = ((target - before.sampleOffset) / sampleSpan).clamp(
      0.0,
      1.0,
    );
    final timeSpan =
        after.position.inMicroseconds - before.position.inMicroseconds;
    return Duration(
      microseconds:
          before.position.inMicroseconds + (timeSpan * fraction).round(),
    );
  }

  List<int> _wavHeader(int dataBytes) {
    final header = ByteData(44);
    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        header.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, dataBytes + 36, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, dataBytes, Endian.little);
    return header.buffer.asUint8List();
  }

  void _logDiagnostic(String message) {
    if (kDebugMode) debugPrint(message);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _recorder.dispose();
    final file = _recordingFile;
    if (file != null && await file.exists()) await file.delete();
  }
}

class _PitchEstimate {
  final double frequency;
  final double confidence;

  const _PitchEstimate(this.frequency, this.confidence);
}

class _TimelineMarker {
  final int sampleOffset;
  final Duration position;

  const _TimelineMarker(this.sampleOffset, this.position);
}
