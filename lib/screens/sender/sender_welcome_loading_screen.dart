import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';

class SenderWelcomeLoadingScreen extends StatefulWidget {
  const SenderWelcomeLoadingScreen({
    super.key,
    required this.fullName,
    required this.companyName,
  });

  final String fullName;
  final String companyName;

  @override
  State<SenderWelcomeLoadingScreen> createState() => _SenderWelcomeLoadingScreenState();
}

class _SenderWelcomeLoadingScreenState extends State<SenderWelcomeLoadingScreen>
    with TickerProviderStateMixin {
  static const String _logoAssetPath = 'assets/branding/app_logo.png';

  bool _showSkip = false;
  Timer? _skipTimer;
  Timer? _autoCloseTimer;
  bool _closed = false;
  bool _isClosing = false;

  late final AnimationController _introController;
  late final AnimationController _breathController;
  late final Animation<double> _introFade;
  late final Animation<double> _introScale;
  late final Animation<double> _breathScale;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _introFade = CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
    _introScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
    _breathScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _introController.forward();
    _breathController.repeat(reverse: true);

    _skipTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showSkip = true;
      });
    });

    _autoCloseTimer = Timer(const Duration(seconds: 3), () {
      _close();
    });
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _autoCloseTimer?.cancel();
    _introController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _skipTimer?.cancel();
    _autoCloseTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _isClosing = true;
    });

    // Let the overlay fade-out before popping.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
      opacity: _isClosing ? 0 : 1,
      child: Scaffold(
        backgroundColor: BiTasiColors.primaryRed,
        body: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _showSkip ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showSkip,
                      child: TextButton(
                        onPressed: _close,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          backgroundColor: Colors.white.withAlpha(40),
                          shape: StadiumBorder(
                            side: BorderSide(color: Colors.white.withAlpha(90), width: 1),
                          ),
                        ),
                        child: const Text(
                          'Geç',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 92,
                          width: 92,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: FadeTransition(
                            opacity: _introFade,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_introController, _breathController]),
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _introScale.value * _breathScale.value,
                                  child: child,
                                );
                              },
                              child: Image.asset(
                                _logoAssetPath,
                                fit: BoxFit.contain,
                                semanticLabel: 'Uygulama logosu',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Hoş geldin,',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withAlpha(220),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.fullName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.companyName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Hesabını hazırlıyoruz, birkaç saniye sürecek…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withAlpha(220),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(230)),
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
      ),
    );
  }
}
