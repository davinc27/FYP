// screens/alerts_notifications_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/alert_monitor_service.dart';

class AlertsNotificationsScreen extends StatefulWidget {
  final bool fromHarvestMode;

  const AlertsNotificationsScreen({super.key, this.fromHarvestMode = false});

  @override
  State<AlertsNotificationsScreen> createState() =>
      _AlertsNotificationsScreenState();
}

class _AlertsNotificationsScreenState extends State<AlertsNotificationsScreen> {
  bool _pushNotifications = true;

  // Firebase alerts state
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Timer? _activeAlertsTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _alertsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _loadNotifications();
    _loadNotificationPreferences();
    // Periodically recompute active alerts to reflect latest sensor data
    _activeAlertsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _computeActiveAlertsFromSensors(),
    );
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _activeAlertsTimer?.cancel();
    super.dispose();
  }

  void _loadAlerts() {
    _computeActiveAlertsFromSensors();
  }

  Future<void> _computeActiveAlertsFromSensors() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final thresholds = AlertMonitorService.thresholds;
      final lowHumidity = thresholds['lowHumidity'] ?? 60.0;
      final lowSoil = thresholds['lowSoilMoisture'] ?? 30.0;
      final highTemp = thresholds['highTemperature'] ?? 35.0;
      final lowTemp = thresholds['lowTemperature'] ?? 15.0;

      final basketIds = List<String>.generate(6, (i) => 'basket${i + 1}');
      final results = await FirebaseService.getLatestSensorDataForBaskets(
        basketIds,
      );

      final List<Map<String, dynamic>> activeAlerts = [];

      for (final id in basketIds) {
        final data = results[id];
        if (data == null) continue;

        // Humidity
        if (data.humidity > 0 && data.humidity < lowHumidity) {
          activeAlerts.add({
            'basketId': id,
            'type': 'Low Humidity',
            'message':
                'Humidity is ${data.humidity.toStringAsFixed(0)}%. Consider increasing ventilation or moisture.',
            'severity': 'warning',
          });
        }

        // Soil Moisture (0 is considered critically low and should alert)
        if (data.soilMoisture < lowSoil) {
          activeAlerts.add({
            'basketId': id,
            'type': 'Water Needed',
            'message':
                'Soil moisture is low (${data.soilMoisture.toStringAsFixed(0)}%). Water your plants!',
            'severity': 'critical',
          });
        }

        // High Temperature
        if (data.temperature > highTemp) {
          activeAlerts.add({
            'basketId': id,
            'type': 'High Temperature',
            'message':
                'Temperature is ${data.temperature.toStringAsFixed(1)}°C. Provide shade or cooling.',
            'severity': 'warning',
          });
        }

        // Low Temperature
        if (data.temperature > 0 && data.temperature < lowTemp) {
          activeAlerts.add({
            'basketId': id,
            'type': 'Low Temperature',
            'message':
                'Temperature is ${data.temperature.toStringAsFixed(1)}°C. Melons need warmth!',
            'severity': 'warning',
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _alerts = activeAlerts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _alerts = [];
        _isLoading = false;
      });
    }
  }

  void _loadNotifications() {
    _notificationsSubscription = FirebaseService.getNotificationHistory()
        .listen(
          (List<Map<String, dynamic>> notifications) {
            if (mounted) {
              setState(() {
                _notifications = notifications;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _notifications = [];
              });
            }
          },
        );
  }

  void _loadNotificationPreferences() async {
    try {
      Map<String, dynamic>? preferences =
          await FirebaseService.getNotificationPreferences();
      if (preferences != null && mounted) {
        setState(() {
          _pushNotifications = preferences['pushNotifications'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
    }
  }

  void _saveNotificationPreferences() async {
    try {
      await FirebaseService.saveNotificationPreferences(
        emailNotifications:
            false, // Always false since we removed email notifications
        pushNotifications: _pushNotifications,
      );

      // Subscribe/unsubscribe to FCM topics based on preferences
      if (_pushNotifications) {
        await FirebaseService.subscribeToPlantAlerts();
      } else {
        await FirebaseService.unsubscribeFromPlantAlerts();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification preferences saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatBasketName(String basketId) {
    // Convert basket1, basket2, etc. to Basket 1, Basket 2, etc.
    if (basketId.startsWith('basket')) {
      final number = basketId.substring(6); // Remove 'basket' prefix
      return 'Basket $number';
    }
    return basketId; // Return as is if not in expected format
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brown,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Image.asset(
                'assets/images/back_icon.png',
                width: 24,
                height: 24,
                color: AppColors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppColors.primary),
            onPressed: () {
              _showAlertMonitoringDialog();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _computeActiveAlertsFromSensors();
        },
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        strokeWidth: 2.5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Alerts & Notifications',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Poppins",
                ),
              ),
              const SizedBox(height: 24),

              // Dynamic Alerts Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        )
                        : _alerts.isEmpty
                        ? _buildNoAlertsState()
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Active Alerts',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: "Poppins",
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_alerts.length}',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: "Poppins",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._alerts.map(
                              (alert) => _buildDynamicAlertCard(alert),
                            ),
                          ],
                        ),
              ),

              const SizedBox(height: 32),

              // Notification History Section
              if (_notifications.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification History',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Poppins",
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _notifications.take(10).length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return _buildNotificationHistoryItem(notification);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notifications Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Settings',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Poppins",
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNotificationSetting(
                      title: 'Push Notifications',
                      subtitle: 'Receive push notifications for plant alerts',
                      value: _pushNotifications,
                      onChanged: (value) {
                        setState(() {
                          _pushNotifications = value;
                        });
                        _saveNotificationPreferences();
                      },
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

  void _showAlertMonitoringDialog() {
    final thresholds = AlertMonitorService.thresholds;
    final isMonitoring = AlertMonitorService.isMonitoring;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isMonitoring ? Icons.check_circle : Icons.pause_circle,
                color: isMonitoring ? AppColors.primary : AppColors.brown,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isMonitoring ? 'Monitoring Active' : 'Monitoring Paused',
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Thresholds
              Text(
                'Alert Thresholds:',
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              _buildThresholdItem(
                'Humidity Alert',
                'Below ${thresholds['lowHumidity']}%',
                AppColors.blue,
              ),
              _buildThresholdItem(
                'Soil Moisture Alert',
                'Below ${thresholds['lowSoilMoisture']}%',
                AppColors.brown,
              ),
              _buildThresholdItem(
                'High Temperature Alert',
                'Above ${thresholds['highTemperature']}°C',
                AppColors.peach,
              ),
              _buildThresholdItem(
                'Low Temperature Alert',
                'Below ${thresholds['lowTemperature']}°C',
                AppColors.blue,
              ),

              const SizedBox(height: 16),

              // Monitoring Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neutral),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works:',
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Checks sensor data every 5 minutes\n• Sends alerts when thresholds are exceeded\n• 30-minute cooldown between same alerts\n• Works for all baskets (basket1-basket6)',
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text(
                'Close',
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThresholdItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Poppins",
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlertsState() {
    return Column(
      children: [
        Icon(
          Icons.check_circle_outline,
          color: Colors.green.shade600,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'No Active Alerts',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 18,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All your plants are healthy and happy! 🌱',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green.shade600,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] ?? 'warning';
    final isCritical = severity == 'critical';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? Colors.red.shade300 : Colors.orange.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCritical ? Colors.red.shade200 : Colors.orange.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCritical ? Icons.warning : Icons.info,
              color: isCritical ? Colors.red.shade700 : Colors.orange.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alert['type']} - ${_formatBasketName(alert['basketId'])}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Poppins",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['message'] ?? 'Attention required',
                  style: TextStyle(
                    color: isCritical ? Colors.red.shade700 : AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationHistoryItem(Map<String, dynamic> notification) {
    final timestamp = notification['timestamp'] as int? ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final timeAgo = _getTimeAgo(date);

    final alertType = notification['alertType'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final severity = notification['severity'] ?? 'info';
    final basketId = notification['basketId'] ?? '';

    final isCritical = severity == 'critical';
    final isWarning = severity == 'warning';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isCritical
                ? Colors.red.shade50
                : isWarning
                ? Colors.orange.shade50
                : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isCritical
                  ? Colors.red.shade200
                  : isWarning
                  ? Colors.orange.shade200
                  : Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color:
                  isCritical
                      ? Colors.red
                      : isWarning
                      ? Colors.orange
                      : Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$alertType - ${_formatBasketName(basketId)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Poppins",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.8),
                    fontSize: 12,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: TextStyle(
              color: AppColors.primary.withOpacity(0.6),
              fontSize: 10,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildNotificationSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Poppins",
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.8),
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: AppColors.neutral,
            inactiveTrackColor: AppColors.neutral.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
