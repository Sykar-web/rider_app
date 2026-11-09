import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A consistent branded launch across platforms, including Android 12.
class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _ready = false;
  late final AnimationController _animationController;
  late final Animation<double> _iconProgress;
  late final Animation<double> _textOpacity;
  late final Animation<double> _brandOpacity;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _iconProgress = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _textOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
    );
    _brandOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.60, 1, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animationController.forward();
    });
    _timer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _ready
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : Scaffold(
              key: const ValueKey('splash'),
              backgroundColor: AppColors.background,
              body: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  final progress = _iconProgress.value;
                  // Starts at the approximate size of a launcher icon, then
                  // expands into the branded opening screen.
                  final iconScale = 0.38 + (0.62 * progress);
                  final iconOffset = -42 * progress;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Transform.translate(
                          offset: Offset(0, iconOffset),
                          child: Transform.scale(
                            scale: iconScale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 184,
                                  height: 184,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.blueDeep.withValues(
                                      alpha: 0.08 * progress,
                                    ),
                                  ),
                                ),
                                Image.asset(
                                  // The transparent launcher mark keeps the
                                  // native and Flutter splash visually unified.
                                  'assets/icon/app_icon_foreground.png',
                                  color: AppColors.blueDeep,
                                  width: 214,
                                  height: 214,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.34),
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - progress)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FadeTransition(
                                    opacity: _brandOpacity,
                                    child: Text(
                                      'FastRide',
                                      style: const TextStyle(
                                        fontFamily: 'Asap',
                                        fontSize: 29,
                                        letterSpacing: -0.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Text(
                                    'Move Safe, Move Fast',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Asap',
                                      fontSize: 16,
                                      height: 1.45,
                                      letterSpacing: 0.15,
                                      color: AppColors.blueDeep,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
