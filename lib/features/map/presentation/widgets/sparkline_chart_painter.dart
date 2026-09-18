import 'package:flutter/material.dart';

class SparklineChartPainter extends CustomPainter {
  final String indicator;
  SparklineChartPainter({required this.indicator});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    if (indicator == 'LST') {
      paint.color = const Color(0xFFD70015);
      fillPaint.color = const Color(0xFFD70015).withValues(alpha: 0.15);
    } else if (indicator == 'NDVI') {
      paint.color = const Color(0xFF248A3D);
      fillPaint.color = const Color(0xFF248A3D).withValues(alpha: 0.15);
    } else {
      paint.color = const Color(0xFFFF9500);
      fillPaint.color = const Color(0xFFFF9500).withValues(alpha: 0.15);
    }

    final path = Path();
    final fillPath = Path();
    final points = [0.2, 0.28, 0.35, 0.42, 0.5, 0.55, 0.62, 0.75, 0.82, 0.88];
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
