import 'dart:math';
import 'package:flutter/material.dart';

class SpeedometerGauge extends StatelessWidget {
  final double value; // 0.0 to 1.0 (for progress arc)
  final String label;
  final String? currentValue;
  final double size;
  final double? currentSpeed; // Current speed in Mbps for dynamic display
  final double maxSpeed; // Maximum speed for gauge scale

  const SpeedometerGauge({
    super.key,
    required this.value,
    required this.label,
    this.currentValue,
    this.size = 200,
    this.currentSpeed,
    this.maxSpeed = 300.0, // Default max speed 300 Mbps for speeds around 250
  });

  @override
  Widget build(BuildContext context) {
    // Always use currentSpeed for needle position when available, ignore progress value
    final double displayValue = currentSpeed != null 
        ? (currentSpeed! / maxSpeed).clamp(0.0, 1.0)
        : 0.0; // Show 0 when no speed data

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpeedometerPainter(
          value: displayValue,
          maxSpeed: maxSpeed,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (currentValue != null) ...[
                Text(
                  currentValue!,
                  style: TextStyle(
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.bold,
                    color: _getColorForValue(displayValue),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: size * 0.08,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForValue(double value) {
    if (value < 0.33) return Colors.red.shade600;
    if (value < 0.66) return Colors.orange.shade600;
    return Colors.green.shade600;
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double value;
  final double maxSpeed;

  _SpeedometerPainter({
    required this.value,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    
    // Draw background arc
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75, // Start angle (bottom left)
      pi * 1.5, // Sweep angle (270 degrees)
      false,
      backgroundPaint,
    );

    // Draw progress arc with gradient effect (only if value > 0)
    if (value > 0.001) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: pi * 0.75,
          endAngle: pi * 0.75 + pi * 1.5 * value,
          colors: [
            Colors.red.shade400,
            Colors.orange.shade400,
            Colors.green.shade400,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi * 0.75,
        pi * 1.5 * value,
        false,
        progressPaint,
      );
    }

    // Draw speed markers
    _drawSpeedMarkers(canvas, center, radius, size);

    // Draw needle
    final needleAngle = pi * 0.75 + (pi * 1.5 * value);
    final needleLength = radius - 10;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 8, centerPaint);
  }

  void _drawSpeedMarkers(Canvas canvas, Offset center, double radius, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw markers at 0%, 25%, 50%, 75%, 100% of max speed
    final markers = [0.0, 0.25, 0.5, 0.75, 1.0];
    
    for (final marker in markers) {
      final angle = pi * 0.75 + (pi * 1.5 * marker);
      final markerRadius = radius + 15;
      final markerPos = Offset(
        center.dx + markerRadius * cos(angle),
        center.dy + markerRadius * sin(angle),
      );

      // Draw speed value
      final speedValue = (maxSpeed * marker).toInt();
      textPainter.text = TextSpan(
        text: '$speedValue',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: size.width * 0.06,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          markerPos.dx - textPainter.width / 2,
          markerPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
