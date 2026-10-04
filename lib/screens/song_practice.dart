import 'package:flutter/material.dart';
import 'package:musiq_learning/models/song_section.dart';
import 'package:musiq_learning/models/song_track.dart';
import 'package:musiq_learning/services/song_playback_service.dart';
import 'package:musiq_learning/services/song_progress_service.dart';
import 'package:musiq_learning/widgets/song_pitch_graph.dart';

class SongPracticeScreen extends StatefulWidget {
  final SongSection section;
  final InstrumentalTrack instrumental;
  final SongProgressService progress;

  const SongPracticeScreen({
    super.key,
    required this.section,
    required this.instrumental,
    required this.progress,
  });

  @override
  State<SongPracticeScreen> createState() => _SongPracticeScreenState();
}

class _SongPracticeScreenState extends State<SongPracticeScreen> {
  static const Color background = Color(0xFF0B0C0F);
  static const Color card = Color(0xFF17181C);
  static const Color border = Color(0xFF292B33);
  static const Color yellow = Color(0xFFFFD21F);
  static const Color lime = Color(0xFFD9E86C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);

  final SongPlaybackService _playback = SongPlaybackService();
  bool _loop = true;
  double _speed = 1.0;
  bool _awardedPractice = false;

  @override
  void dispose() {
    if (_playback.hasLooped) widget.progress.loopSessionCompleted();
    _playback.dispose();
    super.dispose();
  }

  Future<void> _replay() async {
    try {
      await _playback.playSection(
        track: widget.instrumental,
        start: widget.section.start,
        end: widget.section.end,
        loop: _loop,
        speed: _speed,
      );
      if (!_awardedPractice) {
        _awardedPractice = true;
        widget.progress.sectionPracticed();
      }
    } on UnsupportedError catch (error) {
      _showMessage(
        error.message ?? 'This playback speed is not available yet.',
      );
    } catch (error) {
      _showMessage('Could not play this section: $error');
    }
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
  Widget build(BuildContext context) {
    final section = widget.section;
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
          'Practice Section',
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title.toUpperCase(),
                style: const TextStyle(
                  color: lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SECTION LENGTH  ${_time(section.duration)}',
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _playback,
                builder: (context, _) => SongPitchGraph(
                  reference: section.referencePitch,
                  user: section.userPitch,
                  duration: section.duration,
                  position: (_playback.position - section.start).isNegative
                      ? Duration.zero
                      : _playback.position - section.start,
                  emptyMessage: 'This phrase is ready for its original-vocal pitch contour when pitch analysis is connected.',
                ),
              ),
              const SizedBox(height: 14),
              _buildSpeedCard(),
              const SizedBox(height: 12),
              _buildLoopCard(),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _replay,
                        style: FilledButton.styleFrom(
                          backgroundColor: yellow,
                          foregroundColor: buttonText,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text(
                          'REPLAY SECTION',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 54,
                    width: 58,
                    child: OutlinedButton(
                      onPressed: _playback.stop,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: white,
                        side: const BorderSide(color: border),
                        shape: const StadiumBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.stop_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (section.feedback != null) _buildFeedback(section.feedback!),
              if (section.userPitch.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Your previous pitch line will appear here after microphone pitch tracking is connected.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SPEED',
          style: TextStyle(
            color: lime,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [0.25, 0.5, 0.75, 1.0].map((speed) {
            final selected = _speed == speed;
            final supported = speed == 1.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  label: Text('${speed}x'),
                  labelStyle: TextStyle(
                    color: selected
                        ? buttonText
                        : supported
                        ? white
                        : muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  selectedColor: yellow,
                  backgroundColor: const Color(0xFF22242B),
                  side: BorderSide(color: selected ? yellow : border),
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.zero,
                  onSelected: supported
                      ? (_) => setState(() => _speed = speed)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Slow motion stays unavailable until pitch-preserving time stretch is connected.',
          style: TextStyle(color: muted, fontSize: 10, height: 1.4),
        ),
      ],
    ),
  );

  Widget _buildLoopCard() => Container(
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _loop ? yellow.withAlpha(90) : border),
    ),
    child: SwitchListTile.adaptive(
      value: _loop,
      onChanged: (value) {
        setState(() => _loop = value);
        _playback.setSectionLooping(value);
      },
      activeTrackColor: yellow,
      title: Text(
        _loop ? 'Looping this section' : 'Loop section',
        style: const TextStyle(
          color: white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: const Text(
        'Only the selected phrase repeats',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      secondary: Icon(Icons.repeat_rounded, color: _loop ? yellow : muted),
    ),
  );

  Widget _buildFeedback(SongFeedbackLevel feedback) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF22221A),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: yellow.withAlpha(70)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          feedbackTitle(feedback),
          style: const TextStyle(color: yellow, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          feedbackMessage(feedback),
          style: const TextStyle(color: white, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );

  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
