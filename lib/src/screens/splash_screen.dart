import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _progressController.forward();
    _pulseController.repeat(reverse: true);

    // Navigation logic with delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.user != null) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');// change to login
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff686c75), // Deep blue
              Color(0xFF0f172a), // Very dark blue/black
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main content area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo icon with pulse animation
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: const LogoIcon(),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // App name
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'EdgeFeeder',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Industrial Monitoring & Sales',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom section with loading
              // Padding(
              //   padding: const EdgeInsets.only(bottom: 60),
              //   child: Column(
              //     children: [
              //       // Loading text
              //       FadeTransition(
              //         opacity: _fadeAnimation,
              //         child: const Text(
              //           'Checking login state...',
              //           style: TextStyle(
              //             fontSize: 14,
              //             color: Colors.white60,
              //           ),
              //         ),
              //       ),
              //       const SizedBox(height: 20),
              //
              //       // Progress bar
              //       AnimatedBuilder(
              //         animation: _progressAnimation,
              //         builder: (context, child) {
              //           return Container(
              //             width: MediaQuery.of(context).size.width * 0.7,
              //             height: 3,
              //             decoration: BoxDecoration(
              //               color: Colors.white.withOpacity(0.2),
              //               borderRadius: BorderRadius.circular(1.5),
              //             ),
              //             child: FractionallySizedBox(
              //               alignment: Alignment.centerLeft,
              //               widthFactor: _progressAnimation.value,
              //               child: Container(
              //                 decoration: BoxDecoration(
              //                   color: const Color(0xff686c75),
              //                   borderRadius: BorderRadius.circular(1.5),
              //                   boxShadow: [
              //                     BoxShadow(
              //                       color: const Color(0xff686c75).withOpacity(0.5),
              //                       blurRadius: 4,
              //                       offset: const Offset(0, 0),
              //                     ),
              //                   ],
              //                 ),
              //               ),
              //             ),
              //           );
              //         },
              //       ),
              //       const SizedBox(height: 30),
              //
              //       // Version
              //       FadeTransition(
              //         opacity: _fadeAnimation,
              //         child: const Text(
              //           'Version 1.0.0',
              //           style: TextStyle(
              //             fontSize: 12,
              //             color: Colors.white,
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoIcon extends StatelessWidget {
  const LogoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: SliderIconPainter(),
      ),
    );
  }
}

class SliderIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff686c75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final sliderWidth = size.width * 0.6;
    final sliderSpacing = size.height * 0.15;

    // Draw three horizontal sliders
    for (int i = 0; i < 3; i++) {
      final y = center.dy + (i - 1) * sliderSpacing;

      // Draw slider track
      paint.color = Colors.white.withOpacity(0.3);
      canvas.drawLine(
        Offset(center.dx - sliderWidth / 2, y),
        Offset(center.dx + sliderWidth / 2, y),
        paint,
      );

      // Draw slider handle
      paint.color = const Color(0xff686c75);
      final handleX = center.dx + (i - 1) * sliderWidth * 0.2; // Vary handle positions
      canvas.drawCircle(Offset(handleX, y), 6, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}