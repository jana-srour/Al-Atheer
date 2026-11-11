import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_provider.dart';
import 'providers/resource_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_access_guard.dart';
import 'screens/password_recovery_screen.dart';
import 'localization/app_strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _isInitializing = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await Supabase.initialize(
        url: 'https://wwznycaoofxytdnyckhq.supabase.co',
        publishableKey: 'sb_publishable_tSTYgRL8qa_vbQfdN13ZEw_aUaoDhIB',
      );
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isInitializing = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Supabase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupLoadingScreen(),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupErrorScreen(onRetry: _initializeSupabase),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ResourceProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const AlAtheerApp(),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _StartupErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFF59E0B),
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Could not connect to the app service',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your internet connection and Supabase project settings, then try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlAtheerApp extends StatefulWidget {
  const AlAtheerApp({super.key});

  @override
  State<AlAtheerApp> createState() => _AlAtheerAppState();
}

class _AlAtheerAppState extends State<AlAtheerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Modern Navy + Amber Gold Color Palette
    const deepNavy = Color(0xFF0F172A);
    const darkNavy = Color(0xFF060D1A);
    const radiantGold = Color(0xFFF59E0B);
    const amberLight = Color(0xFFFBBF24);

    return MaterialApp(
      title: 'Al-Atheer | الأثير',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppStrings.supportedLanguages.keys
          .map((code) => Locale(code))
          .toList(growable: false),
      // The user's in-app selection must win over the device locale. If the
      // callback picks the device language here, Directionality follows the
      // selected setting while Localizations.localeOf(context) stays Arabic.
      localeResolutionCallback: (_, __) => settings.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: _navigatorKey,
      builder: (context, child) => _PasswordRecoveryRouteListener(
        isRecoveringPassword: auth.isPasswordRecovery,
        navigatorKey: _navigatorKey,
        child: Builder(
          builder: (context) => Directionality(
            textDirection: settings.isRtl
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.textScale),
                disableAnimations: settings.reduceMotion,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),

      // Modern Light Theme (Slate + Amber Gold + Clean White)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: deepNavy,
          primary: deepNavy,
          secondary: radiantGold,
          surface: const Color(0xFFF8FAFC),
          surfaceContainerHighest: const Color(0xFFEEF2FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: deepNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2.5,
          shadowColor: deepNavy.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: radiantGold.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: radiantGold.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: radiantGold.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: radiantGold, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: radiantGold.withValues(alpha: 0.3)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: deepNavy,
          foregroundColor: radiantGold,
          elevation: 4,
        ),
      ),

      // Modern Dark Theme (Deep Navy + Amber Gold)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkNavy,
          brightness: Brightness.dark,
          primary: const Color(0xFF1E293B),
          secondary: radiantGold,
          surface: const Color(0xFF0F172A),
          surfaceContainerHighest: const Color(0xFF1E293B),
        ),
        scaffoldBackgroundColor: const Color(0xFF060D1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1628),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: radiantGold.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          color: const Color(0xFF1E293B),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: radiantGold.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: radiantGold.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: radiantGold, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: radiantGold.withValues(alpha: 0.3)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: amberLight,
          elevation: 4,
        ),
      ),

      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/admin': (context) =>
            AdminAccessGuard(child: const AdminDashboardScreen()),
        '/password-recovery': (context) => const PasswordRecoveryScreen(),
      },
    );
  }
}

class _PasswordRecoveryRouteListener extends StatefulWidget {
  final bool isRecoveringPassword;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const _PasswordRecoveryRouteListener({
    required this.isRecoveringPassword,
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<_PasswordRecoveryRouteListener> createState() =>
      _PasswordRecoveryRouteListenerState();
}

class _PasswordRecoveryRouteListenerState
    extends State<_PasswordRecoveryRouteListener> {
  @override
  void initState() {
    super.initState();
    _openRecoveryRouteIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PasswordRecoveryRouteListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isRecoveringPassword && widget.isRecoveringPassword) {
      _openRecoveryRouteIfNeeded();
    }
  }

  void _openRecoveryRouteIfNeeded() {
    if (!widget.isRecoveringPassword) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isRecoveringPassword) return;
      widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/password-recovery',
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
