import 'package:flutter/material.dart';
import 'login_screen.dart';

class TraceColors {
  static const Color background = Color(0xFF0C1B45);
  static const Color gold = Color(0xFFF6B93B);
  static const Color white = Colors.white;
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;

    // ============================================================
    // EASY ADJUSTMENTS
    // ============================================================

    // Bigger number = logo moves DOWN
    // Smaller number = logo moves UP
    const double logoTopOffset = 55;

    return Scaffold(
      backgroundColor: TraceColors.background,

      body: Stack(
        fit: StackFit.expand,
        children: [

          // ========================================================
          // 1. DARK BLUE BACKGROUND
          // ========================================================
          Container(
            color: TraceColors.background,
          ),

          // ========================================================
          // 2. BACKGROUND IMAGE
          // ========================================================
          Positioned.fill(
            child: Image.asset(
              'assets/back1.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: TraceColors.background,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: Colors.white54,
                    size: 60,
                  ),
                );
              },
            ),
          ),

          // ========================================================
          // 3. TOP FADE
          // ========================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.40,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0C1B45),
                      Color(0xF70C1B45),
                      Color(0xC80C1B45),
                      Color(0x850C1B45),
                      Color(0x300C1B45),
                      Color(0x000C1B45),
                    ],
                    stops: [
                      0.00,
                      0.25,
                      0.45,
                      0.65,
                      0.83,
                      1.00,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ========================================================
          // 4. BOTTOM FADE
          // ========================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.40,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x000C1B45),
                      Color(0x200C1B45),
                      Color(0x650C1B45),
                      Color(0xB50C1B45),
                      Color(0xEA0C1B45),
                      Color(0xFF0C1B45),
                    ],
                    stops: [
                      0.00,
                      0.18,
                      0.38,
                      0.60,
                      0.82,
                      1.00,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ========================================================
          // 5. LOGO
          // ========================================================
          Positioned(
            top: topInset + logoTopOffset,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                width: size.width * 0.60,
                height: size.height * 0.18,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const _FallbackLogo();
                },
              ),
            ),
          ),

          // ========================================================
          // 6. BOTTOM ICONS + BUTTON
          // ========================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ------------------------------------------------
                    // ICONS
                    // ------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'SCAN',
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.calendar_month_rounded,
                              label: 'EVENTS',
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.people_alt_rounded,
                              label: 'ATTENDANCE',
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.bar_chart_rounded,
                              label: 'REPORTS',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ------------------------------------------------
                    // GET STARTED BUTTON
                    // ------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 51,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TraceColors.gold,
                            foregroundColor: TraceColors.background,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FEATURE ITEM
// ================================================================

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ========================================================
        // ICON
        // White main icon + subtle gold accent
        // ========================================================
        Stack(
          alignment: Alignment.center,
          children: [
            // Gold accent / glow


            // White main icon
            const Icon(
              Icons.circle,
              color: Colors.transparent,
              size: 0,
            ),

            Icon(
              icon,
              color: TraceColors.white,
              size: 30,
            ),
          ],
        ),

        const SizedBox(height: 5),

        // ========================================================
        // LABEL
        // White main text + subtle gold accent
        // ========================================================
        Stack(
          alignment: Alignment.center,
          children: [
            // Gold accent
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: TraceColors.gold.withOpacity(0.75),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.25,
              ),
            ),

            // White main text
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TraceColors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.25,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ================================================================
// FALLBACK LOGO
// ================================================================

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 4,
                top: 10,
                child: _speedLine(34),
              ),
              Positioned(
                left: 0,
                top: 21,
                child: _speedLine(27),
              ),
              Positioned(
                left: 8,
                top: 32,
                child: _speedLine(20),
              ),
              Positioned(
                left: 16,
                top: 41,
                child: _speedLine(12),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'T',
                    style: TextStyle(
                      color: TraceColors.white,
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      height: 1,
                    ),
                  ),

                  const SizedBox(width: 2),

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Text(
                          'R',
                          style: TextStyle(
                            color: TraceColors.gold,
                            fontSize: 50,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),

                      Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: TraceColors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: TraceColors.background,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        Text.rich(
          const TextSpan(
            children: [
              TextSpan(
                text: 'TR',
                style: TextStyle(
                  color: TraceColors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              TextSpan(
                text: 'A',
                style: TextStyle(
                  color: TraceColors.gold,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              TextSpan(
                text: 'CE',
                style: TextStyle(
                  color: TraceColors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 1),

        const Text(
          'TRACKING & RECORDING ATTENDANCE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TraceColors.white,
            fontSize: 5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.45,
          ),
        ),

        const Text(
          'FOR CAMPUS EVENTS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TraceColors.gold,
            fontSize: 5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _speedLine(double width) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: TraceColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}