// services/alert_monitor_service.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'firebase_service.dart';
import 'fcm_service.dart';

class AlertMonitorService {
  static Timer? _monitoringTimer;
  static bool _isMonitoring = false;

  // Alert thresholds
  static const double _lowHumidityThreshold = 60.0;
  static const double _lowSoilMoistureThreshold = 30.0;
  static const double _highTemperatureThreshold = 35.0;
  static const double _lowTemperatureThreshold = 15.0;

  // Cooldown periods to prevent spam (in minutes)
  static const int _alertCooldownMinutes = 30;
  static final Map<String, DateTime> _lastAlertTimes = {};

  // Start monitoring sensor data for alerts
  static void startMonitoring() {
    if (_isMonitoring) {
      developer.log('Alert monitoring already started');
      return;
    }

    _isMonitoring = true;
    developer.log('🚨 Starting alert monitoring service...');

    // Check for alerts every 10 minutes (reduced frequency for better performance)
    _monitoringTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _checkForAlerts(),
    );

    // Also check immediately
    _checkForAlerts();
  }

  // Stop monitoring
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    developer.log('🛑 Alert monitoring stopped');
  }

  // Check for alerts across all baskets using parallel fetching
  static Future<void> _checkForAlerts() async {
    try {
      developer.log('🔍 [ALERT DEBUG] Starting alert check...');
      developer.log('🔍 [ALERT DEBUG] Current time: ${DateTime.now()}');

      // Get all basket IDs
      final basketIds = List.generate(6, (i) => 'basket${i + 1}');
      developer.log('🔍 [ALERT DEBUG] Checking baskets: $basketIds');

      // Fetch all sensor data in parallel
      developer.log('🌐 [ALERT DEBUG] Fetching sensor data for all baskets...');
      final sensorDataMap = await FirebaseService.getLatestSensorDataForBaskets(
        basketIds,
      );

      developer.log(
        '📊 [ALERT DEBUG] Received data for ${sensorDataMap.length} baskets',
      );
      sensorDataMap.forEach((basketId, data) {
        if (data != null) {
          developer.log(
            '✅ [ALERT DEBUG] $basketId: ${data.temperature}°C, ${data.humidity}% humidity, ${data.soilMoisture}% moisture',
          );
        } else {
          developer.log('❌ [ALERT DEBUG] $basketId: No data');
        }
      });

      // Process alerts for each basket
      developer.log('🚨 [ALERT DEBUG] Processing alerts for each basket...');
      final futures = basketIds.map((basketId) async {
        final sensorData = sensorDataMap[basketId];
        if (sensorData != null) {
          developer.log('🔍 [ALERT DEBUG] Checking alerts for $basketId...');
          await _checkBasketAlertsWithData(basketId, sensorData);
        } else {
          developer.log(
            '❌ [ALERT DEBUG] No sensor data for $basketId - skipping alerts',
          );
        }
      });

      // Wait for all alert checks to complete
      await Future.wait(futures);

      developer.log(
        '✅ [ALERT DEBUG] Alert check completed for ${basketIds.length} baskets',
      );
    } catch (e) {
      developer.log('❌ [ALERT DEBUG] Error checking alerts: $e');
      developer.log('❌ [ALERT DEBUG] Error type: ${e.runtimeType}');
      developer.log('❌ [ALERT DEBUG] Stack trace: ${StackTrace.current}');
    }
  }

  // Check alerts for a specific basket with pre-fetched data
  static Future<void> _checkBasketAlertsWithData(
    String basketId,
    dynamic sensorData,
  ) async {
    try {
      // Check humidity alert
      if (sensorData.humidity < _lowHumidityThreshold &&
          sensorData.humidity > 0) {
        await _triggerAlert(
          basketId: basketId,
          alertType: 'Low Humidity',
          message:
              'Humidity is ${sensorData.humidity.toStringAsFixed(0)}%. Consider increasing ventilation or moisture.',
          severity: 'warning',
        );
      }

      // Check soil moisture alert
      if (sensorData.soilMoisture < _lowSoilMoistureThreshold &&
          sensorData.soilMoisture > 0) {
        await _triggerAlert(
          basketId: basketId,
          alertType: 'Water Needed',
          message:
              'Soil moisture is low (${sensorData.soilMoisture.toStringAsFixed(0)}%). Water your plants!',
          severity: 'critical',
        );
      }

      // Check high temperature alert
      if (sensorData.temperature > _highTemperatureThreshold) {
        await _triggerAlert(
          basketId: basketId,
          alertType: 'High Temperature',
          message:
              'Temperature is ${sensorData.temperature.toStringAsFixed(1)}°C. Provide shade or cooling.',
          severity: 'warning',
        );
      }

      // Check low temperature alert
      if (sensorData.temperature < _lowTemperatureThreshold &&
          sensorData.temperature > 0) {
        await _triggerAlert(
          basketId: basketId,
          alertType: 'Low Temperature',
          message:
              'Temperature is ${sensorData.temperature.toStringAsFixed(1)}°C. Melons need warmth!',
          severity: 'warning',
        );
      }
    } catch (e) {
      developer.log('❌ Error checking alerts for $basketId: $e');
    }
  }

  // Trigger an alert if cooldown period has passed
  static Future<void> _triggerAlert({
    required String basketId,
    required String alertType,
    required String message,
    required String severity,
  }) async {
    try {
      String alertKey = '${basketId}_${alertType}';
      DateTime now = DateTime.now();

      // Check if we've sent this alert recently
      if (_lastAlertTimes.containsKey(alertKey)) {
        DateTime lastAlert = _lastAlertTimes[alertKey]!;
        Duration timeSinceLastAlert = now.difference(lastAlert);

        if (timeSinceLastAlert.inMinutes < _alertCooldownMinutes) {
          developer.log('Alert $alertKey is in cooldown period');
          return;
        }
      }

      // Update last alert time
      _lastAlertTimes[alertKey] = now;

      // Send FCM notification to Firebase
      await FirebaseService.createAlertNotification(
        basketId: basketId,
        alertType: alertType,
        message: message,
        severity: severity,
      );

      // Show local notification for immediate visibility
      await FCMService.showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '🌱 Terra Alert - $alertType',
        body: '${_formatBasketName(basketId)}: $message',
        payload: 'basket:$basketId',
      );

      developer.log('🚨 Alert sent: $alertType for $basketId');
    } catch (e) {
      developer.log('❌ Error triggering alert: $e');
    }
  }

  // Format basket name for display
  static String _formatBasketName(String basketId) {
    if (basketId.startsWith('basket')) {
      final number = basketId.substring(6);
      return 'Basket $number';
    }
    return basketId;
  }

  // Get monitoring status
  static bool get isMonitoring => _isMonitoring;

  // Get alert thresholds
  static Map<String, double> get thresholds => {
    'lowHumidity': _lowHumidityThreshold,
    'lowSoilMoisture': _lowSoilMoistureThreshold,
    'highTemperature': _highTemperatureThreshold,
    'lowTemperature': _lowTemperatureThreshold,
  };

  // Update thresholds
  static void updateThresholds({
    double? lowHumidity,
    double? lowSoilMoisture,
    double? highTemperature,
    double? lowTemperature,
  }) {
    // Note: In a real app, you'd want to persist these settings
    developer.log('Threshold update requested - implement persistence');
  }

  // Clear alert cooldowns (for testing)
  static void clearCooldowns() {
    _lastAlertTimes.clear();
    developer.log('Alert cooldowns cleared');
  }
}
