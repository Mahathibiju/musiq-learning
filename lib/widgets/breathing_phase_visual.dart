import 'package:flutter/material.dart';
import 'package:musiq_learning/models/breathing_exercise.dart';

class BreathingPhaseVisual extends StatelessWidget {
  final BreathingPhase phase;
  final bool isRunning;
  final int secondsRemaining;
  final double progress;

  const BreathingPhaseVisual({
    super.key,
    required this.phase,
    required this.isRunning,
    required this.secondsRemaining,
    required this.progress,
  });

  static const Color yellow = Color(0xFFFFD21F);
  static const Color lime = Color(0xFFD9E86C);

  double get _scale => switch (phase) {
        BreathingPhase.inhale => 1.0,
        BreathingPhase.hold => 1.0,
        BreathingPhase.exhale => 0.76,
        BreathingPhase.phrase => 0.76,
        BreathingPhase.sustain => 1.0,
        BreathingPhase.recovery => 0.82,
        BreathingPhase.ready => 0.76,
        BreathingPhase.complete => 0.9,
      };

  Color get _phaseColor => switch (phase) {
        BreathingPhase.inhale => lime,
        BreathingPhase.hold => yellow,
        BreathingPhase.exhale => yellow,
        BreathingPhase.phrase => yellow,
        BreathingPhase.sustain => lime,
        BreathingPhase.recovery => const Color(0xFF82D4C5),
        BreathingPhase.ready => const Color(0xFF82D4C5),
        BreathingPhase.complete => lime,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      height: 252,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 238,
            height: 238,
            child: CircularProgressIndicator(
              value: isRunning ? progress : 0,
              strokeWidth: 2.5,
              backgroundColor: const Color(0xFF2A2C36),
              valueColor: AlwaysStoppedAnimation<Color>(_phaseColor),
            ),
          ),
          AnimatedScale(
            scale: isRunning ? _scale : 0.82,
            duration: Duration(
              milliseconds: phase == BreathingPhase.inhale
                  ? 700
                  : phase == BreathingPhase.exhale
                      ? 900
                      : 450,
            ),
            curve: Curves.easeInOutCubic,
            child: Container(
              width: 198,
              height: 198,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _phaseColor.withAlpha(65),
                    _phaseColor.withAlpha(24),
                    const Color(0xFF17181C),
                  ],
                  stops: const [0, 0.66, 1],
                ),
                border: Border.all(color: _phaseColor.withAlpha(130), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _phaseColor.withAlpha(isRunning ? 48 : 16),
                    blurRadius: isRunning ? 34 : 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    breathingPhaseLabel(phase),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _phaseColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isRunning || phase == BreathingPhase.complete ? secondsRemaining : 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    phase == BreathingPhase.sustain ? 'SECONDS LEFT' : 'SECONDS',
                    style: const TextStyle(
                      color: Color(0xFFA7A7A7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
