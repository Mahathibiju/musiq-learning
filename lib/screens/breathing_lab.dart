import 'dart:async';

import 'package:flutter/material.dart';
import 'package:musiq_learning/models/breathing_exercise.dart';
import 'package:musiq_learning/services/breathing_session_controller.dart';
import 'package:musiq_learning/services/exercise_playback_controller.dart';
import 'package:musiq_learning/widgets/breathing_phase_visual.dart';

class BreathingLabScreen extends StatefulWidget {
  const BreathingLabScreen({super.key});

  @override
  State<BreathingLabScreen> createState() => _BreathingLabScreenState();
}

class _BreathingLabScreenState extends State<BreathingLabScreen> {
  static const Color background = Color(0xFF0B0C0F);
  static const Color card = Color(0xFF17181C);
  static const Color border = Color(0xFF262830);
  static const Color yellow = Color(0xFFFFD21F);
  static const Color lime = Color(0xFFD9E86C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);

  final BreathingSessionController _session = BreathingSessionController();
  final ExercisePlaybackController _referencePlayer =
      ExercisePlaybackController();
  bool _useLipTrill = true;
  bool _wasOnSingerExercise = false;
  int? _lastPlayedChromaticIndex;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleSessionChange);
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChange);
    _session.dispose();
    unawaited(_referencePlayer.dispose());
    super.dispose();
  }

  void _handleSessionChange() {
    final isOnSingerExercise =
        _session.exerciseId == BreathingExerciseId.singersBreath;
    if (!isOnSingerExercise) {
      if (_wasOnSingerExercise) unawaited(_referencePlayer.stop());
      _lastPlayedChromaticIndex = null;
    } else if (!_wasOnSingerExercise ||
        _lastPlayedChromaticIndex != _session.chromaticIndex) {
      _lastPlayedChromaticIndex = _session.chromaticIndex;
      unawaited(_playCurrentReferenceNote());
    }
    _wasOnSingerExercise = isOnSingerExercise;
  }

  Future<void> _playCurrentReferenceNote() => _referencePlayer.playReferenceNote(
        frequencyHz: _session.chromaticFrequencyHz,
      );

  void _replaySingerNote() {
    _session.replaySingerNote();
    unawaited(_playCurrentReferenceNote());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final exercise = _session.exercise;
        return Scaffold(
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
              'Breathing Lab',
              style: TextStyle(
                color: white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
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
                  const Text(
                    'MODULE 02  /  BREATH TRAINING',
                    style: TextStyle(
                      color: lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make room for\nyour sound.',
                    style: TextStyle(
                      color: white,
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Five focused ways to build a calm, steady breath.',
                    style: TextStyle(color: muted, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildExercisePicker(),
                  const SizedBox(height: 18),
                  if (_session.exerciseId == BreathingExerciseId.singersBreath)
                    _buildSingerSession(exercise)
                  else
                    _buildGuidedSession(exercise),
                  const SizedBox(height: 16),
                  _buildHowItWorksCard(exercise),
                  if (_session.isComplete) ...[
                    const SizedBox(height: 14),
                    _buildResultCard(exercise),
                  ],
                  const SizedBox(height: 18),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.spa_outlined, color: lime, size: 18),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Keep every breath comfortable. Pause or stop if you feel light-headed.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercisePicker() {
    const options = [
      (BreathingExerciseId.breathControl, 'Breath Control', Icons.air_rounded),
      (
        BreathingExerciseId.singersBreath,
        "Singer's Breath",
        Icons.graphic_eq_rounded
      ),
      (
        BreathingExerciseId.lipTongueTrill,
        'Lip Trill / Tongue Trill',
        Icons.waves_rounded
      ),
      (
        BreathingExerciseId.breathToPhrase,
        'Breath-to-Phrase',
        Icons.format_quote_rounded
      ),
      (
        BreathingExerciseId.randomChallenge,
        'Random Breath Challenge',
        Icons.shuffle_rounded
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHOOSE YOUR EXERCISE',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 9) / 2;
            return Wrap(
              spacing: 9,
              runSpacing: 9,
              children: options.map((option) {
                final selected = _session.exerciseId == option.$1;
                return SizedBox(
                  width: tileWidth,
                  height: 76,
                  child: Material(
                    color: selected ? const Color(0xFF25251B) : card,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _session.selectExercise(option.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected ? yellow.withAlpha(150) : border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22242B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? yellow : border,
                                ),
                              ),
                              child: Icon(
                                option.$3,
                                size: 17,
                                color: selected ? yellow : lime,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                option.$2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? yellow : white,
                                  fontSize: 11,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGuidedSession(BreathingExercise exercise) {
    final isTrill = _session.exerciseId == BreathingExerciseId.lipTongueTrill;
    final cue = switch (_session.phase) {
      BreathingPhase.inhale => 'Breathe in gently through your nose.',
      BreathingPhase.hold => 'Keep the breath easy. No need to strain.',
      BreathingPhase.exhale => isTrill
          ? _useLipTrill
              ? 'Let the lips flutter on a light, even stream of air.'
              : 'Let the tongue trill lightly as the air flows out.'
          : 'Let the breath flow out evenly.',
      BreathingPhase.recovery => 'Release your breath and relax.',
      BreathingPhase.phrase => 'Sing or speak one comfortable phrase.',
      BreathingPhase.sustain => 'Sustain this pitch with an easy breath.',
      BreathingPhase.ready => 'Press start when you are comfortable.',
      BreathingPhase.complete => 'You completed this practice.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 19),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExerciseHeading(exercise),
          if (isTrill) ...[
            const SizedBox(height: 13),
            _buildTrillSelector(),
          ],
          const SizedBox(height: 5),
          Center(
            child: BreathingPhaseVisual(
              phase: _session.phase,
              isRunning: _session.isRunning,
              secondsRemaining: _session.phaseSecondsRemaining,
              progress: _session.phaseProgress,
            ),
          ),
          Text(
            cue,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _session.isComplete
                    ? 'ROUNDS COMPLETE'
                    : 'ROUND ${_session.round} OF ${exercise.rounds}',
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${(_session.sessionProgress * 100).round()}%',
                style: const TextStyle(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _session.sessionProgress,
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2C36),
              valueColor: const AlwaysStoppedAnimation<Color>(yellow),
            ),
          ),
          const SizedBox(height: 17),
          _buildSessionControls(),
        ],
      ),
    );
  }

  Widget _buildSingerSession(BreathingExercise exercise) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 19),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _buildExerciseHeading(exercise),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              border: Border.all(color: const Color(0xFF30323A)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  _session.chromaticNote,
                  style: const TextStyle(
                    color: white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'NOTE ${_session.chromaticIndex + 1} OF ${BreathingSessionController.singerRangeLength}',
                  style: const TextStyle(
                    color: lime,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'C3  —  B5',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Center(
            child: BreathingPhaseVisual(
              phase: _session.phase,
              isRunning: _session.isRunning,
              secondsRemaining: _session.phaseSecondsRemaining,
              progress: _session.phaseProgress,
            ),
          ),
          Text(
            _session.isComplete
                ? 'Sustain complete. Move to the next note or replay.'
                : _session.isRunning
                    ? 'Sustain this pitch with a comfortable breath.'
                    : 'Choose a note, prepare your breath, then replay the sustain guide.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _circleControl(
                icon: Icons.arrow_back_rounded,
                label: 'Previous note',
                onPressed: _session.chromaticIndex > 0
                    ? _session.previousSingerNote
                    : null,
              ),
              const SizedBox(width: 5),
              _circleControl(
                icon: Icons.arrow_forward_rounded,
                label: 'Next note',
                onPressed: _session.chromaticIndex <
                        BreathingSessionController.singerRangeLength - 1
                    ? _session.nextSingerNote
                    : null,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _session.nextSingerNote,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: white,
                      side: const BorderSide(color: border),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('NEXT'),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _session.isRunning
                        ? _session.pause
                        : _session.isPaused
                            ? _session.resume
                            : _replaySingerNote,
                    style: FilledButton.styleFrom(
                      backgroundColor: yellow,
                      foregroundColor: buttonText,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      _session.isRunning
                          ? Icons.pause_rounded
                          : _session.isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.replay_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _session.isRunning
                          ? 'PAUSE'
                          : _session.isPaused
                              ? 'RESUME'
                              : 'REPLAY',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _session.reset,
              style: OutlinedButton.styleFrom(
                foregroundColor: muted,
                side: const BorderSide(color: border),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('RESET SUSTAIN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHeading(BreathingExercise exercise) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.title.toUpperCase(),
                style: const TextStyle(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                exercise.subtitle,
                style: const TextStyle(
                  color: white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (_session.exerciseId == BreathingExerciseId.breathControl)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF22242B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: const Text(
              'PROGRESSIVE',
              style: TextStyle(
                color: yellow,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrillSelector() {
    return Row(
      children: [
        Expanded(child: _trillOption('Lip Trill', true)),
        const SizedBox(width: 8),
        Expanded(child: _trillOption('Tongue Trill', false)),
      ],
    );
  }

  Widget _trillOption(String label, bool lip) {
    final selected = _useLipTrill == lip;
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () => setState(() => _useLipTrill = lip),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? buttonText : white,
          backgroundColor: selected ? lime : const Color(0xFF22242B),
          side: BorderSide(color: selected ? lime : border),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _circleControl({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 44,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: white,
          backgroundColor: const Color(0xFF22242B),
          disabledForegroundColor: muted.withAlpha(80),
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 19),
      ),
    );
  }

  Widget _buildSessionControls() {
    final label = _session.isRunning
        ? 'Pause'
        : _session.isPaused
            ? 'Resume'
            : _session.isComplete
                ? 'Start Again'
                : 'Start Exercise';
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _session.isRunning
                  ? _session.pause
                  : _session.isPaused
                      ? _session.resume
                      : _session.start,
              style: FilledButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor: buttonText,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: Icon(
                _session.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
              ),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          height: 52,
          width: 54,
          child: OutlinedButton(
            onPressed: _session.reset,
            style: OutlinedButton.styleFrom(
              foregroundColor: white,
              side: const BorderSide(color: border),
              shape: const StadiumBorder(),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.refresh_rounded, size: 21),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksCard(BreathingExercise exercise) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121317),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR ROUTINE',
            style: TextStyle(
              color: lime,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exercise.description,
            style: const TextStyle(color: white, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF202228),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, color: yellow, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exercise.pattern,
                    style: const TextStyle(
                      color: yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BreathingExercise exercise) {
    final message = _session.exerciseId == BreathingExerciseId.singersBreath
        ? 'Sustained ${_session.chromaticNote} · ${_session.elapsed.inSeconds}s'
        : '${exercise.rounds} rounds · ${_session.elapsed.inSeconds}s total';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF22221A),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: yellow.withAlpha(90)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: yellow, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: buttonText, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session.exerciseId == BreathingExerciseId.singersBreath
                      ? 'Sustain complete'
                      : 'Practice complete',
                  style: const TextStyle(
                    color: white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
