import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:logger/logger.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/tts_service.dart';
import 'core/utils/permissions_handler.dart';
import 'core/services/settings_service.dart';
import 'core/services/battery_service.dart';
import 'core/services/error_reporting_service.dart';
import 'features/home/screens/home_screen.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await ErrorReportingService().initialize();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    WakelockPlus.enable();

    FlutterError.onError = (FlutterErrorDetails details) {
      final isOverflowError = details.exception.toString().contains('overflowed');
      if (isOverflowError) {
        if (kDebugMode) {
          logger.w('Layout overflow detected: ${details.exception}');
        }
        return;
      }
      FlutterError.presentError(details);
      ErrorReportingService().recordFlutterError(details);
      logger.e('Flutter Error', error: details.exception, stackTrace: details.stack);
    };

    runApp(const AeyeApp());
  }, (error, stackTrace) {
    logger.e('Uncaught Error', error: error, stackTrace: stackTrace);
    ErrorReportingService().recordError(error, stackTrace, fatal: true);
  });
}

class AeyeApp extends StatelessWidget {
  const AeyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aeye',
      theme: AppTheme.darkTheme,
      home: const LoadingScreen(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: Material(child: child!),
        );
      },
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _loadingStatus = 'Starting...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Request permissions
      setState(() => _loadingStatus = 'Requesting permissions...');
      await PermissionsHandler.requestAllPermissions();

      // Initialize TTS
      setState(() => _loadingStatus = 'Initializing voice...');
      await TTSService().initialize();

      // Initialize settings
      setState(() => _loadingStatus = 'Loading settings...');
      await SettingsService().initialize();

      // Initialize battery service
      setState(() => _loadingStatus = 'Preparing services...');
      await BatteryService().initialize();

      logger.i('✅ All services initialized successfully');

      setState(() => _loadingStatus = 'Ready!');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e, stackTrace) {
      logger.e('❌ Error initializing app', error: e, stackTrace: stackTrace);
      ErrorReportingService().recordError(e, stackTrace, fatal: false);

      if (mounted) {
        setState(() {
          _hasError = true;
          _loadingStatus = 'Error: ${e.toString().split('\n').first}';
        });

        // Still try to navigate after error
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceColor,
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo with glow effect
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 140,
                        height: 140,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.visibility_rounded,
                              size: 70,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // App Name
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'AEye',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                ),
              ),

              const SizedBox(height: 8),

              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Your Vision, Enhanced',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    if (!_hasError)
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                          strokeWidth: 3,
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningColor,
                          size: 28,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _loadingStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _hasError ? AppTheme.warningColor : AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
