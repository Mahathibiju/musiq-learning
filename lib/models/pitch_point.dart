import 'dart:math' as math;

class PitchPoint {
  final Duration time;
  final double midiNote;
  final double confidence;

  const PitchPoint({
    required this.time,
    required this.midiNote,
    required this.confidence,
  });

  double get frequencyHz =>
      (440 * math.pow(2, (midiNote - 69) / 12)).toDouble();

  String get noteName {
    const names = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
    final midi = midiNote.round();
    return '${names[midi % 12]}${midi ~/ 12 - 1}';
  }
}
