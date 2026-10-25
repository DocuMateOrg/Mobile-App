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
  late Animation<double> _buttonSlideAnimation;

  // Flow stage: 0 = blue gradient, 1 = logo visible, 2 = line drawn, 3 = white welcome screen
  int _stage = 0;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // 1. Logo Animation (Frame 2) - Elastic bounce scale + smooth fade
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _logoScaleAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoFadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    // 2. Line Extension Animation (Frame 3) - Laser draw downwards
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _lineProgressAnimation = CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeInOutCubic,
    );

    // 3. Screen Transition to Frame 4 (Welcome screen + Documate brand + Login CTA)
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _transitionFadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    );
    _contentSlideAnimation = Tween<double>(begin: 36.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _buttonSlideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // Step 1: Brief ambient pause on royal gradient (Frame 1)
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _stage = 1);
    await _logoController.forward();

    // Step 2: Glowing line traces downwards from logo to bottom (Frame 3)
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _stage = 2);
    await _lineController.forward();

    // Step 3: Transition smoothly into Frame 4 (White Welcome Screen with Login button)
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
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: const Color(0xFF001126),
              systemNavigationBarIconBrightness: Brightness.light,
            ),
      child: Scaffold(
        backgroundColor: isWhiteStage ? Colors.white : const Color(0xFF001126),
        body: Stack(
          children: [
            // ==========================================
            // LAYER 1: Deep Blue Ambient Gradient (Frames 1, 2, 3)
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

            // Ambient Radial Soft Glow behind badge in Frames 1-3
            if (_stage < 3)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF0066D6).withValues(alpha: 0.35),
                          const Color(0xFF003E7E).withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            // ==========================================
            // LAYER 2: Frame 2 & 3 - Centered "D" Logo & Laser Beam
            // ==========================================
            if (_stage < 3)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centered White Circular "D" Badge with Multi-layered Depth
                      FadeTransition(
                        opacity: _logoFadeAnimation,
                        child: ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF0056D2).withValues(alpha: 0.45),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: DocumateDLogo(size: 48),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Frame 3: Laser Line Tracing Downwards from Logo to Bottom
            if (_stage >= 2 && _stage < 3)
              Positioned(
                top: (size.height / 2) + 43, // Bottom edge of circular badge
                left: (size.width / 2) - 1.5,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _lineProgressAnimation,
                  builder: (context, child) {
                    final targetHeight = size.height - ((size.height / 2) + 43);
                    final currentHeight = targetHeight * _lineProgressAnimation.value;
                    return SizedBox(
                      width: 3.0,
                      height: currentHeight,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          // Radiant glowing beam
                          Container(
                            width: 2.5,
                            height: currentHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.95),
                                  Colors.white.withValues(alpha: 0.65),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Subtle leading light particle at the tip
                          if (_lineProgressAnimation.value > 0.05 && _lineProgressAnimation.value < 0.98)
                            Positioned(
                              top: currentHeight - 4,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // ==========================================
            // LAYER 3: Frame 4 - Production-Grade White Welcome Screen
            // ==========================================
            if (_stage == 3)
              FadeTransition(
                opacity: _transitionFadeAnimation,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF8FAFC), // Ultra-subtle clean cool white tint
                        Colors.white,
                        Color(0xFFF1F5F9), // Soft contrast at bottom
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 4),

                          // Brand Block (Title + Emblem + Tagline)
                          AnimatedBuilder(
                            animation: _contentSlideAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _contentSlideAnimation.value),
                                child: child,
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Subtle Brand Emblem
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0056D2),
                                        Color(0xFF003E7E),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0056D2).withValues(alpha: 0.30),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: DocumateDLogo(
                                      size: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // Brand Name: "Documate"
                                Text(
                                  "Documate",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -1.0,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Production Tagline
                                Text(
                                  "Intelligent Document Digitization & AI Intelligence",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Capability Feature Pills
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildFeaturePill(Icons.auto_awesome, "Gemini AI"),
                                    const SizedBox(width: 8),
                                    _buildFeaturePill(Icons.document_scanner, "Smart OCR"),
                                    const SizedBox(width: 8),
                                    _buildFeaturePill(Icons.shield_outlined, "Secure"),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 4),

                          // Interactive CTA Button Group
                          AnimatedBuilder(
                            animation: _buttonSlideAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _buttonSlideAnimation.value),
                                child: child,
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Primary "Login" Button with Touch Micro-Animation
                                GestureDetector(
                                  onTapDown: (_) => setState(() => _isButtonPressed = true),
                                  onTapUp: (_) => setState(() => _isButtonPressed = false),
                                  onTapCancel: () => setState(() => _isButtonPressed = false),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.go('/login');
                                  },
                                  child: AnimatedScale(
                                    scale: _isButtonPressed ? 0.97 : 1.0,
                                    duration: const Duration(milliseconds: 120),
                                    curve: Curves.easeInOut,
                                    child: Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF0056D2), // High-clarity primary royal
                                            Color(0xFF0041A8), // Deep vivid cobalt
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0056D2).withValues(alpha: 0.35),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Login",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Secondary Quick Action: "Don't have an account? Register"
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.go('/signup');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: RichText(
                                      text: TextSpan(
                                        text: "Don't have an account? ",
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFF64748B),
                                        ),
                                        children: [
                                          TextSpan(
                                            text: "Register",
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0056D2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
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

  /// Capability Pill Badge Widget
  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: const Color(0xFF0056D2),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
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
