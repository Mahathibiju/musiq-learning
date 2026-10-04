import 'package:flutter/material.dart';
import 'package:musiq_learning/models/musical_note.dart';
import 'package:musiq_learning/services/exercise_generator.dart';
import 'package:musiq_learning/services/exercise_playback_controller.dart';

/// Simple data model for a vocal exercise category.
class VocalExerciseCategory {
  final String name;
  final String description;
  final IconData icon;
  final String tag;

  const VocalExerciseCategory({
    required this.name,
    required this.description,
    required this.icon,
    required this.tag,
  });
}

/// Interactive exercise generator and synchronized audio playback screen.
class ExerciseDetailScreen extends StatefulWidget {
  final VocalExerciseCategory exercise;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  // Design system constants
  static const Color appBackground = Color(0xFF0B0C0F);
  static const Color darkCardBg = Color(0xFF17181C);
  static const Color cardBorderColor = Color(0xFF262830);
  static const Color primaryYellow = Color(0xFFFFD21F);
  static const Color secondaryLime = Color(0xFFD9E86C);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);
  static const Color chipBackground = Color(0xFF202228);

  // Playback controller
  final ExercisePlaybackController _playbackController =
      ExercisePlaybackController();

  // User selection states
  ExerciseDifficulty _selectedDifficulty = ExerciseDifficulty.beginner;
  ExercisePatternDirection _selectedDirection =
      ExercisePatternDirection.ascendingDescending;
  SwaraExerciseType _selectedSwaraType = SwaraExerciseType.saraliVarisai;

  int _bpm = 75;
  int _variantIndex = 0;
  int? _activeNoteIndex;
  PlaybackStatus _playbackStatus = PlaybackStatus.idle;

  late GeneratedVocalExercise _currentExercise;

  bool get _isSwaras => widget.exercise.name.toLowerCase().contains('swara');
  bool get _isPlaying => _playbackStatus == PlaybackStatus.playing;
  bool get _isPaused => _playbackStatus == PlaybackStatus.paused;

  @override
  void initState() {
    super.initState();
    _regenerateExercise();
    _bpm = _currentExercise.recommendedBpm;

    _playbackController.onActiveIndexChanged = (index) {
      if (mounted) {
        setState(() => _activeNoteIndex = index);
      }
    };

    _playbackController.onStatusChanged = (status) {
      if (mounted) {
        setState(() => _playbackStatus = status);
      }
    };
  }

  @override
  void dispose() {
    _playbackController.dispose();
    super.dispose();
  }

  void _regenerateExercise() {
    _playbackController.stop();
    setState(() {
      _currentExercise = ExerciseGenerator.generate(
        categoryName: widget.exercise.name,
        difficulty: _selectedDifficulty,
        direction: _selectedDirection,
        swaraType: _selectedSwaraType,
        variationIndex: _variantIndex,
      );
    });
  }

  void _cycleNextVariation() {
    setState(() {
      _variantIndex++;
      _regenerateExercise();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'New exercise variation generated!',
          style: TextStyle(color: buttonText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: secondaryLime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _handlePlayPause() {
    if (_isPlaying) {
      _playbackController.pause();
    } else if (_isPaused) {
      _playbackController.resume();
    } else {
      _playbackController.start(
        notes: _currentExercise.notes,
        bpm: _bpm,
      );
    }
  }

  void _handleStop() {
    _playbackController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textWhite),
          onPressed: () {
            _playbackController.stop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.exercise.name,
          style: const TextStyle(
            color: textWhite,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Swaras Exercise Type Selector (Only visible for Swaras)
              if (_isSwaras) ...[
                const Text(
                  'EXERCISE TYPE',
                  style: TextStyle(
                    color: secondaryLime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                _buildSwaraTypeSelector(),
                const SizedBox(height: 20),
              ],

              // 2. Difficulty Selector
              const Text(
                'DIFFICULTY',
                style: TextStyle(
                  color: secondaryLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              _buildDifficultySelector(),
              const SizedBox(height: 20),

              // 3. Pattern Direction Selector
              const Text(
                'PATTERN DIRECTION',
                style: TextStyle(
                  color: secondaryLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              _buildDirectionSelector(),
              const SizedBox(height: 20),

              // 4. Tempo / BPM Selector
              _buildTempoSelector(),
              const SizedBox(height: 24),

              // 5. Synchronized Swaras Display Card
              _buildSynchronizedPatternCard(),
              const SizedBox(height: 20),

              // 6. Action Controls: Play / Pause / Stop
              Row(
                children: [
                  // Main Start / Pause / Resume Button
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _handlePlayPause,
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryYellow,
                          foregroundColor: buttonText,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 24,
                          color: buttonText,
                        ),
                        label: Text(
                          _isPlaying
                              ? 'Pause'
                              : (_isPaused ? 'Resume' : 'Start Exercise'),
                          style: const TextStyle(
                            color: buttonText,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stop Button (visible whenever playing or paused)
                  if (_isPlaying || _isPaused) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _handleStop,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFF383A44),
                              width: 1.2,
                            ),
                            shape: const StadiumBorder(),
                            backgroundColor: const Color(0xFF1B1C22),
                            foregroundColor: textWhite,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: textWhite,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Generate New Variation Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cycleNextVariation,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: secondaryLime, width: 1.2),
                    shape: const StadiumBorder(),
                    backgroundColor: Colors.transparent,
                    foregroundColor: secondaryLime,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Generate New Exercise',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Swara Exercise Type Chips (Sarali Varisai, Janta Varisai, Daatu Varisai, Gamaka Practice)
  Widget _buildSwaraTypeSelector() {
    final types = [
      {'type': SwaraExerciseType.saraliVarisai, 'label': 'Sarali Varisai'},
      {'type': SwaraExerciseType.jantaVarisai, 'label': 'Janta Varisai'},
      {'type': SwaraExerciseType.daatuVarisai, 'label': 'Daatu Varisai'},
      {'type': SwaraExerciseType.gamakaPractice, 'label': 'Gamaka Practice'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((item) {
        final isSelected = _selectedSwaraType == item['type'];
        return InkWell(
          onTap: () {
            setState(() {
              _selectedSwaraType = item['type'] as SwaraExerciseType;
              _variantIndex = 0;
              _regenerateExercise();
              _bpm = _currentExercise.recommendedBpm;
              _playbackController.setBpm(_bpm);
            });
          },
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryYellow : darkCardBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? primaryYellow : cardBorderColor,
                width: 1.0,
              ),
            ),
            child: Text(
              item['label'] as String,
              style: TextStyle(
                color: isSelected ? buttonText : textWhite,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Difficulty Selector (Beginner, Intermediate, Advanced)
  Widget _buildDifficultySelector() {
    final difficulties = [
      {'level': ExerciseDifficulty.beginner, 'label': 'Beginner'},
      {'level': ExerciseDifficulty.intermediate, 'label': 'Intermediate'},
      {'level': ExerciseDifficulty.advanced, 'label': 'Advanced'},
    ];

    return Row(
      children: difficulties.map((item) {
        final isSelected = _selectedDifficulty == item['level'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDifficulty = item['level'] as ExerciseDifficulty;
                  _variantIndex = 0;
                  _regenerateExercise();
                  _bpm = _currentExercise.recommendedBpm;
                  _playbackController.setBpm(_bpm);
                });
              },
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? primaryYellow : darkCardBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected ? primaryYellow : cardBorderColor,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: isSelected ? buttonText : textWhite,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Pattern Direction Selector (Ascending, Descending, Asc + Desc)
  Widget _buildDirectionSelector() {
    final directions = [
      {'dir': ExercisePatternDirection.ascending, 'label': 'Ascending'},
      {'dir': ExercisePatternDirection.descending, 'label': 'Descending'},
      {
        'dir': ExercisePatternDirection.ascendingDescending,
        'label': 'Asc + Desc'
      },
    ];

    return Row(
      children: directions.map((item) {
        final isSelected = _selectedDirection == item['dir'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDirection = item['dir'] as ExercisePatternDirection;
                  _variantIndex = 0;
                  _regenerateExercise();
                });
              },
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? secondaryLime : darkCardBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected ? secondaryLime : cardBorderColor,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: isSelected ? buttonText : textWhite,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Tempo Selector & Display
  Widget _buildTempoSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TEMPO',
                style: TextStyle(
                  color: secondaryLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_bpm',
                    style: const TextStyle(
                      color: textWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'BPM',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Increment / Decrement buttons
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_bpm > 40) {
                    setState(() {
                      _bpm -= 5;
                      _playbackController.setBpm(_bpm);
                    });
                  }
                },
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: textWhite,
                iconSize: 28,
              ),
              IconButton(
                onPressed: () {
                  if (_bpm < 180) {
                    setState(() {
                      _bpm += 5;
                      _playbackController.setBpm(_bpm);
                    });
                  }
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: primaryYellow,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Prominent Synchronized Pattern Card with Glowing Swaras
  Widget _buildSynchronizedPatternCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Mode Tag & Category Variation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22242B),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF2E313A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headphones_rounded, size: 12, color: secondaryLime),
                    SizedBox(width: 5),
                    Text(
                      'LISTEN MODE',
                      style: TextStyle(
                        color: secondaryLime,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF2E313A)),
                ),
                child: Text(
                  'Var ${_variantIndex + 1}',
                  style: const TextStyle(
                    color: primaryYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _currentExercise.title,
            style: const TextStyle(
              color: textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          // Synchronized Swara Notes Visual Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isPlaying
                    ? primaryYellow.withAlpha(90)
                    : primaryYellow.withAlpha(40),
                width: 1.2,
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: List.generate(_currentExercise.notes.length, (index) {
                final note = _currentExercise.notes[index];
                final isCurrent = _activeNoteIndex == index;
                return _buildSwaraChip(note, isCurrent);
              }),
            ),
          ),
          const SizedBox(height: 14),

          // Phonetic Syllables if available
          if (_currentExercise.phoneticSyllables != null) ...[
            Text(
              _currentExercise.phoneticSyllables!,
              style: const TextStyle(
                color: secondaryLime,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Technique Instruction Note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2.0, right: 8.0),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: textSecondary,
                  size: 16,
                ),
              ),
              Expanded(
                child: Text(
                  _currentExercise.techniqueNote,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Individual Swara Note Chip with glowing visual highlight and pulse
  Widget _buildSwaraChip(MusicalNote note, bool isCurrent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      transform: isCurrent ? Matrix4.diagonal3Values(1.08, 1.08, 1.0) : Matrix4.identity(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? primaryYellow : const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? primaryYellow : const Color(0xFF2A2C36),
          width: isCurrent ? 2.0 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: primaryYellow.withAlpha(160),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            note.displayLabel,
            style: TextStyle(
              color: isCurrent ? buttonText : textWhite,
              fontSize: 16,
              fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          // Subtle pulse dot indicator
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isCurrent ? buttonText : const Color(0xFF383A44),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
