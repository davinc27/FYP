// services/performance_service.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'firebase_service.dart';
import 'data_service.dart';

class PerformanceService {
  static Timer? _cacheCleanupTimer;
  static bool _isInitialized = false;

  // Initialize performance optimizations
  static void initialize() {
    if (_isInitialized) {
      developer.log('Performance service already initialized');
      return;
    }

    _isInitialized = true;
    developer.log('🚀 Initializing performance service...');

    // Start cache cleanup timer (every 5 minutes)
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanupCaches(),
    );

    developer.log('✅ Performance service initialized');
  }

  // Cleanup old caches to free memory
  static void _cleanupCaches() {
    try {
      developer.log('🧹 Cleaning up caches...');

      // Clear data service caches
      DataService.clearCache();

      // Clear Firebase sensor data cache
      FirebaseService.clearSensorDataCache();

      developer.log('✅ Cache cleanup completed');
    } catch (e) {
      developer.log('❌ Error during cache cleanup: $e');
    }
  }

  // Preload critical data for better performance
  static Future<void> preloadCriticalData() async {
    try {
      developer.log('📦 Preloading critical data...');

      // Preload sensor data for all baskets
      final basketIds = List.generate(6, (i) => 'basket${i + 1}');
      await FirebaseService.getLatestSensorDataForBaskets(basketIds);

      // Preload historical data service
      await DataService.loadSensorData();

      developer.log('✅ Critical data preloaded');
    } catch (e) {
      developer.log('❌ Error preloading critical data: $e');
    }
  }

  // Get performance metrics
  static Map<String, dynamic> getPerformanceMetrics() {
    return {
      'isInitialized': _isInitialized,
      'cacheCleanupActive': _cacheCleanupTimer?.isActive ?? false,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Dispose resources
  static void dispose() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = null;
    _isInitialized = false;
    developer.log('🛑 Performance service disposed');
  }
}
