import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A cute robot head character with highly expressive LED eyes, antenna, and mouth.
/// This becomes the Winatra AI mascot with expressive states.
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
  idle,        // Hijau - diam, siap sedia
  happy,       // Hijau terang - senang
  waiting,     // Kuning - mendengarkan wake word
  listening,   // Kuning terang - STT aktif, menangkap suara
  processing,  // Biru - memproses perintah
  thinking,    // Biru muda - berpikir (query AI)
  speaking,    // Oranye - TTS berbicara
  excited,     // Oranye terang - semangat
  sleepy,      // Abu-abu - ngantuk / idle lama
  error,       // Merah - ada masalah
}

class _RobotCharacterState extends State<RobotCharacter>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _bounceController;
  late AnimationController _antennaGlowController;
  late AnimationController _pupilMoveController;
  late AnimationController _mouthAnimController;
  late AnimationController _shakeController;
  late AnimationController _soundWaveController;
  late AnimationController _headTiltController;

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

    _pupilMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _mouthAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _soundWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _headTiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // Start blinking randomly
    _startBlinking();
  }

  void _startBlinking() {
    Future.delayed(Duration(milliseconds: 3000 + math.Random().nextInt(3000)), () {
      if (!mounted) return;
      // Skip blink if speaking (mouth anim active)
      if (widget.expression == RobotExpression.speaking) {
        _startBlinking();
        return;
      }
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
    _pupilMoveController.dispose();
    _mouthAnimController.dispose();
    _shakeController.dispose();
    _soundWaveController.dispose();
    _headTiltController.dispose();
    super.dispose();
  }

  /// Get the bounce frequency multiplier based on expression
  double get _bounceFrequency {
    switch (widget.expression) {
      case RobotExpression.excited:
        return 2.0;
      case RobotExpression.speaking:
        return 1.5;
      case RobotExpression.listening:
        return 1.2;
      case RobotExpression.sleepy:
        return 0.3;
      default:
        return 1.0;
    }
  }

  /// Get the bounce amplitude based on expression
  double get _bounceAmplitude {
    switch (widget.expression) {
      case RobotExpression.excited:
        return 6.0;
      case RobotExpression.speaking:
        return 4.0;
      case RobotExpression.listening:
        return 2.0;
      case RobotExpression.sleepy:
        return 1.0;
      default:
        return 3.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bounceController,
        _antennaGlowController,
        _pupilMoveController,
        _mouthAnimController,
        _shakeController,
        _soundWaveController,
        _headTiltController,
      ]),
      builder: (context, child) {
        final bounceY = widget.isIdle
            ? math.sin(_bounceController.value * 2 * math.pi * _bounceFrequency) *
                _bounceAmplitude
            : 0.0;
        final antennaGlow = _antennaGlowController.value;
        final pupilOffsetX = math.sin(_pupilMoveController.value * 2 * math.pi) * 3;
        final pupilOffsetY = math.cos(_pupilMoveController.value * 2 * math.pi * 0.7) * 2;
        final headTilt = widget.isIdle
            ? math.sin(_headTiltController.value * 2 * math.pi) * 0.04
            : 0.0;

        // Sound wave rings (visible during listening/speaking)
        final isSoundWaveVisible = widget.expression == RobotExpression.listening ||
            widget.expression == RobotExpression.speaking;

        // Shake for error expression
        final shakeX = widget.expression == RobotExpression.error
            ? math.sin(_shakeController.value * 2 * math.pi * 6) * 3
            : 0.0;

        return Transform.translate(
          offset: Offset(shakeX, bounceY),
          child: Transform.rotate(
            angle: headTilt,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sound wave rings
                  if (isSoundWaveVisible)
                    for (int i = 0; i < 3; i++)
                      Positioned(
                        child: _SoundWaveRing(
                          index: i,
                          progress: _soundWaveController.value,
                          isSpeaking: widget.expression == RobotExpression.speaking,
                          color: widget.accentColor,
                        ),
                      ),

                  // Main robot head
                  CustomPaint(
                    painter: _RobotHeadPainter(
                      blinkValue: _blinkController.value,
                      antennaGlow: antennaGlow,
                      primaryColor: widget.primaryColor,
                      accentColor: widget.accentColor,
                      expression: widget.expression,
                      pupilOffset: Offset(pupilOffsetX, pupilOffsetY),
                      mouthOpenValue: _mouthAnimController.value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Sound Wave Ring Widget ──

class _SoundWaveRing extends StatelessWidget {
  final int index;
  final double progress;
  final bool isSpeaking;
  final Color color;

  const _SoundWaveRing({
    required this.index,
    required this.progress,
    required this.isSpeaking,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Each ring has a different phase offset
    final phase = (progress + index * 0.33) % 1.0;
    final scale = 1.0 + phase * 0.5;
    final opacity = (1.0 - phase) * 0.4;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(opacity),
            width: 2.0,
          ),
        ),
      ),
    );
  }
}

// ── Robot Head Painter ──

class _RobotHeadPainter extends CustomPainter {
  final double blinkValue;
  final double antennaGlow;
  final Color primaryColor;
  final Color accentColor;
  final RobotExpression expression;
  final Offset pupilOffset;
  final double mouthOpenValue;

  _RobotHeadPainter({
    required this.blinkValue,
    required this.antennaGlow,
    required this.primaryColor,
    required this.accentColor,
    required this.expression,
    required this.pupilOffset,
    required this.mouthOpenValue,
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

    // Draw head with rounded rect
    final headRadius = radius * 0.85;
    final headCenter = Offset(center.dx, center.dy + 2);
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: headCenter,
        width: headRadius * 2,
        height: headRadius * 2,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(rr, headPaint);

    // Head border with glow on certain expressions
    final borderGlow = expression == RobotExpression.error ? 0.8 :
                        expression == RobotExpression.listening ? 0.5 :
                        expression == RobotExpression.speaking ? 0.4 : 0.6;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1.0 + (expression == RobotExpression.error ? antennaGlow * 0.5 : 0.0))
      ..color = primaryColor.withOpacity(borderGlow);
    canvas.drawRRect(rr, borderPaint);

    // ── Antenna ──
    _drawAntenna(canvas, headCenter, headRadius, paint);

    // ── Eyes ──
    _drawEyes(canvas, headCenter, headRadius, paint);

    // ── Mouth ──
    _drawMouth(canvas, headCenter, headRadius, paint);

    // ── Ear bolts ──
    _drawEarBolts(canvas, headCenter, headRadius, paint);

    // ── Error X marks over eyes (for error expression) ──
    if (expression == RobotExpression.error) {
      _drawErrorX(canvas, headCenter, headRadius, paint);
    }
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

    // Antenna glow effect (larger for excited/processing)
    final glowIntensity = expression == RobotExpression.excited ? 0.5 :
                          expression == RobotExpression.processing ? 0.4 :
                          expression == RobotExpression.error ? 0.5 :
                          0.3;
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withOpacity(glowIntensity * antennaGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(antennaTip, 8, glowPaint);

    // Antenna ball color changes based on expression
    Color ballColor;
    switch (expression) {
      case RobotExpression.listening:
        ballColor = const Color(0xFFFFCC00);
        break;
      case RobotExpression.processing:
      case RobotExpression.thinking:
        ballColor = const Color(0xFF66B2FF);
        break;
      case RobotExpression.speaking:
        ballColor = const Color(0xFFFF6600);
        break;
      case RobotExpression.error:
        ballColor = const Color(0xFFFF3333);
        break;
      case RobotExpression.excited:
        ballColor = const Color(0xFFFF8800);
        break;
      case RobotExpression.sleepy:
        ballColor = const Color(0xFF8888AA);
        break;
      default:
        ballColor = accentColor;
    }
    final ballPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = ballColor.withOpacity(0.6 + 0.4 * antennaGlow);
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
    final glowAccent = expression == RobotExpression.listening ? 0.4 :
                       expression == RobotExpression.speaking ? 0.3 :
                       expression == RobotExpression.error ? 0.4 : 0.2;
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withOpacity(glowAccent)
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
        case RobotExpression.idle:
        case RobotExpression.happy:
          eyeColor = const Color(0xFF00FF88);
          break;
        case RobotExpression.waiting:
        case RobotExpression.listening:
          eyeColor = const Color(0xFFFFCC00);
          break;
        case RobotExpression.excited:
          eyeColor = const Color(0xFFFF6600);
          break;
        case RobotExpression.processing:
        case RobotExpression.thinking:
          eyeColor = const Color(0xFF66B2FF);
          break;
        case RobotExpression.speaking:
          eyeColor = const Color(0xFFFF8800);
          break;
        case RobotExpression.sleepy:
          eyeColor = const Color(0xFF8888AA);
          break;
        case RobotExpression.error:
          eyeColor = const Color(0xFFFF3333);
          break;
      }

      // Main eye
      final eyePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = eyeColor;

      // For sleepy: draw half-closed eyes
      if (expression == RobotExpression.sleepy) {
        final sleepyPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = eyeColor.withOpacity(0.5);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(center.dx - eyeSpacing, eyeY + eyeSize * 0.3),
            width: eyeSize * 1.8,
            height: eyeSize * 0.5,
          ),
          sleepyPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(center.dx + eyeSpacing, eyeY + eyeSize * 0.3),
            width: eyeSize * 1.8,
            height: eyeSize * 0.5,
          ),
          sleepyPaint,
        );
      } else {
        canvas.drawCircle(Offset(center.dx - eyeSpacing, eyeY), eyeSize, eyePaint);
        canvas.drawCircle(Offset(center.dx + eyeSpacing, eyeY), eyeSize, eyePaint);
      }

      // Eye highlight
      if (expression != RobotExpression.sleepy) {
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
      }

      // Pupil movement (for idle look-around)
      if (expression == RobotExpression.idle ||
          expression == RobotExpression.happy ||
          expression == RobotExpression.listening) {
        final pupilPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF1A1A2E).withOpacity(0.6);
        canvas.drawCircle(
          Offset(
            center.dx - eyeSpacing + pupilOffset.dx,
            eyeY + pupilOffset.dy,
          ),
          eyeSize * 0.3,
          pupilPaint,
        );
        canvas.drawCircle(
          Offset(
            center.dx + eyeSpacing + pupilOffset.dx,
            eyeY + pupilOffset.dy,
          ),
          eyeSize * 0.3,
          pupilPaint,
        );
      }

      // Sparkle eyes for excited
      if (expression == RobotExpression.excited) {
        final sparklePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(0.9);
        canvas.drawCircle(
          Offset(center.dx - eyeSpacing + eyeSize * 0.5, eyeY - eyeSize * 0.6),
          eyeSize * 0.2,
          sparklePaint,
        );
        canvas.drawCircle(
          Offset(center.dx + eyeSpacing + eyeSize * 0.5, eyeY - eyeSize * 0.6),
          eyeSize * 0.2,
          sparklePaint,
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
      case RobotExpression.idle:
        // Small gentle smile
        final path = Path();
        path.moveTo(center.dx - mouthWidth * 0.6, mouthY);
        path.quadraticBezierTo(
          center.dx,
          mouthY + mouthWidth * 0.3,
          center.dx + mouthWidth * 0.6,
          mouthY,
        );
        canvas.drawPath(path, mouthPaint);
        break;

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
        // Small 'o' shape (surprised/waiting)
        mouthPaint.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(center.dx, mouthY), 4, mouthPaint);
        break;

      case RobotExpression.listening:
        // Slightly open mouth
        final open = mouthPaint..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, mouthY),
            width: 8,
            height: 6,
          ),
          mouthPaint..style = PaintingStyle.fill,
        );
        break;

      case RobotExpression.processing:
        // Wavy/zigzag line (processing)
        final path2 = Path();
        path2.moveTo(center.dx - mouthWidth, mouthY);
        path2.quadraticBezierTo(
          center.dx - mouthWidth * 0.4, mouthY - 5,
          center.dx, mouthY,
        );
        path2.quadraticBezierTo(
          center.dx + mouthWidth * 0.4, mouthY + 5,
          center.dx + mouthWidth, mouthY,
        );
        canvas.drawPath(path2, mouthPaint);
        break;

      case RobotExpression.thinking:
        // Wavy line (thinking)
        final path3 = Path();
        path3.moveTo(center.dx - mouthWidth, mouthY);
        path3.quadraticBezierTo(
          center.dx - mouthWidth * 0.3, mouthY - 6,
          center.dx, mouthY,
        );
        path3.quadraticBezierTo(
          center.dx + mouthWidth * 0.3, mouthY + 6,
          center.dx + mouthWidth, mouthY,
        );
        canvas.drawPath(path3, mouthPaint);
        break;

      case RobotExpression.speaking:
        // Animated mouth (opens and closes)
        final mouthOpen = mouthOpenValue;
        final mouthHeight = 3 + mouthOpen * 8;
        mouthPaint.style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(center.dx, mouthY + mouthHeight / 2),
              width: mouthWidth * 0.8,
              height: mouthHeight,
            ),
            const Radius.circular(4),
          ),
          mouthPaint,
        );
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

      case RobotExpression.sleepy:
        // Small line / flat mouth
        canvas.drawLine(
          Offset(center.dx - mouthWidth * 0.5, mouthY),
          Offset(center.dx + mouthWidth * 0.5, mouthY),
          mouthPaint..strokeWidth = 2,
        );
        break;

      case RobotExpression.error:
        // Zigzag angry mouth
        final zigzag = Path();
        zigzag.moveTo(center.dx - mouthWidth, mouthY);
        zigzag.lineTo(center.dx - mouthWidth * 0.5, mouthY - 5);
        zigzag.lineTo(center.dx, mouthY + 2);
        zigzag.lineTo(center.dx + mouthWidth * 0.5, mouthY - 3);
        zigzag.lineTo(center.dx + mouthWidth, mouthY + 1);
        canvas.drawPath(zigzag, mouthPaint..color = const Color(0xFFFF3333));
        break;
    }
  }

  void _drawEarBolts(Canvas canvas, Offset center, double radius, Paint paint) {
    final earY = center.dy;
    final earSize = radius * 0.12;

    for (final side in [-1, 1]) {
      final earX = center.dx + side * (radius + 2);

      // Ear bolt glow
      if (expression == RobotExpression.listening ||
          expression == RobotExpression.speaking ||
          expression == RobotExpression.processing) {
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = accentColor.withOpacity(0.2 * antennaGlow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(earX, earY), earSize * 2, glowPaint);
      }

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

  void _drawErrorX(Canvas canvas, Offset center, double radius, Paint paint) {
    final eyeY = center.dy - radius * 0.15;
    final eyeSpacing = radius * 0.3;
    final eyeSize = radius * 0.18;

    final xPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = const Color(0xFFFF3333)
      ..strokeCap = StrokeCap.round;

    // Left eye X
    canvas.drawLine(
      Offset(center.dx - eyeSpacing - eyeSize * 0.5, eyeY - eyeSize * 0.5),
      Offset(center.dx - eyeSpacing + eyeSize * 0.5, eyeY + eyeSize * 0.5),
      xPaint,
    );
    canvas.drawLine(
      Offset(center.dx - eyeSpacing + eyeSize * 0.5, eyeY - eyeSize * 0.5),
      Offset(center.dx - eyeSpacing - eyeSize * 0.5, eyeY + eyeSize * 0.5),
      xPaint,
    );

    // Right eye X
    canvas.drawLine(
      Offset(center.dx + eyeSpacing - eyeSize * 0.5, eyeY - eyeSize * 0.5),
      Offset(center.dx + eyeSpacing + eyeSize * 0.5, eyeY + eyeSize * 0.5),
      xPaint,
    );
    canvas.drawLine(
      Offset(center.dx + eyeSpacing + eyeSize * 0.5, eyeY - eyeSize * 0.5),
      Offset(center.dx + eyeSpacing - eyeSize * 0.5, eyeY + eyeSize * 0.5),
      xPaint,
    );
  }

  @override
  bool shouldRepaint(_RobotHeadPainter old) =>
      old.blinkValue != blinkValue ||
      old.antennaGlow != antennaGlow ||
      old.expression != expression ||
      old.pupilOffset != pupilOffset ||
      old.mouthOpenValue != mouthOpenValue;
}