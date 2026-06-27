import 'dart:math';

import 'package:flutter/material.dart';

class OrdifyLogoMark extends StatelessWidget {
  final double size;

  const OrdifyLogoMark({
    super.key,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF35E58F),
            Color(0xFF0FA765),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF35E58F).withValues(alpha: 0.28),
            blurRadius: size * 0.55,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: _OrdifyLogoPainter(),
        ),
      ),
    );
  }
}

class _OrdifyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()
      ..color = const Color(0xFF06100B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF06100B)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    final hexPath = Path();

    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * pi / 180;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      if (i == 0) {
        hexPath.moveTo(point.dx, point.dy);
      } else {
        hexPath.lineTo(point.dx, point.dy);
      }
    }

    hexPath.close();
    canvas.drawPath(hexPath, darkPaint);

    final innerRadius = size.width * 0.14;

    final innerCirclePaint = Paint()
      ..color = const Color(0xFF06100B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, innerRadius, innerCirclePaint);

    final flowPaint = Paint()
      ..color = const Color(0xFF06100B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - radius * 0.70, center.dy),
      Offset(center.dx - innerRadius * 1.15, center.dy),
      flowPaint,
    );

    canvas.drawLine(
      Offset(center.dx + innerRadius * 1.15, center.dy),
      Offset(center.dx + radius * 0.70, center.dy),
      flowPaint,
    );

    canvas.drawCircle(
      Offset(center.dx - radius * 0.82, center.dy),
      size.width * 0.035,
      fillPaint,
    );

    canvas.drawCircle(
      Offset(center.dx + radius * 0.82, center.dy),
      size.width * 0.035,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}