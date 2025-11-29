// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'screens/landing_screen.dart';
import 'utils/app_colors.dart';
import 'services/data_service.dart';
import 'services/firebase_service.dart';
import 'firebase_options.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate app errors in background handler
    print('Background handler Firebase init: $e');
  }
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  print('🚀 Starting Terra app...');
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ WidgetsFlutterBinding initialized');

  // Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print('✅ FCM background handler set');

  // Start the app immediately - Firebase initialization is handled in LandingScreen
  print('🎯 Starting TerraApp...');
  runApp(const TerraApp());
}

class TerraApp extends StatefulWidget {
  const TerraApp({super.key});

  @override
  State<TerraApp> createState() => _TerraAppState();
}

class _TerraAppState extends State<TerraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    // Clear caches when memory pressure is detected
    DataService.clearCache();
    FirebaseService.clearSensorDataCache();
    super.didHaveMemoryPressure();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terra',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const LandingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
