import 'package:flutter/material.dart';
import 'package:musiq_learning/models/pitch_point.dart';

class SongPitchGraph extends StatelessWidget {
  final List<PitchPoint> reference;
  final List<PitchPoint> user;
  final Duration duration;
  final Duration position;
  final String emptyMessage;

  const SongPitchGraph({
    super.key,
    required this.reference,
    this.user = const [],
    required this.duration,
    this.position = Duration.zero,
    this.emptyMessage =
        'The vocal pitch graph will appear after melody analysis.',
  });

  static const Color yellow = Color(0xFFFFD21F);
  static const Color teal = Color(0xFF79D8C5);

  @override
  Widget build(BuildContext context) {
    final hasReference = reference.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111216),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF292B33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'VOCAL MELODY',
                  style: TextStyle(
                    color: Color(0xFFD9E86C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              _Legend(color: yellow, label: 'Original Vocal'),
              if (user.isNotEmpty) ...[
                const SizedBox(width: 12),
                const _Legend(color: teal, label: 'Your Voice'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 186,
            width: double.infinity,
            child: hasReference || user.isNotEmpty
                ? CustomPaint(
                    painter: _PitchGraphPainter(
                      reference: reference,
                      user: user,
                      duration: duration,
                      position: position,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0E12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8C8F99),
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(
                  position - const Duration(seconds: 6) < Duration.zero
                      ? Duration.zero
                      : position - const Duration(seconds: 6),
                ),
                style: _timeStyle,
              ),
              Text(_format(position), style: _currentTimeStyle),
              Text(
                _format(
                  position + const Duration(seconds: 6) > duration
                      ? duration
                      : position + const Duration(seconds: 6),
                ),
                style: _timeStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _timeStyle = TextStyle(
    color: Color(0xFF8C8F99),
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle _currentTimeStyle = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w900,
  );

  String _format(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD5D6DA),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _PitchGraphPainter extends CustomPainter {
  final List<PitchPoint> reference;
  final List<PitchPoint> user;
  final Duration duration;
  final Duration position;

  const _PitchGraphPainter({
    required this.reference,
    required this.user,
    required this.duration,
    required this.position,
  });

  static const Color _gridColor = Color(0xFF292B33);
  static const Color _referenceColor = Color(0xFFFFD21F);
  static const Color _userColor = Color(0xFF79D8C5);
  static const double _viewportSeconds = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(28, 8, size.width - 34, size.height - 22);
    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    for (var i = 0; i <= 4; i++) {
      final x = chart.left + chart.width * i / 4;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
    }

    final all = [
      ...reference,
      ...user,
    ].where((point) => point.confidence >= 0.55).toList();
    if (all.isEmpty) return;
    var minPitch = all
        .map((point) => point.midiNote)
        .reduce((a, b) => a < b ? a : b);
    var maxPitch = all
        .map((point) => point.midiNote)
        .reduce((a, b) => a > b ? a : b);
    if (maxPitch - minPitch < 5) {
      final center = (maxPitch + minPitch) / 2;
      minPitch = center - 3;
      maxPitch = center + 3;
    }

    Offset mapPoint(PitchPoint point) {
      final windowMs = _viewportSeconds * 1000;
      final deltaMs = point.time.inMilliseconds - position.inMilliseconds;
      final timeFraction = 0.5 + deltaMs / windowMs;
      final pitchFraction =
          ((point.midiNote - minPitch) / (maxPitch - minPitch)).clamp(0.0, 1.0);
      return Offset(
        chart.left + chart.width * timeFraction,
        chart.bottom - chart.height * pitchFraction,
      );
    }

    canvas.save();
    canvas.clipRect(chart);
    _drawPitchPath(canvas, reference, mapPoint, _referenceColor);
    _drawPitchPath(canvas, user, mapPoint, _userColor);
    canvas.restore();

    final x = chart.center.dx;
    canvas.drawLine(
      Offset(x, chart.top),
      Offset(x, chart.bottom),
      Paint()
        ..color = Colors.white.withAlpha(220)
        ..strokeWidth = 1.5,
    );
  }

  void _drawPitchPath(
    Canvas canvas,
    List<PitchPoint> points,
    Offset Function(PitchPoint) mapPoint,
    Color color,
  ) {
    final centerMs = position.inMilliseconds;
    final halfWindowMs = (_viewportSeconds * 500).round();
    final ordered = points.where((point) {
      final delta = point.time.inMilliseconds - centerMs;
      return delta >= -halfWindowMs - 500 && delta <= halfWindowMs + 500;
    }).toList()..sort((a, b) => a.time.compareTo(b.time));
    final path = Path();
    PitchPoint? previous;
    Offset? previousOffset;
    var segmentOpen = false;
    for (final point in ordered) {
      if (point.confidence < 0.55) {
        previous = null;
        previousOffset = null;
        segmentOpen = false;
        continue;
      }
      final currentOffset = mapPoint(point);
      final gapMs = previous == null
          ? 0
          : point.time.inMilliseconds - previous.time.inMilliseconds;
      final octaveJump =
          previous != null && (point.midiNote - previous.midiNote).abs() > 12;
      if (!segmentOpen || gapMs > 500 || octaveJump) {
        path.moveTo(currentOffset.dx, currentOffset.dy);
        segmentOpen = true;
      } else {
        final previousPoint = previousOffset!;
        final middle = Offset(
          (previousPoint.dx + currentOffset.dx) / 2,
          (previousPoint.dy + currentOffset.dy) / 2,
        );
        path.quadraticBezierTo(
          previousPoint.dx,
          previousPoint.dy,
          middle.dx,
          middle.dy,
        );
        path.lineTo(currentOffset.dx, currentOffset.dy);
      }
      previous = point;
      previousOffset = currentOffset;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchGraphPainter oldDelegate) =>
      oldDelegate.reference != reference ||
      oldDelegate.user != user ||
      oldDelegate.duration != duration ||
      oldDelegate.position != position;
}
