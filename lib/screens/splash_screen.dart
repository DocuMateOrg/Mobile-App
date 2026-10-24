import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;

  late AnimationController _lineController;
  late Animation<double> _lineProgressAnimation;

  late AnimationController _transitionController;
  late Animation<double> _transitionFadeAnimation;
  late Animation<double> _contentSlideAnimation;

  // Flow stage: 0 = blue gradient, 1 = logo visible, 2 = line drawn, 3 = white welcome screen
  int _stage = 0;

  @override
  void initState() {
    super.initState();

    // 1. Logo Animation (Frame 2)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScaleAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoFadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    // 2. Line Extension Animation (Frame 3)
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _lineProgressAnimation = CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeInOut,
    );

    // 3. Screen Transition to Frame 4 (White screen + Documate + Login button)
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _transitionFadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );
    _contentSlideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeOutCubic),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // Step 1: Brief pause on gradient (Frame 1)
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _stage = 1);
    await _logoController.forward();

    // Step 2: Line draws downwards from logo (Frame 3)
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _stage = 2);
    await _lineController.forward();

    // Step 3: Transition to Frame 4 (White Welcome Screen with Login button)
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _stage = 3);
    await _transitionController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _lineController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWhiteStage = _stage == 3;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isWhiteStage
          ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
      child: Scaffold(
        body: Stack(
          children: [
            // ==========================================
            // LAYER 1: Deep Blue Gradient (Frames 1, 2, 3)
            // ==========================================
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF003E7E), // Rich vibrant royal blue at top
                      Color(0xFF002248), // Deep navy
                      Color(0xFF001126), // Midnight navy / near-black at bottom
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ==========================================
            // LAYER 2: Frame 2 & 3 - Centered "D" Logo & Vertical Line
            // ==========================================
            if (_stage < 3)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centered White Circular "D" Badge
                      FadeTransition(
                        opacity: _logoFadeAnimation,
                        child: ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: DocumateDLogo(size: 46),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Frame 3: Vertical Line Tracing Downwards from Logo to Bottom
            if (_stage >= 2 && _stage < 3)
              Positioned(
                top: (size.height / 2) + 41, // Bottom edge of circular badge
                left: (size.width / 2) - 1,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _lineProgressAnimation,
                  builder: (context, child) {
                    final targetHeight = size.height - ((size.height / 2) + 41);
                    return Container(
                      width: 2.0,
                      height: targetHeight * _lineProgressAnimation.value,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // ==========================================
            // LAYER 3: Frame 4 - White Welcome Screen with "Documate" & "Login" Button
            // ==========================================
            if (_stage == 3)
              FadeTransition(
                opacity: _transitionFadeAnimation,
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                  child: SafeArea(
                    child: AnimatedBuilder(
                      animation: _contentSlideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _contentSlideAnimation.value),
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 3),

                          // Brand Title: "Documate"
                          Text(
                            "Documate",
                            style: GoogleFonts.poppins(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF002244),
                              letterSpacing: -0.5,
                            ),
                          ),

                          const Spacer(flex: 3),

                          // Login Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: SizedBox(
                              width: 170,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Directs user to the Sign In / Login page
                                  context.go('/login');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0056D2),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: const Color(0xFF0056D2).withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Stylized Documate 'D' Monogram matching the circular badge icon in the design
class DocumateDLogo extends StatelessWidget {
  final double size;
  final Color color;

  const DocumateDLogo({
    super.key,
    required this.size,
    this.color = const Color(0xFF002952),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DocumateDPainter(color: color),
    );
  }
}

class _DocumateDPainter extends CustomPainter {
  final Color color;

  _DocumateDPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Stylized 'D' path with classic top-left serif bracket and curved right bowl
    final outerPath = Path();
    outerPath.moveTo(w * 0.18, h * 0.15); // Top-left serif tip
    outerPath.lineTo(w * 0.44, h * 0.15); // Top stem connection
    // Smooth outer bowl curve
    outerPath.cubicTo(
      w * 0.76, h * 0.15,
      w * 0.88, h * 0.32,
      w * 0.88, h * 0.50,
    );
    outerPath.cubicTo(
      w * 0.88, h * 0.68,
      w * 0.76, h * 0.85,
      w * 0.44, h * 0.85,
    );
    outerPath.lineTo(w * 0.18, h * 0.85); // Bottom-left serif
    outerPath.lineTo(w * 0.18, h * 0.76);
    outerPath.lineTo(w * 0.30, h * 0.76); // Inner stem edge
    outerPath.lineTo(w * 0.30, h * 0.24);
    outerPath.lineTo(w * 0.18, h * 0.24);
    outerPath.close();

    // Inner cutout (counter of the D)
    final innerPath = Path();
    innerPath.moveTo(w * 0.45, h * 0.30);
    innerPath.cubicTo(
      w * 0.68, h * 0.30,
      w * 0.73, h * 0.38,
      w * 0.73, h * 0.50,
    );
    innerPath.cubicTo(
      w * 0.73, h * 0.62,
      w * 0.68, h * 0.70,
      w * 0.45, h * 0.70,
    );
    innerPath.close();

    final combined = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
