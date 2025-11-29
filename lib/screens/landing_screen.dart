// screens/landing_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';
import 'home_screen.dart';
import '../utils/app_colors.dart';
import '../services/firebase_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  bool _isInitializing = true;
  String _statusMessage = 'Starting Terra...';
  double _progress = 0.0;
  Timer? _initializationTimer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Start the 7-second initialization process
    _startInitializationProcess();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _initializationTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startInitializationProcess() {
    // Start progress animation
    _startProgressAnimation();

    // Schedule initialization steps over 7 seconds
    _scheduleInitializationSteps();

    // Set timer to navigate after exactly 7 seconds
    _initializationTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  void _startProgressAnimation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.01; // Increment by 1% every 50ms
          if (_progress > 1.0) _progress = 1.0;
        });
      }
    });
  }

  void _scheduleInitializationSteps() {
    // Step 1: App startup (0-1 seconds)
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading Terra...';
        });
      }
    });

    // Step 2: Firebase initialization (1-3 seconds)
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Connecting to Firebase...';
        });
        _initializeFirebase();
      }
    });

    // Step 3: Services initialization (3-5 seconds)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Initializing services...';
        });
        _initializeServices();
      }
    });

    // Step 4: Data loading (5-6 seconds)
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading data...';
        });
        _loadInitialData();
      }
    });

    // Step 5: Final preparation (6-7 seconds)
    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Almost ready...';
        });
      }
    });
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            developer.log('Firebase initialization timeout');
            throw TimeoutException('Firebase timeout');
          },
        );
      }

      // Configure Firebase Database settings
      FirebaseDatabase database = FirebaseDatabase.instance;
      database.setPersistenceEnabled(true);
      database.ref().keepSynced(true);

      // Initialize Firebase Service
      FirebaseService.initializeFirebase();

      developer.log('✅ Firebase initialized successfully');
    } catch (e) {
      developer.log('❌ Firebase initialization failed: $e');
      // Continue without Firebase
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize FCM and other services
      await FirebaseService.initializeFirebaseAndFCM();
      developer.log('✅ Services initialized successfully');
    } catch (e) {
      developer.log('❌ Services initialization failed: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Preload critical data
      await FirebaseService.getLatestSensorData('basket1');
      developer.log('✅ Initial data loaded');
    } catch (e) {
      developer.log('❌ Data loading failed: $e');
    }
  }

  void _navigateToHome() {
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Ready!';
      _isInitializing = false;
    });

    // Brief pause to show ready message
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      // Navigate with fade transition
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  void _manualNavigate() {
    if (!_isInitializing) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: GestureDetector(
          onTap: _isInitializing ? null : _manualNavigate,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated logo
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/images/terra_logo.png',
                                  width: 160,
                                  height: 160,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // App name with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Terra',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFamily: 'Poppins',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Smart Melon Cultivation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brown,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Progress bar and status
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child:
                        _isInitializing
                            ? Column(
                              key: const ValueKey('loading'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Progress bar
                                Center(
                                  child: Container(
                                    width: 200,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.neutral.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _progressAnimation,
                                      builder: (context, child) {
                                        return FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _progress,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Status message
                                Center(
                                  child: Text(
                                    _statusMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.neutral,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Progress percentage
                                Center(
                                  child: Text(
                                    '${(_progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.brown,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              key: const ValueKey('ready'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _statusMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
