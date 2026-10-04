import 'dart:math';
import 'dart:typed_data';

/// Pure-Dart acoustic tone synthesizer.
/// Generates click-free 16-bit PCM WAV audio in memory with harmonic overtones
/// and a smooth ADSR (Attack, Decay, Sustain, Release) envelope.
class ToneGenerator {
  static const int sampleRate = 44100;

  // In-memory cache for generated WAV byte buffers (keyed by "$freq-$durationMs")
  static final Map<String, Uint8List> _cache = {};

  /// Generates or retrieves cached 16-bit mono PCM WAV bytes for a given pitch and duration.
  static Uint8List generateToneBytes({
    required double frequencyHz,
    required int durationMs,
    double volume = 0.85,
  }) {
    final key = '${frequencyHz.toStringAsFixed(1)}-$durationMs';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final int numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final int byteCount = numSamples * 2; // 16-bit = 2 bytes per sample

    // 44-byte standard RIFF/WAVE header + PCM sample bytes
    final ByteData byteData = ByteData(44 + byteCount);

    // 1. RIFF Chunk Descriptor
    _writeString(byteData, 0, 'RIFF');
    byteData.setUint32(4, 36 + byteCount, Endian.little);
    _writeString(byteData, 8, 'WAVE');

    // 2. "fmt " Sub-chunk
    _writeString(byteData, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    byteData.setUint16(22, 1, Endian.little); // NumChannels (1 = Mono)
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little); // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample

    // 3. "data" Sub-chunk
    _writeString(byteData, 36, 'data');
    byteData.setUint32(40, byteCount, Endian.little);

    // 4. Acoustic waveform generation with harmonic overtones and ADSR envelope
    final attackSamples = (sampleRate * 0.030).round(); // 30ms smooth attack
    final releaseSamples = (sampleRate * 0.040).round(); // 40ms smooth release

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;

      // Acoustic harmonic mix for pleasant, organic vocal/organ timbre
      final double fundamental = sin(2 * pi * frequencyHz * t);
      final double harmonic2 = 0.22 * sin(4 * pi * frequencyHz * t);
      final double harmonic3 = 0.08 * sin(6 * pi * frequencyHz * t);
      double sample = (fundamental + harmonic2 + harmonic3) / 1.30;

      // Anti-click ADSR Envelope
      double envelope = 1.0;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i > numSamples - releaseSamples) {
        envelope = (numSamples - i) / releaseSamples;
      }

      sample = (sample * envelope * volume).clamp(-1.0, 1.0);
      final int intSample = (sample * 32767).toInt();
      byteData.setInt16(44 + (i * 2), intSample, Endian.little);
    }

    final Uint8List result = byteData.buffer.asUint8List();
    _cache[key] = result;
    return result;
  }

  static void _writeString(ByteData byteData, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      byteData.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  static void clearCache() {
    _cache.clear();
  }
}
