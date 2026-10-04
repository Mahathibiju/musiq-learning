enum BreathingExerciseId {
  breathControl,
  singersBreath,
  lipTongueTrill,
  breathToPhrase,
  randomChallenge,
}

enum BreathingPhase {
  inhale,
  hold,
  exhale,
  recovery,
  phrase,
  sustain,
  ready,
  complete,
}

class BreathingPhaseStep {
  final BreathingPhase phase;
  final int seconds;

  const BreathingPhaseStep(this.phase, this.seconds);
}

class BreathingExercise {
  final BreathingExerciseId id;
  final String title;
  final String subtitle;
  final String description;
  final String pattern;
  final List<BreathingPhaseStep> phases;
  final int rounds;

  const BreathingExercise({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.pattern,
    this.phases = const [],
    this.rounds = 1,
  });

  static const List<BreathingExercise> all = [
    BreathingExercise(
      id: BreathingExerciseId.breathControl,
      title: 'Breath Control',
      subtitle: 'Progressive guided rounds',
      description:
          'Build an even flow through gentle inhale, hold and longer exhale rounds. The timing gradually grows as you progress.',
      pattern: 'Inhale 4 · Hold 2 · Exhale 6',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 4),
        BreathingPhaseStep(BreathingPhase.hold, 2),
        BreathingPhaseStep(BreathingPhase.exhale, 6),
      ],
      rounds: 4,
    ),
    BreathingExercise(
      id: BreathingExerciseId.singersBreath,
      title: "Singer's Breath",
      subtitle: '3-octave chromatic sustain',
      description:
          'Move through a three-octave chromatic range. Choose a note with the arrows, then replay its timed sustain at your own pace.',
      pattern: 'C3 → B5 · 36 chromatic notes',
    ),
    BreathingExercise(
      id: BreathingExerciseId.lipTongueTrill,
      title: 'Lip Trill / Tongue Trill',
      subtitle: 'Keep the airflow light and steady',
      description:
          'Choose a lip or tongue trill, then follow the inhale, sustained trill and recovery through five relaxed rounds.',
      pattern: 'Inhale 3 · Trill 8 · Recover 2',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 3),
        BreathingPhaseStep(BreathingPhase.exhale, 8),
        BreathingPhaseStep(BreathingPhase.recovery, 2),
      ],
      rounds: 5,
    ),
    BreathingExercise(
      id: BreathingExerciseId.breathToPhrase,
      title: 'Breath-to-Phrase',
      subtitle: 'Connect a breath to a phrase',
      description:
          'Take a quiet breath, sustain a comfortable phrase through the guided count, then recover before the next round.',
      pattern: 'Inhale 3 · Phrase 10 · Recover 3',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 3),
        BreathingPhaseStep(BreathingPhase.phrase, 10),
        BreathingPhaseStep(BreathingPhase.recovery, 3),
      ],
      rounds: 4,
    ),
    BreathingExercise(
      id: BreathingExerciseId.randomChallenge,
      title: 'Random Breath Challenge',
      subtitle: 'A fresh pattern every time',
      description:
          'Start a four-round challenge with a randomly selected comfortable breathing pattern. Reset and start again for a new pattern.',
      pattern: 'Random inhale · hold · exhale · recover',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 3),
        BreathingPhaseStep(BreathingPhase.hold, 2),
        BreathingPhaseStep(BreathingPhase.exhale, 5),
        BreathingPhaseStep(BreathingPhase.recovery, 2),
      ],
      rounds: 4,
    ),
  ];

  static const List<BreathingExercise> randomRoutines = [
    BreathingExercise(
      id: BreathingExerciseId.randomChallenge,
      title: 'Random Breath Challenge',
      subtitle: 'Pattern A · 4 rounds',
      description: 'A balanced pattern with a smooth, longer exhale.',
      pattern: 'Inhale 3 · Hold 2 · Exhale 5 · Recover 2',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 3),
        BreathingPhaseStep(BreathingPhase.hold, 2),
        BreathingPhaseStep(BreathingPhase.exhale, 5),
        BreathingPhaseStep(BreathingPhase.recovery, 2),
      ],
      rounds: 4,
    ),
    BreathingExercise(
      id: BreathingExerciseId.randomChallenge,
      title: 'Random Breath Challenge',
      subtitle: 'Pattern B · 4 rounds',
      description: 'A measured pattern with a gentle pause at the top.',
      pattern: 'Inhale 4 · Hold 3 · Exhale 6 · Recover 2',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 4),
        BreathingPhaseStep(BreathingPhase.hold, 3),
        BreathingPhaseStep(BreathingPhase.exhale, 6),
        BreathingPhaseStep(BreathingPhase.recovery, 2),
      ],
      rounds: 4,
    ),
    BreathingExercise(
      id: BreathingExerciseId.randomChallenge,
      title: 'Random Breath Challenge',
      subtitle: 'Pattern C · 4 rounds',
      description: 'A compact cycle that keeps the breath moving calmly.',
      pattern: 'Inhale 3 · Hold 1 · Exhale 4 · Recover 2',
      phases: [
        BreathingPhaseStep(BreathingPhase.inhale, 3),
        BreathingPhaseStep(BreathingPhase.hold, 1),
        BreathingPhaseStep(BreathingPhase.exhale, 4),
        BreathingPhaseStep(BreathingPhase.recovery, 2),
      ],
      rounds: 4,
    ),
  ];
}

String breathingPhaseLabel(BreathingPhase phase) => switch (phase) {
      BreathingPhase.inhale => 'INHALE',
      BreathingPhase.hold => 'HOLD',
      BreathingPhase.exhale => 'EXHALE',
      BreathingPhase.recovery => 'RECOVER',
      BreathingPhase.phrase => 'SING YOUR PHRASE',
      BreathingPhase.sustain => 'SUSTAIN',
      BreathingPhase.ready => 'READY WHEN YOU ARE',
      BreathingPhase.complete => 'COMPLETE',
    };
