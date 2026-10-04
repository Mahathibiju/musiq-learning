/// Represents a musical note or swara with acoustic pitch frequency and duration.
class MusicalNote {
  final String symbol; // e.g. "Sa", "Re", "Ga", "C3", "G4"
  final double frequencyHz; // e.g. 261.63
  final double durationBeats; // e.g. 1.0 (1 beat)
  final String displayLabel; // e.g. "Sa", "Re", "C3"

  const MusicalNote({
    required this.symbol,
    required this.frequencyHz,
    this.durationBeats = 1.0,
    required this.displayLabel,
  });

  /// Standard reference tonic (Middle C / C4 ≈ 261.63 Hz).
  static const double baseC4 = 261.63;

  /// Returns the exact frequency for Indian Classical Swaras relative to base tonic.
  static double getSwaraFrequency(String swara, {double baseHz = baseC4}) {
    final clean = swara.replaceAll(RegExp(r'[^\wṠṘĠṀŅḎ~.]'), '').trim();

    // Tara Sthayi (Upper Octave)
    if (clean == 'Ṡ' || clean == "Sa'" || clean == 'S.') return baseHz * 2.0;
    if (clean == 'Ṙ' || clean == "Re'" || clean == 'R.') return baseHz * (9.0 / 8.0) * 2.0;
    if (clean == 'Ġ' || clean == "Ga'" || clean == 'G.') return baseHz * (5.0 / 4.0) * 2.0;
    if (clean == 'Ṁ' || clean == "Ma'" || clean == 'M.') return baseHz * (4.0 / 3.0) * 2.0;

    // Mandra Sthayi (Lower Octave)
    if (clean == 'Ni.' || clean == 'Ņi' || clean == 'Ni_') return baseHz * (15.0 / 8.0) / 2.0;
    if (clean == 'Dha.' || clean == 'Ḏha' || clean == 'Dha_') return baseHz * (5.0 / 3.0) / 2.0;
    if (clean == 'Pa.' || clean == 'Pa_') return baseHz * (3.0 / 2.0) / 2.0;

    // Madhya Sthayi (Middle Octave)
    if (clean.startsWith('Sa')) return baseHz * 1.0;
    if (clean.startsWith('Re')) return baseHz * (9.0 / 8.0); // 294.33 Hz
    if (clean.startsWith('Ga')) return baseHz * (5.0 / 4.0); // 327.03 Hz
    if (clean.startsWith('Ma')) return baseHz * (4.0 / 3.0); // 348.84 Hz
    if (clean.startsWith('Pa')) return baseHz * (3.0 / 2.0); // 392.44 Hz
    if (clean.startsWith('Dha')) return baseHz * (5.0 / 3.0); // 436.05 Hz
    if (clean.startsWith('Ni')) return baseHz * (15.0 / 8.0); // 490.55 Hz

    return baseHz;
  }

  /// Returns the exact frequency for Western chromatic note names (e.g. C3, G3, C4, G4, C5).
  static double getWesternFrequency(String noteName) {
    final clean = noteName.toUpperCase().trim();
    final noteMap = <String, double>{
      'A2': 110.00,
      'B2': 123.47,
      'C3': 130.81,
      'D3': 146.83,
      'E3': 164.81,
      'F3': 174.61,
      'G3': 196.00,
      'A3': 220.00,
      'B3': 246.94,
      'C4': 261.63,
      'D4': 293.66,
      'E4': 329.63,
      'F4': 349.23,
      'F#4': 369.99,
      'G4': 392.00,
      'A4': 440.00,
      'B4': 493.88,
      'C5': 523.25,
      'D5': 587.33,
      'E5': 659.25,
      'F5': 698.46,
      'G5': 783.99,
      'A5': 880.00,
    };

    for (final entry in noteMap.entries) {
      if (clean.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return baseC4;
  }
}
