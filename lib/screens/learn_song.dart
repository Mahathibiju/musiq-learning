import 'package:flutter/material.dart';
import 'package:musiq_learning/models/song_track.dart';
import 'package:musiq_learning/screens/song_analysis.dart';
import 'package:musiq_learning/services/song_file_picker_service.dart';
import 'package:musiq_learning/services/song_playback_service.dart';
import 'package:musiq_learning/services/song_progress_service.dart';

class LearnSongScreen extends StatefulWidget {
  const LearnSongScreen({super.key});

  @override
  State<LearnSongScreen> createState() => _LearnSongScreenState();
}

class _LearnSongScreenState extends State<LearnSongScreen> {
  static const Color background = Color(0xFF0B0C0F);
  static const Color card = Color(0xFF17181C);
  static const Color border = Color(0xFF292B33);
  static const Color yellow = Color(0xFFFFD21F);
  static const Color lime = Color(0xFFD9E86C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA7A7A7);
  static const Color buttonText = Color(0xFF0B0C0F);

  final SongFilePickerService _filePicker = SongFilePickerService();
  final SongPlaybackService _previewPlayer = SongPlaybackService();
  final SongProgressService _progress = SongProgressService();
  SongFile? _song;
  bool _picking = false;
  String? _pickerError;

  @override
  void dispose() {
    _previewPlayer.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _chooseSong() async {
    setState(() {
      _picking = true;
      _pickerError = null;
    });
    try {
      final song = await _filePicker.pickAudioFile();
      if (!mounted) return;
      if (song != null) {
        await _previewPlayer.stop();
        setState(() => _song = song);
      }
    } catch (error) {
      if (mounted) setState(() => _pickerError = error.toString());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _openWorkspace() {
    final song = _song;
    if (song == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            SongAnalysisScreen(original: song, progress: _progress),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Learn a Song',
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
                'SONG STUDIO',
                style: TextStyle(
                  color: lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Learn the song.\nMake it yours.',
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
                'Turn any song into a personal vocal practice session.',
                style: TextStyle(color: muted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 23),
              _buildUploadCard(),
              if (_song != null) ...[
                const SizedBox(height: 16),
                _buildSongCard(_song!),
                const SizedBox(height: 16),
                _buildPipelineCard(),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _openWorkspace,
                    style: FilledButton.styleFrom(
                      backgroundColor: yellow,
                      foregroundColor: buttonText,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.graphic_eq_rounded),
                    label: const Text(
                      'OPEN SONG WORKSPACE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
              if (_pickerError != null) ...[
                const SizedBox(height: 12),
                _messageCard(_pickerError!, isError: true),
              ],
              const SizedBox(height: 20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, color: lime, size: 17),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Your song is copied to this device for the current app session. Stem separation and vocal analysis need a processing service.',
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
  }

  Widget _buildUploadCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 53,
          height: 53,
          decoration: const BoxDecoration(
            color: yellow,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: buttonText,
            size: 27,
          ),
        ),
        const SizedBox(height: 17),
        const Text(
          'Upload a Song',
          style: TextStyle(
            color: white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose an audio file stored on your phone. Common audio formats are available through Android’s file picker.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 17),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _picking ? null : _chooseSong,
            style: OutlinedButton.styleFrom(
              foregroundColor: yellow,
              side: const BorderSide(color: yellow, width: 1.2),
              shape: const StadiumBorder(),
            ),
            icon: _picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: Text(
              _picking ? 'Opening files…' : 'CHOOSE AUDIO FILE',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Center(
          child: Text(
            'Audio files  ·  Selected on device',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  Widget _buildSongCard(SongFile song) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFF17181C),
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: border),
    ),
    child: AnimatedBuilder(
      animation: _previewPlayer,
      builder: (context, _) => Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF25251B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.audio_file_rounded, color: yellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${song.mimeType}  ·  ${_formatDuration(song.duration)}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _previewPlayer.isPlaying
                    ? 'Pause preview'
                    : 'Preview song',
                onPressed: () => _previewPlayer.isPlaying
                    ? _previewPlayer.toggle()
                    : _previewPlayer.previewUpload(song),
                icon: Icon(
                  _previewPlayer.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: yellow,
                  size: 28,
                ),
              ),
            ],
          ),
          if (_previewPlayer.isPlaying) ...[
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _previewPlayer,
              builder: (context, _) => LinearProgressIndicator(
                value: song.duration > Duration.zero
                    ? (_previewPlayer.position.inMilliseconds /
                              song.duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                    : null,
                minHeight: 4,
                backgroundColor: border,
                valueColor: const AlwaysStoppedAnimation<Color>(yellow),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildPipelineCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFF111216),
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SONG PREPARATION',
          style: TextStyle(
            color: lime,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 13),
        const _PipelineStep(
          icon: Icons.check_circle_rounded,
          title: 'Song uploaded',
          detail: 'Ready on this device',
          color: lime,
        ),
        const _PipelineConnector(),
        const _PipelineStep(
          icon: Icons.hourglass_empty_rounded,
          title: 'Separate vocals and backing',
          detail: 'Waiting for a stem-separation service',
          color: Color(0xFFFFD21F),
        ),
        const _PipelineConnector(),
        const _PipelineStep(
          icon: Icons.multiline_chart_rounded,
          title: 'Analyze the vocal melody',
          detail: 'Uses the vocal stem only',
          color: Color(0xFF7B7E88),
        ),
      ],
    ),
  );

  Widget _messageCard(String message, {bool isError = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFF251B1B) : const Color(0xFF202228),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isError ? const Color(0xFF704242) : border),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? const Color(0xFFFFB6A8) : muted,
        fontSize: 12,
      ),
    ),
  );

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PipelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _PipelineStep({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 10),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PipelineConnector extends StatelessWidget {
  const _PipelineConnector();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 14,
    margin: const EdgeInsets.only(left: 9),
    color: const Color(0xFF363842),
  );
}
