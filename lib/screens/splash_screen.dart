import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../widgets/app_brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isBrandingReady = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _loadBrandingAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandingAndNavigate() async {
    final settings = context.read<SettingsProvider>();
    await settings.appBrandingReady;
    if (!mounted) return;
    final logoUrl = settings.appLogoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      await precacheImage(
        NetworkImage(logoUrl),
        context,
        onError: (error, stackTrace) {
          debugPrint('Could not preload the app logo: $error');
          if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
        },
      );
    }
    if (!mounted) return;

    setState(() => _isBrandingReady = true);
    _animController.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Navy
      body: !_isBrandingReady
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFF1E293B), Color(0xFF060D1A)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 36,
                                  spreadRadius: 6,
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                                width: 2.2,
                              ),
                            ),
                            child: AppBrandLogo(
                              imageUrl: settings.appLogoUrl,
                              size: 84,
                              fallbackColor: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            settings.appNameAr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            settings.appNameEn,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 1.5,
                            width: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'المكتبة الإسلامية الرقمية والوسائط المعرفية',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 56),
                          const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
