import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A cute robot head character with expressive LED eyes and antenna.
/// This becomes the Winatra AI mascot.
class RobotCharacter extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color accentColor;
  final RobotExpression expression;
  final bool isIdle;

  const RobotCharacter({
    super.key,
    this.size = 120,
    this.primaryColor = const Color(0xFF6B4EFF),
    this.accentColor = const Color(0xFF00CC88),
    this.expression = RobotExpression.happy,
    this.isIdle = false,
  });

  @override
  State<RobotCharacter> createState() => _RobotCharacterState();
}

enum RobotExpression {
  happy,
  waiting,
  excited,
  thinking,
  sleepy,
}

class _RobotCharacterState extends State<RobotCharacter>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _bounceController;
  late AnimationController _antennaGlowController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _antennaGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Blink every 3-5 seconds
    _startBlinking();
  }

  void _startBlinking() {
    Future.delayed(const Duration(milliseconds: 3000 + math.Random().nextInt(2000)), () {
      if (!mounted) return;
      _blinkController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _blinkController.reverse();
        });
      });
      _startBlinking();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _bounceController.dispose();
    _antennaGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bounceController, _antennaGlowController]),
      builder: (context, child) {
        final bounceY = widget.isIdle ? math.sin(_bounceController.value * 2 * math.pi) * 3 : 0.0;
        final antennaGlow = _antennaGlowController.value;

        return Transform.translate(
          offset: Offset(0, bounceY),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _RobotHeadPainter(
                blinkValue: _blinkController.value,
                antennaGlow: antennaGlow,
                primaryColor: widget.primaryColor,
                accentColor: widget.accentColor,
                expression: widget.expression,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RobotHeadPainter extends CustomPainter {
  final double blinkValue;
  final double antennaGlow;
  final Color primaryColor;
  final Color accentColor;
  final RobotExpression expression;

  _RobotHeadPainter({
    required this.blinkValue,
    required this.antennaGlow,
    required this.primaryColor,
    required this.accentColor,
    required this.expression,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()..style = PaintingStyle.fill;

    // ── Shadow ──
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(2, 3), radius - 2, shadowPaint);

    // ── Main head (rounded square with slight robot shape) ──
    final headRect = Rect.fromCircle(center: center, radius: radius);
    final headPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withOpacity(0.9),
          primaryColor.withOpacity(0.6),
          primaryColor.withOpacity(0.8),
        ],
      ).createShader(headRect.inflate(10));

    // Draw head with rounded rect (more robot-like than circle)
    final headRadius = radius * 0.85;
    final headCenter = Offset(center.dx, center.dy + 2);
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: headCenter, width: headRadius * 2, height: headRadius * 2),
      const Radius.circular(24),
    );
    canvas.drawRRect(rr, headPaint);

    // Head border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = primaryColor.withOpacity(0.6);
    canvas.drawRRect(rr, borderPaint);

    // ── Antenna ──
    _drawAntenna(canvas, headCenter, headRadius, paint);

    // ── Eyes ──
    _drawEyes(canvas, headCenter, headRadius, paint);

    // ── Mouth ──
    _drawMouth(canvas, headCenter, headRadius, paint);

    // ── Ear bolts ──
    _drawEarBolts(canvas, headCenter, headRadius, paint);
  }

  void _drawAntenna(Canvas canvas, Offset center, double radius, Paint paint) {
    final antennaBase = Offset(center.dx, center.dy - radius - 4);
    final antennaTip = Offset(center.dx, center.dy - radius - 18);

    // Antenna line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = primaryColor.withOpacity(0.7)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(antennaBase, antennaTip, linePaint);

    // Antenna ball with glow
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withOpacity(0.3 * antennaGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(antennaTip, 6, glowPaint);

    final ballPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withOpacity(0.6 + 0.4 * antennaGlow);
    canvas.drawCircle(antennaTip, 4, ballPaint);

    // Small highlight on ball
    final highlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.6);
    canvas.drawCircle(antennaTip + const Offset(-1.5, -1.5), 1.5, highlightPaint);
  }

  void _drawEyes(Canvas canvas, Offset center, double radius, Paint paint) {
    final eyeY = center.dy - radius * 0.15;
    final eyeSpacing = radius * 0.3;
    final eyeSize = radius * 0.18;

    // Eye background (dark sockets)
    final socketPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1A1A2E).withOpacity(0.8);
    canvas.drawCircle(Offset(center.dx - eyeSpacing, eyeY), eyeSize + 3, socketPaint);
    canvas.drawCircle(Offset(center.dx + eyeSpacing, eyeY), eyeSize + 3, socketPaint);

    // Eye glow
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx - eyeSpacing, eyeY), eyeSize + 2, glowPaint);
    canvas.drawCircle(Offset(center.dx + eyeSpacing, eyeY), eyeSize + 2, glowPaint);

    // Eye whites (only visible when blinking)
    if (blinkValue > 0) {
      // Closed eyes (line)
      final closedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accentColor
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - eyeSpacing - eyeSize * 0.6, eyeY),
        Offset(center.dx - eyeSpacing + eyeSize * 0.6, eyeY),
        closedPaint,
      );
      canvas.drawLine(
        Offset(center.dx + eyeSpacing - eyeSize * 0.6, eyeY),
        Offset(center.dx + eyeSpacing + eyeSize * 0.6, eyeY),
        closedPaint,
      );
    } else {
      // Open eyes - LED style
      Color eyeColor;
      switch (expression) {
        case RobotExpression.happy:
          eyeColor = const Color(0xFF00FF88);
          break;
        case RobotExpression.waiting:
          eyeColor = const Color(0xFFFFCC00);
          break;
        case RobotExpression.excited:
          eyeColor = const Color(0xFFFF6600);
          break;
        case RobotExpression.thinking:
          eyeColor = const Color(0xFF66B2FF);
          break;
        case RobotExpression.sleepy:
          eyeColor = const Color(0xFF8888AA);
          break;
      }

      // Main eye
      final eyePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = eyeColor;
      canvas.drawCircle(Offset(center.dx - eyeSpacing, eyeY), eyeSize, eyePaint);
      canvas.drawCircle(Offset(center.dx + eyeSpacing, eyeY), eyeSize, eyePaint);

      // Eye highlight
      final hlPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(0.7);
      canvas.drawCircle(
        Offset(center.dx - eyeSpacing - eyeSize * 0.25, eyeY - eyeSize * 0.25),
        eyeSize * 0.35,
        hlPaint,
      );
      canvas.drawCircle(
        Offset(center.dx + eyeSpacing - eyeSize * 0.25, eyeY - eyeSize * 0.25),
        eyeSize * 0.35,
        hlPaint,
      );

      // Pupil direction based on expression
      if (expression == RobotExpression.thinking) {
        final pupilPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF1A1A2E).withOpacity(0.6);
        canvas.drawCircle(
          Offset(center.dx - eyeSpacing + eyeSize * 0.2, eyeY - eyeSize * 0.1),
          eyeSize * 0.3,
          pupilPaint,
        );
        canvas.drawCircle(
          Offset(center.dx + eyeSpacing + eyeSize * 0.2, eyeY - eyeSize * 0.1),
          eyeSize * 0.3,
          pupilPaint,
        );
      }
    }
  }

  void _drawMouth(Canvas canvas, Offset center, double radius, Paint paint) {
    final mouthY = center.dy + radius * 0.35;
    final mouthWidth = radius * 0.35;

    final mouthPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withOpacity(0.8)
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case RobotExpression.happy:
        // Smile arc
        final path = Path();
        path.moveTo(center.dx - mouthWidth, mouthY);
        path.quadraticBezierTo(
          center.dx,
          mouthY + mouthWidth * 0.6,
          center.dx + mouthWidth,
          mouthY,
        );
        canvas.drawPath(path, mouthPaint);
        break;

      case RobotExpression.waiting:
        // Small 'o' shape
        mouthPaint.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(center.dx, mouthY), 4, mouthPaint);
        break;

      case RobotExpression.excited:
        // Wide open mouth
        final openPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF1A1A2E).withOpacity(0.8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(center.dx, mouthY + 2),
              width: mouthWidth * 1.2,
              height: mouthWidth * 0.7,
            ),
            const Radius.circular(6),
          ),
          openPaint,
        );
        // Outline
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(center.dx, mouthY + 2),
              width: mouthWidth * 1.2,
              height: mouthWidth * 0.7,
            ),
            const Radius.circular(6),
          ),
          mouthPaint..style = PaintingStyle.stroke,
        );
        break;

      case RobotExpression.thinking:
        // Wavy line
        final path2 = Path();
        path2.moveTo(center.dx - mouthWidth, mouthY);
        path2.quadraticBezierTo(
          center.dx - mouthWidth * 0.4,
          mouthY - 5,
          center.dx,
          mouthY,
        );
        path2.quadraticBezierTo(
          center.dx + mouthWidth * 0.4,
          mouthY + 5,
          center.dx + mouthWidth,
          mouthY,
        );
        canvas.drawPath(path2, mouthPaint);
        break;

      case RobotExpression.sleepy:
        // Small line
        canvas.drawLine(
          Offset(center.dx - mouthWidth * 0.5, mouthY),
          Offset(center.dx + mouthWidth * 0.5, mouthY),
          mouthPaint..strokeWidth = 2,
        );
        break;
    }
  }

  void _drawEarBolts(Canvas canvas, Offset center, double radius, Paint paint) {
    final earY = center.dy;
    final earSize = radius * 0.12;

    for (final side in [-1, 1]) {
      final earX = center.dx + side * (radius + 2);

      // Ear bolt
      final boltPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = primaryColor.withOpacity(0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(earX, earY),
            width: earSize * 1.5,
            height: earSize * 2,
          ),
          const Radius.circular(3),
        ),
        boltPaint,
      );

      // Ear highlight
      final hlPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(earX - 1, earY - 1),
            width: earSize * 0.5,
            height: earSize * 0.8,
          ),
          const Radius.circular(1),
        ),
        hlPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RobotHeadPainter old) =>
      old.blinkValue != blinkValue ||
      old.antennaGlow != antennaGlow ||
      old.expression != expression;
}