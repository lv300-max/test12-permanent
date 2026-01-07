import 'package:flutter/material.dart';

import 'theme.dart';

class Try12Background extends StatelessWidget {
  const Try12Background({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: Try12Gradients.background)),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(
              color: Try12Colors.border.withValues(alpha: 0.18),
              majorColor: Try12Colors.border.withValues(alpha: 0.26),
            ),
          ),
        ),
        Positioned(
          left: -120,
          top: -140,
          child: _Glow(color: Try12Colors.accent.withValues(alpha: 0.20), size: 360),
        ),
        Positioned(
          right: -150,
          top: 120,
          child: _Glow(color: Try12Colors.highlight.withValues(alpha: 0.14), size: 420),
        ),
        Positioned(
          right: -160,
          bottom: -160,
          child: _Glow(color: const Color(0xFF7C9CFF).withValues(alpha: 0.14), size: 420),
        ),
        const Positioned.fill(child: _Vignette()),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.1),
            radius: 1.2,
            colors: [
              Colors.transparent,
              Try12Colors.bg.withValues(alpha: 0.45),
              Try12Colors.bg.withValues(alpha: 0.75),
            ],
            stops: const [0.0, 0.72, 1.0],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  final Color majorColor;

  const _GridPainter({required this.color, required this.majorColor});

  @override
  void paint(Canvas canvas, Size size) {
    const minorStep = 24.0;
    const majorEvery = 5;

    final minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    final majorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = majorColor;

    int v = 0;
    for (double x = 0; x <= size.width; x += minorStep, v++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (v % majorEvery == 0) ? majorPaint : minorPaint);
    }

    int h = 0;
    for (double y = 0; y <= size.height; y += minorStep, h++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (h % majorEvery == 0) ? majorPaint : minorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.majorColor != majorColor;
  }
}

