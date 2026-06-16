import 'dart:math' as math;
import 'dart:ui' as ui; 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _hexagonDraw;
  late Animation<double> _innerNodesDraw;
  late Animation<double> _centerPulse;
  late Animation<double> _textFadeSlide;
  late Animation<double> _taglineFade;

  final List<Offset> _particles = const [
    Offset(-120, -140), Offset(140, -110), Offset(-150, 40),
    Offset(130, 150),   Offset(-60, -180), Offset(80, -160),
    Offset(-160, -60),  Offset(160, 60),   Offset(-90, 160),
    Offset(70, 180),    Offset(110, -30),  Offset(-40, 130),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), 
    );

    _hexagonDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    _innerNodesDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic), 
      ),
    );

    _centerPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 2.3), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 2.3, end: 1.0), weight: 60),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.65, curve: Curves.easeInOutCubic), 
      ),
    );

    _textFadeSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 0.95, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Secure timing guard callback ensures layout tree assembly is absolute before navigation triggers
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/login');
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00FFCC);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withOpacity(
                              (0.06 * _hexagonDraw.value).clamp(0.0, 1.0)),
                          accentColor.withOpacity(
                              (0.01 * _hexagonDraw.value).clamp(0.0, 1.0)),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              ...List.generate(_particles.length, (index) {
                final double activationPoint = 0.2 + ((index % 4) * 0.15);
                final double particleOpacity = CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    activationPoint,
                    math.min(activationPoint + 0.25, 1.0),
                    curve: Curves.easeIn,
                  ),
                ).value;

                return Center(
                  child: Transform.translate(
                    offset: _particles[index],
                    child: Container(
                      width: 2.0,
                      height: 2.0,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(
                            (particleOpacity * 0.4).clamp(0.0, 1.0)),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(
                                (particleOpacity * 0.2).clamp(0.0, 1.0)),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CustomPaint(
                        painter: _OrdiFyEnginePainter(
                          chassisProgress: _hexagonDraw.value,
                          networkProgress: _innerNodesDraw.value,
                          corePulse: _centerPulse.value,
                          accentColor: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Opacity(
                      opacity: _textFadeSlide.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset:
                            Offset(0.0, 16.0 * (1.0 - _textFadeSlide.value)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Ordi',
                                  style: GoogleFonts.lexend(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'FY',
                                  style: GoogleFonts.lexend(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: _taglineFade.value.clamp(0.0, 1.0),
                              child: Text(
                                'BUSINESS ENGINE',
                                style: GoogleFonts.lexend(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor.withOpacity(0.85),
                                  letterSpacing:
                                      3.0 + (1.5 * _taglineFade.value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrdiFyEnginePainter extends CustomPainter {
  final double chassisProgress;
  final double networkProgress;
  final double corePulse;
  final Color accentColor;

  _OrdiFyEnginePainter({
    required this.chassisProgress,
    required this.networkProgress,
    required this.corePulse,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.45;

    final Paint chassisPaint = Paint()
      ..color = accentColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final Paint networkPaint = Paint()
      ..color = accentColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final Paint nodePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final List<Offset> hexPoints = [];
    for (int i = 0; i < 6; i++) {
      double angle = (i * math.pi / 3) - (math.pi / 6);
      hexPoints.add(Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ));
    }

    if (chassisProgress > 0) {
      final Path outerPath = Path()
        ..moveTo(hexPoints[0].dx, hexPoints[0].dy);
      for (int i = 1; i <= 5; i++) {
        outerPath.lineTo(hexPoints[i].dx, hexPoints[i].dy);
      }
      outerPath.close();

      final ui.PathMetrics metrics = outerPath.computeMetrics();
      for (final ui.PathMetric metric in metrics) {
        final Path extract =
            metric.extractPath(0.0, metric.length * chassisProgress);
        canvas.drawPath(extract, chassisPaint);
      }
    }

    if (networkProgress > 0) {
      final List<Offset> networkTargets = [
        hexPoints[0],
        hexPoints[2],
        hexPoints[4],
      ];
      for (int i = 0; i < networkTargets.length; i++) {
        Offset target = networkTargets[i];
        Offset currentLineEnd = Offset.lerp(target, center, networkProgress)!;
        canvas.drawLine(target, currentLineEnd, networkPaint);

        if (networkProgress > 0.7) {
          double nodeAlpha = ((networkProgress - 0.7) / 0.3).clamp(0.0, 1.0);
          canvas.drawCircle(
            target,
            3.5,
            nodePaint..color = accentColor.withOpacity(nodeAlpha),
          );
          canvas.drawCircle(
            target,
            6.0,
            chassisPaint
              ..color =
                  accentColor.withOpacity((nodeAlpha * 0.3).clamp(0.0, 1.0)),
          );
        }
      }
    }

    if (networkProgress >= 0.95) {
      double coreAlpha = networkProgress.clamp(0.0, 1.0);
      double pulseOpacity = (0.4 - (corePulse * 0.15)).clamp(0.0, 1.0);

      final Paint pulsePaint = Paint()
        ..color = accentColor.withOpacity(pulseOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, 5.0 * corePulse, pulsePaint);
      canvas.drawCircle(
        center,
        4.5,
        nodePaint..color = Colors.white.withOpacity(coreAlpha),
      );
      canvas.drawCircle(
        center,
        5.5,
        chassisPaint..color = accentColor.withOpacity(coreAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrdiFyEnginePainter oldDelegate) {
    return oldDelegate.chassisProgress != chassisProgress ||
        oldDelegate.networkProgress != networkProgress ||
        oldDelegate.corePulse != corePulse;
  }
}