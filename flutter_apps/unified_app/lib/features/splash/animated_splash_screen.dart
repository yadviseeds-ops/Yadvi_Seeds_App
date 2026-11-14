import 'dart:async';
import 'package:flutter/material.dart';

/// Animated YADVI Seeds Logo Reveal Splash Screen.
///
/// Features:
/// - Clean white canvas (Scaffold background Colors.white).
/// - Direct rendering of authentic YHS logo asset without GPU ShaderMask clipping.
/// - Staggered "YADVI SEEDS" serif brand title reveal.
/// - Staggered "Sowing Seeds, Growing Futures." tagline reveal.
/// - Optional, subtle non-masking specular sheen sweep inside an IgnorePointer overlay.
/// - Robust auth-resolution synchronization with bounded safety timeout.
class AnimatedSplashScreen extends StatefulWidget {
  final bool isCheckingAuth;
  final VoidCallback onSplashComplete;

  const AnimatedSplashScreen({
    super.key,
    required this.isCheckingAuth,
    required this.onSplashComplete,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Staggered Animations
  late Animation<double> _emblemOpacity;
  late Animation<double> _emblemScale;

  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  late Animation<double> _sheenProgress;
  late Animation<double> _sheenOpacity;

  bool _hasTriggeredCompletion = false;
  Timer? _safetyTimeoutTimer;

  @override
  void initState() {
    super.initState();

    // Core reveal animation duration: 3.5 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // 1. Emblem Reveal (0.0s – 1.3s -> 0.0 – 0.37)
    _emblemOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
      ),
    );

    _emblemScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 80,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.38, curve: Curves.linear),
      ),
    );

    // 2. "YADVI SEEDS" Title Reveal (1.1s – 2.0s -> 0.32 – 0.58)
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.56, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.56, curve: Curves.easeOutCubic),
      ),
    );

    // 3. "Sowing Seeds, Growing Futures." Tagline Reveal (1.8s – 2.6s -> 0.52 – 0.74)
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.74, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.74, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Subtle, non-masking light sheen sweep (2.5s – 3.2s -> 0.72 – 0.92)
    _sheenProgress = Tween<double>(begin: -1.2, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 0.92, curve: Curves.easeInOut),
      ),
    );

    _sheenOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.40), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.40, end: 0.40), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.40, end: 0.0), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 0.92, curve: Curves.easeInOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationCompleted();
      }
    });

    // Hard fallback safety timer (5.0 seconds maximum)
    // Guarantees that even if auth check takes unexpectedly long, the splash screen will never freeze indefinitely
    _safetyTimeoutTimer = Timer(const Duration(milliseconds: 5000), () {
      if (!_hasTriggeredCompletion && mounted) {
        _triggerCompletion();
      }
    });

    _controller.forward();
  }

  void _onAnimationCompleted() {
    if (!widget.isCheckingAuth) {
      _triggerCompletion();
    }
    // If widget.isCheckingAuth is still true, we hold in completed resting state
    // and wait for didUpdateWidget to trigger completion once auth finishes
  }

  @override
  void didUpdateWidget(covariant AnimatedSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When auth check finishes and animation has completed, trigger transition
    if (!widget.isCheckingAuth && _controller.isCompleted) {
      _triggerCompletion();
    }
  }

  void _triggerCompletion() {
    if (_hasTriggeredCompletion) return;
    _hasTriggeredCompletion = true;
    _safetyTimeoutTimer?.cancel();
    widget.onSplashComplete();
  }

  @override
  void dispose() {
    _safetyTimeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Direct, unmasked branding column (Always 100% visible, GPU-safe)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Authentic YHS Emblem
                          Opacity(
                            opacity: _emblemOpacity.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: _emblemScale.value,
                              child: Image.asset(
                                'assets/images/yhs_logo.png',
                                width: 148,
                                height: 148,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Brand Title: "YADVI SEEDS"
                          Opacity(
                            opacity: _titleOpacity.value.clamp(0.0, 1.0),
                            child: SlideTransition(
                              position: _titleSlide,
                              child: const Text(
                                'YADVI SEEDS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2C4F7C), // Deep corporate navy
                                  fontFamily: 'serif',
                                  letterSpacing: 3.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Tagline: "Sowing Seeds, Growing Futures."
                          Opacity(
                            opacity: _taglineOpacity.value.clamp(0.0, 1.0),
                            child: SlideTransition(
                              position: _taglineSlide,
                              child: const Text(
                                'Sowing Seeds, Growing Futures.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF558B2F), // Botanical green
                                  fontFamily: 'serif',
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 2. Subtle specular sheen overlay (Inside IgnorePointer, cannot clip or hide content)
                      if (_sheenOpacity.value > 0.01)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: _sheenOpacity.value.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(_sheenProgress.value * 180, 0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(-0.6, -1.0),
                                      end: Alignment(0.6, 1.0),
                                      colors: [
                                        Colors.transparent,
                                        Color(0x33FFFFFF),
                                        Color(0x99FFFFFF),
                                        Color(0x33FFFFFF),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.40, 0.50, 0.60, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
