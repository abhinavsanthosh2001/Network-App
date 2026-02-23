import 'dart:math';
import 'package:flutter/material.dart';

class SpeedometerGauge extends StatelessWidget {
  final double? currentSpeed;
  final double maxSpeed;
  final String label;
  final String? unit;
  final double size;

  const SpeedometerGauge({
    super.key,
    this.currentSpeed,
    this.maxSpeed = 300.0,
    required this.label,
    this.unit = 'Mbps',
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = currentSpeed != null
        ? (currentSpeed! / maxSpeed).clamp(0.0, 1.0)
        : 0.0;

    final color = _colorForRatio(ratio);

    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size * 0.6,
            child: CustomPaint(
              painter: _GaugePainter(ratio: ratio, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentSpeed != null
                ? currentSpeed!.toStringAsFixed(1)
                : '—',
            style: TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit!,
            style: TextStyle(
              fontSize: size * 0.09,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: size * 0.1,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForRatio(double r) {
    if (r < 0.33) return Colors.redAccent;
    if (r < 0.66) return Colors.orange;
    return Colors.green.shade500;
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;

  _GaugePainter({required this.ratio, required this.color});

  static const double _startAngle = pi * 0.85;
  static const double _sweepAngle = pi * 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width / 2 - 12;

    // Track background
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Colored progress arc
    if (ratio > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle,
        _sweepAngle * ratio,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: _startAngle,
            endAngle: _startAngle + _sweepAngle * ratio,
            colors: [Colors.redAccent, Colors.orange, color],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
    }

    // Needle
    final needleAngle = _startAngle + _sweepAngle * ratio;
    final needleEnd = Offset(
      center.dx + (radius - 8) * cos(needleAngle),
      center.dy + (radius - 8) * sin(needleAngle),
    );
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = Colors.grey.shade800
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Center dot
    canvas.drawCircle(
      center,
      6,
      Paint()..color = Colors.grey.shade800,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.ratio != ratio || old.color != color;
}
