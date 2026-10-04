import 'package:musiq_learning/models/musical_note.dart';

/// Enumeration of exercise difficulties.
enum ExerciseDifficulty {
  beginner,
  intermediate,
  advanced,
}

/// Enumeration of musical pitch directions.
enum ExercisePatternDirection {
  ascending,
  descending,
  ascendingDescending,
}

/// Enumeration of Indian classical Swara exercise types.
enum SwaraExerciseType {
  saraliVarisai,
  jantaVarisai,
  daatuVarisai,
  gamakaPractice,
}

/// Model representing a generated vocal exercise.
class GeneratedVocalExercise {
  final String title;
  final String categoryName;
  final String notesPattern;
  final String? phoneticSyllables;
  final String techniqueNote;
  final int recommendedBpm;
  final List<MusicalNote> notes;

  const GeneratedVocalExercise({
    required this.title,
    required this.categoryName,
    required this.notesPattern,
    this.phoneticSyllables,
    required this.techniqueNote,
    required this.recommendedBpm,
    this.notes = const [],
  });
}

/// Musically sensible, deterministic exercise generator for vocal categories.
class ExerciseGenerator {
  /// Generate an exercise given the category, difficulty, direction, and optional swara type.
  static GeneratedVocalExercise generate({
    required String categoryName,
    required ExerciseDifficulty difficulty,
    required ExercisePatternDirection direction,
    SwaraExerciseType swaraType = SwaraExerciseType.saraliVarisai,
    int variationIndex = 0,
  }) {
    final normalizedCategory = categoryName.toLowerCase();
    GeneratedVocalExercise raw;

    if (normalizedCategory.contains('swara')) {
      raw = _generateSwaraExercise(difficulty, direction, swaraType, variationIndex);
    } else if (normalizedCategory.contains('chest')) {
      raw = _generateChestVoiceExercise(difficulty, direction, variationIndex);
    } else if (normalizedCategory.contains('head')) {
      raw = _generateHeadVoiceExercise(difficulty, direction, variationIndex);
    } else {
      // Mixed voice
      raw = _generateMixedVoiceExercise(difficulty, direction, variationIndex);
    }

    final parsedNotes = parsePatternToNotes(raw.notesPattern, raw.categoryName);

    return GeneratedVocalExercise(
      title: raw.title,
      categoryName: raw.categoryName,
      notesPattern: raw.notesPattern,
      phoneticSyllables: raw.phoneticSyllables,
      techniqueNote: raw.techniqueNote,
      recommendedBpm: raw.recommendedBpm,
      notes: parsedNotes,
    );
  }

  /// Extracts structured musical notes with exact frequencies from generated pattern text.
  static List<MusicalNote> parsePatternToNotes(String pattern, String categoryName) {
    final List<MusicalNote> result = [];
    final isSwara = categoryName.toLowerCase().contains('swara');

    if (isSwara) {
      final rawTokens = pattern
          .replaceAll('|', ' ')
          .replaceAll('\n', ' ')
          .split(' ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != '|')
          .toList();

      for (final token in rawTokens) {
        String primary = 'Sa';
        if (token.contains('Ṡ')) {
          primary = 'Ṡ';
        } else if (token.contains('Sa')) {
          primary = 'Sa';
        } else if (token.contains('Re')) {
          primary = 'Re';
        } else if (token.contains('Ga')) {
          primary = 'Ga';
        } else if (token.contains('Ma')) {
          primary = 'Ma';
        } else if (token.contains('Pa')) {
          primary = 'Pa';
        } else if (token.contains('Dha')) {
          primary = 'Dha';
        } else if (token.contains('Ni')) {
          primary = 'Ni';
        }

        result.add(MusicalNote(
          symbol: primary,
          frequencyHz: MusicalNote.getSwaraFrequency(primary),
          displayLabel: token,
        ));
      }
    } else {
      final regExp = RegExp(r'[A-G][#b]?[0-9]');
      final matches = regExp.allMatches(pattern);
      for (final match in matches) {
        final noteStr = match.group(0)!;
        result.add(MusicalNote(
          symbol: noteStr,
          frequencyHz: MusicalNote.getWesternFrequency(noteStr),
          displayLabel: noteStr,
        ));
      }
    }

    if (result.isEmpty) {
      result.add(const MusicalNote(
        symbol: 'Sa',
        frequencyHz: 261.63,
        displayLabel: 'Sa',
      ));
    }

    return result;
  }

  // ==========================================
  // 1. SWARAS GENERATOR
  // ==========================================
  static GeneratedVocalExercise _generateSwaraExercise(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    SwaraExerciseType swaraType,
    int variant,
  ) {
    switch (swaraType) {
      case SwaraExerciseType.saraliVarisai:
        return _buildSaraliVarisai(difficulty, direction, variant);
      case SwaraExerciseType.jantaVarisai:
        return _buildJantaVarisai(difficulty, direction, variant);
      case SwaraExerciseType.daatuVarisai:
        return _buildDaatuVarisai(difficulty, direction, variant);
      case SwaraExerciseType.gamakaPractice:
        return _buildGamakaPractice(difficulty, direction, variant);
    }
  }

  static GeneratedVocalExercise _buildSaraliVarisai(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'Sa Re Ga Ma | Pa Dha Ni Ṡ',
          'Sa Re Ga Ma Pa | Pa Dha Ni Ṡ',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ni Dha Pa | Ma Ga Re Sa',
          'Ṡ Ni Dha Pa Ma | Ma Ga Re Sa',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Re Ga Ma Pa Dha Ni Ṡ |\nṠ Ni Dha Pa Ma Ga Re Sa',
          'Sa Re Ga Ma Pa |\nPa Ma Ga Re Sa',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'Sa Re Sa Re | Sa Re Ga Ma |\nRe Ga Re Ga | Re Ga Ma Pa',
          'Sa Re Ga Re | Sa Re Ga Ma |\nRe Ga Ma Ga | Re Ga Ma Pa',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ni Ṡ Ni | Ṡ Ni Dha Pa |\nNi Dha Ni Dha | Ni Dha Pa Ma',
          'Ṡ Ni Dha Ni | Ṡ Ni Dha Pa |\nNi Dha Pa Dha | Ni Dha Pa Ma',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Re Sa Re Sa Re Ga Ma |\nṠ Ni Ṡ Ni Ṡ Ni Dha Pa |\nNi Dha Pa Ma Ga Re Sa',
          'Sa Re Ga Re Sa Re Ga Ma |\nṠ Ni Dha Ni Ṡ Ni Dha Pa |\nMa Ga Re Sa',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'Sa Re Ga Ma Pa Ma Ga Re | Sa Re Ga Ma Pa Dha Ni Ṡ',
          'Sa Re Ga Ma Pa Dha Pa Ma | Pa Dha Ni Ṡ Ni Dha Pa Ṡ',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ni Dha Pa Ma Pa Dha Ni | Ṡ Ni Dha Pa Ma Ga Re Sa',
          'Ṡ Ni Dha Pa Ma Ga Ma Pa | Ma Ga Re Sa Ni Dha Pa Sa',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Re Ga Ma Pa Ma Ga Re | Sa Re Ga Ma Pa Dha Ni Ṡ |\nṠ Ni Dha Pa Ma Pa Dha Ni | Ṡ Ni Dha Pa Ma Ga Re Sa',
          'Sa Re Ga Ma Pa Dha Ni Ṡ | Ṡ Ni Dha Pa Ma Ga Re Sa |\nSa Ga Re Ma Ga Pa Ma Dha | Pa Ṡ Ni Dha Pa Ma Ga Sa',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Sarali Varisai (${_getDirectionLabel(direction)})',
      categoryName: 'Swaras',
      notesPattern: pattern,
      phoneticSyllables: 'Classical Swara Syllables (Shuddha / Prathama)',
      techniqueNote:
          'Maintain steady Tala tempo. Keep pitch transitions crisp and pure on each swara.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 60
          : difficulty == ExerciseDifficulty.intermediate
              ? 80
              : 100,
    );
  }

  static GeneratedVocalExercise _buildJantaVarisai(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'Sa Sa Re Re | Ga Ga Ma Ma |\nPa Pa Dha Dha | Ni Ni Ṡ Ṡ',
          'Sa Sa Re Re Ga Ga | Re Re Ga Ga Ma Ma',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ṡ Ni Ni | Dha Dha Pa Pa |\nMa Ma Ga Ga | Re Re Sa Sa',
          'Ṡ Ṡ Ni Ni Dha Dha | Ni Ni Dha Dha Pa Pa',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Sa Re Re Ga Ga Ma Ma | Pa Pa Dha Dha Ni Ni Ṡ Ṡ |\nṠ Ṡ Ni Ni Dha Dha Pa Pa | Ma Ma Ga Ga Re Re Sa Sa',
          'Sa Sa Re Re Ga Ga Ma Ma |\nMa Ma Ga Ga Re Re Sa Sa',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'Sa Sa Re Re Ga Ga Ma Ma |\nRe Re Ga Ga Ma Ma Pa Pa |\nGa Ga Ma Ma Pa Pa Dha Dha',
          'Sa Sa Re Re Ga Ma |\nRe Re Ga Ga Ma Pa |\nGa Ga Ma Ma Pa Dha',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ṡ Ni Ni Dha Dha Pa Pa |\nNi Ni Dha Dha Pa Pa Ma Ma |\nDha Dha Pa Pa Ma Ma Ga Ga',
          'Ṡ Ṡ Ni Ni Dha Pa |\nNi Ni Dha Dha Pa Ma |\nDha Dha Pa Pa Ma Ga',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Sa Re Re Ga Ga Ma Ma | Re Re Ga Ga Ma Ma Pa Pa |\nṠ Ṡ Ni Ni Dha Dha Pa Pa | Ni Ni Dha Dha Pa Pa Ma Ma',
          'Sa Sa Re Re Ga Ma | Pa Pa Dha Dha Ni Ṡ |\nṠ Ṡ Ni Ni Dha Pa | Ma Ma Ga Ga Re Sa',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'Sa Re Sa Re Sa Sa Re Re | Re Ga Re Ga Re Re Ga Ga |\nGa Ma Ga Ma Ga Ga Ma Ma | Pa Dha Pa Dha Pa Pa Dha Dha',
          'Sa Sa Re Sa Sa Re Re Ga | Re Re Ga Re Re Ga Ga Ma',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ni Ṡ Ni Ṡ Ṡ Ni Ni | Ni Dha Ni Dha Ni Ni Dha Dha |\nDha Pa Dha Pa Dha Dha Pa Pa | Pa Ma Pa Ma Pa Pa Ma Ma',
          'Ṡ Ṡ Ni Ṡ Ṡ Ni Ni Dha | Ni Ni Dha Ni Ni Dha Dha Pa',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Re Sa Re Sa Sa Re Re | Ga Ma Ga Ma Ga Ga Ma Ma |\nṠ Ni Ṡ Ni Ṡ Ṡ Ni Ni | Dha Pa Dha Pa Dha Dha Pa Pa',
          'Sa Sa Re Re Ga Ga Ma Ma Pa Pa Dha Dha Ni Ni Ṡ Ṡ |\nṠ Ṡ Ni Ni Dha Dha Pa Pa Ma Ma Ga Ga Re Re Sa Sa',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Janta Varisai (${_getDirectionLabel(direction)})',
      categoryName: 'Swaras',
      notesPattern: pattern,
      phoneticSyllables: 'Twin Swaras (Sphurita / Forceful Accent)',
      techniqueNote:
          'Emphasize the second swara with subtle diaphragm impulse without tightening the throat.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 65
          : difficulty == ExerciseDifficulty.intermediate
              ? 85
              : 105,
    );
  }

  static GeneratedVocalExercise _buildDaatuVarisai(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'Sa Ga Re Ma | Ga Pa Ma Dha | Pa Ni Dha Ṡ',
          'Sa Ga Re Ga | Re Ma Ga Ma | Ga Pa Ma Pa',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Dha Ni Pa | Dha Ma Pa Ga | Ma Re Ga Sa',
          'Ṡ Dha Ni Dha | Ni Pa Dha Pa | Dha Ma Pa Ma',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Ga Re Ma Ga Pa Ma Dha | Pa Ni Dha Ṡ |\nṠ Dha Ni Pa Dha Ma Pa Ga | Ma Re Ga Sa',
          'Sa Ga Re Ma Ga Pa |\nPa Ma Ga Re Ga Sa',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'Sa Re Sa Ga | Re Ga Re Ma | Ga Ma Ga Pa |\nMa Pa Ma Dha | Pa Dha Pa Ni | Dha Ni Dha Ṡ',
          'Sa Ga Re Sa | Re Ma Ga Re | Ga Pa Ma Ga',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ni Ṡ Dha | Ni Dha Ni Pa | Dha Pa Dha Ma |\nPa Ma Pa Ga | Ma Ga Ma Re | Ga Re Ga Sa',
          'Ṡ Dha Ni Ṡ | Ni Pa Dha Ni | Dha Ma Pa Dha',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Re Sa Ga Re Ga Re Ma | Ga Ma Ga Pa Ma Pa Ma Dha |\nṠ Ni Ṡ Dha Ni Dha Ni Pa | Dha Pa Dha Ma Pa Ma Pa Ga',
          'Sa Ga Re Sa Re Ma Ga Re |\nṠ Dha Ni Ṡ Ni Pa Dha Ni | Pa Ma Ga Re Sa',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'Sa Re Ga Sa | Re Ga Ma Re | Ga Ma Pa Ga |\nMa Pa Dha Ma | Pa Dha Ni Pa | Dha Ni Ṡ Dha',
          'Sa Ga Pa Ma | Re Ma Dha Pa | Ga Pa Ni Dha | Ma Dha Ṡ Ni',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ Ni Dha Ṡ | Ni Dha Pa Ni | Dha Pa Ma Dha |\nPa Ma Ga Pa | Ma Ga Re Ma | Ga Re Sa Ga',
          'Ṡ Dha Ma Pa | Ni Pa Ga Ma | Dha Ma Re Ga | Pa Ga Sa Re',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa Re Ga Sa Re Ga Ma Re | Ga Ma Pa Ga Ma Pa Dha Ma |\nṠ Ni Dha Ṡ Ni Dha Pa Ni | Dha Pa Ma Dha Pa Ma Ga Pa',
          'Sa Ga Pa Ma Re Ma Dha Pa | Pa Ni Dha Ṡ |\nṠ Dha Ma Pa Ni Pa Ga Ma | Ga Re Sa',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Daatu Varisai (${_getDirectionLabel(direction)})',
      categoryName: 'Swaras',
      notesPattern: pattern,
      phoneticSyllables: 'Interlocking & Skipping Swaras',
      techniqueNote:
          'Precision in melodic interval jumps. Do not slide arbitrarily; land directly on center pitch.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 60
          : difficulty == ExerciseDifficulty.intermediate
              ? 75
              : 95,
    );
  }

  static GeneratedVocalExercise _buildGamakaPractice(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'Sa ~ (Re) ~ Sa | Re ~ (Ga) ~ Re | Ga ~ (Ma) ~ Ga | Pa ~ (Dha) ~ Pa',
          'Sa (Re~Sa) | Re (Ga~Re) | Ga (Ma~Ga) | Pa (Dha~Pa)',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ ~ (Ni) ~ Ṡ | Ni ~ (Dha) ~ Ni | Dha ~ (Pa) ~ Dha | Pa ~ (Ma) ~ Pa',
          'Ṡ (Ni~Ṡ) | Ni (Dha~Ni) | Dha (Pa~Dha) | Pa (Ma~Pa)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa ~ (Re) ~ Sa | Pa ~ (Dha) ~ Pa | Ṡ ~ (Ni) ~ Ṡ |\nṠ ~ (Ni) ~ Ṡ | Pa ~ (Ma) ~ Pa | Sa ~ (Re) ~ Sa',
          'Sa (Re~Sa) | Ga (Ma~Ga) | Pa (Dha~Pa) |\nPa (Ma~Pa) | Ga (Re~Ga) | Sa',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'Sa - Re ~ Re ~ Sa | Re - Ga ~ Ga ~ Re |\nGa - Ma ~ Ma ~ Ga | Pa - Dha ~ Dha ~ Pa',
          'Sa Re (Ga~Re~Ga) | Re Ga (Ma~Ga~Ma) | Ga Ma (Pa~Ma~Pa)',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ - Ni ~ Ni ~ Ṡ | Ni - Dha ~ Dha ~ Ni |\nDha - Pa ~ Pa ~ Dha | Pa - Ma ~ Ma ~ Pa',
          'Ṡ Ni (Dha~Ni~Dha) | Ni Dha (Pa~Dha~Pa) | Dha Pa (Ma~Pa~Ma)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa - Re ~ Re ~ Sa | Pa - Dha ~ Dha ~ Pa | Ṡ - Ni ~ Ni ~ Ṡ |\nṠ - Ni ~ Ni ~ Ṡ | Pa - Ma ~ Ma ~ Pa | Sa - Re ~ Re ~ Sa',
          'Sa Re (Ga~Re~Ga) Ma | Pa Dha (Ni~Dha~Ni) Ṡ |\nṠ Ni (Dha~Ni~Dha) Pa | Ma Ga (Re~Ga~Re) Sa',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'Sa (Re~Ga~Re) Sa | Re (Ga~Ma~Ga) Re |\nGa (Ma~Pa~Ma) Ga | Pa (Dha~Ni~Dha) Pa',
          'Sa Re (Ga~Re~Ga~Re) Ma | Re Ga (Ma~Ga~Ma~Ga) Pa | Ga Ma (Pa~Ma~Pa~Ma) Dha',
        ],
        ExercisePatternDirection.descending: [
          'Ṡ (Ni~Dha~Ni) Ṡ | Ni (Dha~Pa~Dha) Ni |\nDha (Pa~Ma~Pa) Dha | Pa (Ma~Ga~Ma) Pa',
          'Ṡ Ni (Dha~Ni~Dha~Ni) Pa | Ni Dha (Pa~Dha~Pa~Dha) Ma | Dha Pa (Ma~Pa~Ma~Pa) Ga',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'Sa (Re~Ga~Re) Sa | Pa (Dha~Ni~Dha) Pa | Ṡ (Ni~Dha~Ni) Ṡ |\nṠ (Ni~Dha~Ni) Ṡ | Pa (Ma~Ga~Ma) Pa | Sa (Re~Ga~Re) Sa',
          'Sa Re (Ga~Re~Ga) Ma Pa | Ṡ Ni (Dha~Ni~Dha) Pa Ma | Ga (Re~Ga~Re) Sa',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Gamaka Practice (${_getDirectionLabel(direction)})',
      categoryName: 'Swaras',
      notesPattern: pattern,
      phoneticSyllables: 'Oscillation & Deflection Study (Kampita / Nokku)',
      techniqueNote:
          'Structured wave-like oscillation between parent note and adjacent grace swara. Target precise pitch curves.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 55
          : difficulty == ExerciseDifficulty.intermediate
              ? 65
              : 80,
    );
  }

  // ==========================================
  // 2. CHEST VOICE GENERATOR
  // ==========================================
  static GeneratedVocalExercise _generateChestVoiceExercise(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'C3 - D3 - E3 - F3 - G3\n(Mum - Mum - Mum - Mum - Mum)',
          'C3 - E3 - G3\n(Buh - Buh - Buh)',
        ],
        ExercisePatternDirection.descending: [
          'G3 - F3 - E3 - D3 - C3\n(Mum - Mum - Mum - Mum - Mum)',
          'G3 - E3 - C3\n(Buh - Buh - Buh)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'C3 - D3 - E3 - F3 - G3 - F3 - E3 - D3 - C3\n(Mum - Mum - Mum - Mum - Mum - Mum - Mum - Mum - Mum)',
          'C3 - E3 - G3 - E3 - C3\n(Buh - Buh - Buh - Buh - Buh)',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'C3 - E3 - G3 - E3 - G3 - C4\n(Gug - Gug - Gug - Gug - Gug - Gug)',
          'A2 - C3 - E3 - A3\n(Mum - Mum - Mum - Mum)',
        ],
        ExercisePatternDirection.descending: [
          'C4 - G3 - E3 - G3 - E3 - C3\n(Gug - Gug - Gug - Gug - Gug - Gug)',
          'A3 - E3 - C3 - A2\n(Mum - Mum - Mum - Mum)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'C3 - E3 - G3 - C4 - G3 - E3 - C3\n(Gug - Gug - Gug - Gug - Gug - Gug - Gug)',
          'A2 - C3 - E3 - A3 - E3 - C3 - A2\n(Buh - Buh - Buh - Buh - Buh - Buh - Buh)',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'C3 - D3 - E3 - C3 - D3 - E3 - F3 - G3 - C4\n(Brat - Brat - Brat - Brat - Brat - Brat - Brat - Brat - Brat)',
          'C3 - E3 - G3 - B3 - C4\n(Gug - Gug - Gug - Gug - Gug)',
        ],
        ExercisePatternDirection.descending: [
          'C4 - B3 - G3 - E3 - F3 - D3 - C3\n(Brat - Brat - Brat - Brat - Brat - Brat - Brat)',
          'C4 - B3 - G3 - E3 - C3\n(Gug - Gug - Gug - Gug - Gug)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'C3 - E3 - G3 - B3 - C4 - B3 - G3 - E3 - C3\n(Brat - Brat - Brat - Brat - Brat - Brat - Brat - Brat - Brat)',
          'A2 - C3 - E3 - A3 - C4 - A3 - E3 - C3 - A2\n(Gug - Gug - Gug - Gug - Gug - Gug - Gug - Gug - Gug)',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Chest Voice Drill (${_getDirectionLabel(direction)})',
      categoryName: 'Chest Voice',
      notesPattern: pattern,
      phoneticSyllables: 'Resonant Consonants: [Mum], [Buh], [Gug]',
      techniqueNote:
          'Feel deep resonance in your sternum and collarbone. Avoid pressing the laryngeal muscles downward.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 70
          : difficulty == ExerciseDifficulty.intermediate
              ? 85
              : 100,
    );
  }

  // ==========================================
  // 3. HEAD VOICE GENERATOR
  // ==========================================
  static GeneratedVocalExercise _generateHeadVoiceExercise(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'G4 - A4 - B4 - C5 - D5\n(Wee - Wee - Wee - Wee - Wee)',
          'G4 - B4 - D5\n(Noo - Noo - Noo)',
        ],
        ExercisePatternDirection.descending: [
          'D5 - C5 - B4 - A4 - G4\n(Noo - Noo - Noo - Noo - Noo)',
          'D5 - B4 - G4\n(Wee - Wee - Wee)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'G4 - A4 - B4 - C5 - D5 - C5 - B4 - A4 - G4\n(Wee - Wee - Wee - Wee - Wee - Wee - Wee - Wee - Wee)',
          'G4 - B4 - D5 - B4 - G4\n(Noo - Noo - Noo - Noo - Noo)',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'G4 - C5 - E5 - C5 - G5\n(Ooh - Ooh - Ooh - Ooh - Ooh)',
          'A4 - C5 - E5 - A5\n(Wee - Wee - Wee - Wee)',
        ],
        ExercisePatternDirection.descending: [
          'G5 - E5 - C5 - E5 - C5 - G4\n(Ooh - Ooh - Ooh - Ooh - Ooh - Ooh)',
          'A5 - E5 - C5 - A4\n(Wee - Wee - Wee - Wee)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'G4 - C5 - E5 - G5 - E5 - C5 - G4\n(Ooh - Ooh - Ooh - Ooh - Ooh - Ooh - Ooh)',
          'A4 - C5 - E5 - A5 - E5 - C5 - A4\n(Wee - Wee - Wee - Wee - Wee - Wee - Wee)',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'G4 - B4 - D5 - F5 - G5\n(Siren: Wee - Wee - Wee - Wee - Wee)',
          'E4 - G4 - B4 - E5 - G5\n(Noo - Noo - Noo - Noo - Noo)',
        ],
        ExercisePatternDirection.descending: [
          'G5 - F5 - D5 - B4 - G4\n(Siren: Wee - Wee - Wee - Wee - Wee)',
          'G5 - E5 - B4 - G4 - E4\n(Noo - Noo - Noo - Noo - Noo)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'G4 - B4 - D5 - F5 - G5 - F5 - D5 - B4 - G4\n(Wee - Wee - Wee - Wee - Wee - Wee - Wee - Wee - Wee)',
          'E4 - G4 - B4 - E5 - G5 - E5 - B4 - G4 - E4\n(Noo - Noo - Noo - Noo - Noo - Noo - Noo - Noo - Noo)',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Head Voice Drill (${_getDirectionLabel(direction)})',
      categoryName: 'Head Voice',
      notesPattern: pattern,
      phoneticSyllables: 'Forward Placement Vowels: [Wee], [Noo], [Ooh]',
      techniqueNote:
          'Keep the sound light, bright, and buoyant. Avoid forcing volume; imagine sound releasing from the crown of your head.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 75
          : difficulty == ExerciseDifficulty.intermediate
              ? 90
              : 110,
    );
  }

  // ==========================================
  // 4. MIXED VOICE GENERATOR
  // ==========================================
  static GeneratedVocalExercise _generateMixedVoiceExercise(
    ExerciseDifficulty difficulty,
    ExercisePatternDirection direction,
    int variant,
  ) {
    final patterns = {
      ExerciseDifficulty.beginner: {
        ExercisePatternDirection.ascending: [
          'C4 - D4 - E4 - F4 - G4 - A4\n(Nay - Nay - Nay - Nay - Nay - Nay)',
          'C4 - E4 - G4 - A4\n(Gee - Gee - Gee - Gee)',
        ],
        ExercisePatternDirection.descending: [
          'A4 - G4 - F4 - E4 - D4 - C4\n(Nay - Nay - Nay - Nay - Nay - Nay)',
          'A4 - G4 - E4 - C4\n(Gee - Gee - Gee - Gee)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'C4 - E4 - G4 - A4 - G4 - E4 - C4\n(Nay - Nay - Nay - Nay - Nay - Nay - Nay)',
          'C4 - D4 - E4 - F4 - G4 - F4 - E4 - D4 - C4\n(Gee - Gee - Gee - Gee - Gee - Gee - Gee - Gee - Gee)',
        ],
      },
      ExerciseDifficulty.intermediate: {
        ExercisePatternDirection.ascending: [
          'C4 - E4 - G4 - C5\n(Passaggio Bridge: Nay - Nay - Nay - Nay)',
          'D4 - F#4 - A4 - D5\n(Gee - Gee - Gee - Gee)',
        ],
        ExercisePatternDirection.descending: [
          'C5 - G4 - E4 - C4\n(Passaggio Bridge: Nay - Nay - Nay - Nay)',
          'D5 - A4 - F#4 - D4\n(Gee - Gee - Gee - Gee)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'C4 - E4 - G4 - C5 - G4 - E4 - C4\n(Nay - Nay - Nay - Nay - Nay - Nay - Nay)',
          'D4 - F#4 - A4 - D5 - A4 - F#4 - D4\n(Gee - Gee - Gee - Gee - Gee - Gee - Gee)',
        ],
      },
      ExerciseDifficulty.advanced: {
        ExercisePatternDirection.ascending: [
          'C4 - D4 - E4 - F4 - G4 - A4 - B4 - C5 - D5\n(Full 9-Tone Octave Scale: Nay)',
          'C4 - G4 - C5 - E5\n(1.5 Octave Arpeggio: Gee)',
        ],
        ExercisePatternDirection.descending: [
          'D5 - C5 - B4 - A4 - G4 - F4 - E4 - D4 - C4\n(Full 9-Tone Octave Scale: Nay)',
          'E5 - C5 - G4 - C4\n(1.5 Octave Arpeggio: Gee)',
        ],
        ExercisePatternDirection.ascendingDescending: [
          'C4 - E4 - G4 - C5 - E5 - C5 - G4 - E4 - C4\n(Octave + Third Blend: Nay)',
          'C4 - D4 - E4 - F4 - G4 - A4 - B4 - C5 - D5 - C5 - B4 - A4 - G4 - F4 - E4 - D4 - C4\n(Full 9-Tone Ascending + Descending Run)',
        ],
      },
    };

    final list = patterns[difficulty]![direction]!;
    final pattern = list[variant % list.length];

    return GeneratedVocalExercise(
      title: 'Mixed Voice Bridge (${_getDirectionLabel(direction)})',
      categoryName: 'Mixed Voice',
      notesPattern: pattern,
      phoneticSyllables: 'Brassy Pharyngeal Syllables: [Nay], [Gee]',
      techniqueNote:
          'Maintain steady cord closure through the passaggio without flipping into falsetto or yelling.',
      recommendedBpm: difficulty == ExerciseDifficulty.beginner
          ? 70
          : difficulty == ExerciseDifficulty.intermediate
              ? 85
              : 105,
    );
  }

  static String _getDirectionLabel(ExercisePatternDirection direction) {
    switch (direction) {
      case ExercisePatternDirection.ascending:
        return 'Ascending';
      case ExercisePatternDirection.descending:
        return 'Descending';
      case ExercisePatternDirection.ascendingDescending:
        return 'Asc + Desc';
    }
  }
}
