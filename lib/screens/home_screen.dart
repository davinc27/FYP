// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'statistics_screen.dart';
import 'new_basket_screen.dart';
import 'plant_details_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/side_menu_drawer.dart';
import '../widgets/base64_image.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';
import '../models/basket.dart';
import 'alerts_notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Sensor data state
  double _temperature = 0.0;
  double _humidity = 0.0;
  String _temperatureError = '';
  String _humidityError = '';
  bool _isDataLoading = true;

  // Alerts state
  List<Map<String, dynamic>> _alerts = [];
  bool _hasAlerts = false;

  // Harvest mode state
  bool _isHarvestMode = false;
  late AnimationController _harvestModeAnimationController;
  Animation<double>? _harvestModeAnimation;

  // Streams subscription management
  StreamSubscription<SensorData?>? _sensorDataSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _alertsSubscription;
  StreamSubscription<List<Basket>>? _basketsSubscription;

  // Basket data caching
  List<Basket> _cachedBaskets = [];
  bool _isBasketsLoading = true;

  // Encouraging messages for no alerts
  final List<String> _encouragingMessages = [
    "Your Melons are Growing Well! 🌱",
    "Everything Looks Perfect! ✨",
    "Your Plants are Happy! 😊",
    "Great Growing Conditions! 🌟",
    "Your Melons are Thriving! 🍈",
    "Perfect Care, Perfect Growth! 💚",
    "Your Plants Love the Attention! 🌿",
    "Healthy Plants, Happy Harvest! 🌱",
    "Excellent Plant Parenting! 👍",
    "Your Garden is Flourishing! 🌺",
  ];

  // Empty state messages for baskets
  final List<String> _emptyStateMessages = [
    "Let's start planting! 🌱",
    "It's quiet here... Time to grow something amazing! 🌿",
    "Your garden awaits! Add your first melon basket 🍈",
    "Ready to grow? Tap + to begin your journey! 🚀",
    "Empty space = Opportunity! Start planting now 🌱",
    "No melons yet? Let's change that! 🍈",
    "Your green thumb is ready! Add a basket 👍",
    "Time to turn this space into a garden! 🌺",
  ];

  String _currentEncouragingMessage = '';
  String _currentEmptyMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _harvestModeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _harvestModeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _harvestModeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
    _alertsSubscription?.cancel();
    _basketsSubscription?.cancel();
    _harvestModeAnimationController.dispose();
    super.dispose();
  }

  void _initializeData() async {
    _setRandomMessages();

    // Only load data if not in harvest mode
    if (!_isHarvestMode) {
      // Check if Firebase is available
      try {
        // Debug check to see what's in Firebase
        await FirebaseService.debugCheckAllData();

        // Quick connection test with timeout
        FirebaseService.testConnection()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                developer.log('Firebase connection test timed out');
                if (mounted) {
                  setState(() {
                    _isDataLoading = false;
                    _temperatureError = 'Connection timeout';
                    _humidityError = 'Connection timeout';
                  });
                }
                return false;
              },
            )
            .then((isConnected) {
              if (isConnected) {
                developer.log('Firebase connected successfully');
                _loadSensorData();
                _loadAlerts();
                _loadBaskets();
              } else {
                developer.log('Firebase connection failed');
                if (mounted) {
                  setState(() {
                    _isDataLoading = false;
                    _temperatureError = 'Connection failed';
                    _humidityError = 'Connection failed';
                  });
                }
              }
            });
      } catch (e) {
        developer.log('Firebase not available: $e');
        if (mounted) {
          setState(() {
            _isDataLoading = false;
            _temperatureError = 'Firebase not available';
            _humidityError = 'Firebase not available';
          });
        }
      }

      // Set a timeout for loading
      Timer(Duration(seconds: 6), () {
        if (mounted && _isDataLoading) {
          setState(() {
            _isDataLoading = false;
            if (_temperature == 0 && _humidity == 0) {
              _temperatureError = 'No data';
              _humidityError = 'No data';
            }
          });
        }
      });
    } else {
      // In harvest mode, set appropriate states
      setState(() {
        _isDataLoading = false;
        _temperatureError = 'Harvest Mode';
        _humidityError = 'Harvest Mode';
      });
    }
  }

  void _setRandomMessages() {
    final random = Random();
    _currentEncouragingMessage =
        _encouragingMessages[random.nextInt(_encouragingMessages.length)];
    _currentEmptyMessage =
        _emptyStateMessages[random.nextInt(_emptyStateMessages.length)];
  }

  void _toggleHarvestMode() {
    setState(() {
      _isHarvestMode = !_isHarvestMode;
    });

    if (_isHarvestMode) {
      _harvestModeAnimationController.forward();
      // Cancel data streams when entering harvest mode
      _sensorDataSubscription?.cancel();
      _alertsSubscription?.cancel();
      setState(() {
        _temperatureError = 'Harvest Mode';
        _humidityError = 'Harvest Mode';
        _isDataLoading = false;
      });
    } else {
      _harvestModeAnimationController.reverse();
      // Reinitialize data when exiting harvest mode
      _initializeData();
    }
  }

  void _loadSensorData() async {
    try {
      setState(() {
        _isDataLoading = true;
        _temperatureError = '';
        _humidityError = '';
      });

      // Query latest sensor data for all baskets and pick the first available
      final basketIds = List<String>.generate(6, (i) => 'basket${i + 1}');
      final results = await FirebaseService.getLatestSensorDataForBaskets(
        basketIds,
      );

      SensorData? firstAvailable;
      for (final id in basketIds) {
        final data = results[id];
        if (data != null) {
          firstAvailable = data;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        if (firstAvailable != null) {
          _temperature = firstAvailable.temperature;
          _humidity = firstAvailable.humidity;
          _temperatureError = '';
          _humidityError = '';
        } else {
          _temperatureError = 'No data';
          _humidityError = 'No data';
        }
        _isDataLoading = false;
      });
    } catch (e) {
      developer.log('Sensor data load error: $e');
      if (mounted) {
        setState(() {
          _temperatureError = 'Error loading';
          _humidityError = 'Error loading';
          _isDataLoading = false;
        });
      }
    }
  }

  void _loadAlerts() {
    // Mirror Alerts & Notifications by using the notification history stream
    _alertsSubscription = FirebaseService.getNotificationHistory().listen(
      (List<Map<String, dynamic>> notifications) {
        if (!mounted) return;

        setState(() {
          _alerts =
              notifications; // Keep as-is; renderer will use history layout
          _hasAlerts = notifications.isNotEmpty;
          if (!_hasAlerts) {
            _setRandomMessages();
          }
        });
      },
      onError: (error) {
        developer.log('Alerts error: $error');
        if (mounted) {
          setState(() {
            _alerts = [];
            _hasAlerts = false;
          });
        }
      },
    );
  }

  void _loadBaskets() {
    _basketsSubscription = FirebaseService.getBasketsStream().listen(
      (List<Basket> baskets) {
        if (!mounted) return;

        setState(() {
          _cachedBaskets = baskets;
          _isBasketsLoading = false;
        });
      },
      onError: (error) {
        developer.log('Baskets error: $error');
        if (mounted) {
          setState(() {
            _cachedBaskets = [];
            _isBasketsLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const SideMenuDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brown,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Image.asset(
                'assets/images/hamburger_icon.png',
                width: 24,
                height: 24,
                color: AppColors.white,
              ),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ),
        ),
        actions: [
          // Harvest Mode Toggle Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _toggleHarvestMode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isHarvestMode ? Colors.orange : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_isHarvestMode
                              ? Colors.orange
                              : AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isHarvestMode
                          ? Icons.agriculture
                          : Icons.agriculture_outlined,
                      color: AppColors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isHarvestMode ? 'Harvest Mode' : 'Harvest',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: AppColors.neutral,
            child: Image.asset(
              'assets/images/profile_icon.png',
              width: 24,
              height: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                if (!_isHarvestMode) {
                  setState(() {
                    _isBasketsLoading = true;
                  });
                  _initializeData();
                  await Future.delayed(Duration(seconds: 1));
                }
              },
              color: AppColors.primary,
              backgroundColor: AppColors.background,
              strokeWidth: 2.5,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        AppBar().preferredSize.height -
                        MediaQuery.of(context).padding.top,
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Japanese Musk Melon',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontFamily: "Poppins",
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Temperature and Humidity Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMetricCard(
                            label: 'Temperature',
                            value: _getTemperatureDisplayValue(),
                            color: AppColors.background,
                            hasError: _temperatureError.isNotEmpty,
                            isLoading: _isDataLoading,
                          ),
                          _buildMetricCard(
                            label: 'Humidity',
                            value: _getHumidityDisplayValue(),
                            color: AppColors.background,
                            hasError: _humidityError.isNotEmpty,
                            isLoading: _isDataLoading,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Alerts Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _hasAlerts ? 'Alerts' : 'Status',
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          if (_hasAlerts && _alerts.length > 3)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const AlertsNotificationsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View All (${_alerts.length})',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 12,
                                        fontFamily: "Poppins",
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppColors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAlertsOrEncouragingMessage(),
                      const SizedBox(height: 24),

                      // Baskets Grid
                      Text(
                        'My Baskets',
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Baskets Grid - Now part of main scroll with cached data
                      _buildBasketsGrid(),
                      const SizedBox(height: 90), // Extra space for bottom nav
                    ],
                  ),
                ),
              ),
            ),
            // Glass Effect Overlay for Harvest Mode
            if (_isHarvestMode && _harvestModeAnimation != null)
              AnimatedBuilder(
                animation: _harvestModeAnimation!,
                builder: (context, child) {
                  return Opacity(
                    opacity: _harvestModeAnimation!.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: _buildHarvestOverlayContent(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHarvestOverlayContent() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.agriculture,
                size: 40,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Harvest Mode Active',
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All monitoring systems are paused.\nYour melons are ready for harvest! 🍈',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHarvestModeActionButton(
                  iconPath: 'assets/images/statistics_icon.png',
                  label: 'Statistics',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                const StatisticsScreen(fromHarvestMode: true),
                      ),
                    );
                  },
                ),
                _buildHarvestModeActionButton(
                  iconPath: 'assets/images/alert_icon.png',
                  label: 'Alerts',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const AlertsNotificationsScreen(
                              fromHarvestMode: true,
                            ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _toggleHarvestMode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/exit_icon.png',
                      width: 20,
                      height: 20,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Exit Harvest Mode',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasketsGrid() {
    if (_isBasketsLoading) {
      return Container(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_cachedBaskets.isEmpty) {
      return Container(height: 200, child: _buildEmptyBasketsState());
    }

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: NeverScrollableScrollPhysics(), // Outer scroll handles scrolling
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _cachedBaskets.length,
      itemBuilder: (context, index) {
        final basket = _cachedBaskets[index];
        return _buildBasketCard(
          basket.name,
          'assets/images/melon.png',
          basket.id,
          plantingDate: basket.plantingDate,
          imageUrl: basket.imageUrl,
          locationTag: basket.locationTag,
        );
      },
    );
  }

  Widget _buildEmptyBasketsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, color: AppColors.neutral, size: 64),
          const SizedBox(height: 16),
          Text(
            'No baskets yet',
            style: TextStyle(
              color: AppColors.neutral,
              fontSize: 18,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentEmptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.neutral,
              fontSize: 14,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestModeActionButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              iconPath,
              width: 24,
              height: 24,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTemperatureDisplayValue() {
    if (_isDataLoading) return '...';
    if (_temperatureError.isNotEmpty) return _temperatureError;
    return '${_temperature.toStringAsFixed(1)}°C';
  }

  String _getHumidityDisplayValue() {
    if (_isDataLoading) return '...';
    if (_humidityError.isNotEmpty) return _humidityError;
    return '${_humidity.toStringAsFixed(0)}%';
  }

  String _formatBasketName(String basketId) {
    // Convert basket1, basket2, etc. to Basket 1, Basket 2, etc.
    if (basketId.startsWith('basket')) {
      final number = basketId.substring(6); // Remove 'basket' prefix
      return 'Basket $number';
    }
    return basketId; // Return as is if not in expected format
  }

  String _resolveLocationLabel(String? locationTag, String basketId) {
    if (locationTag != null && locationTag.trim().isNotEmpty) {
      return locationTag.trim();
    }
    // Fallback label if location tag missing
    return _formatBasketName(basketId);
  }

  Widget _buildAlertsOrEncouragingMessage() {
    if (_hasAlerts && _alerts.isNotEmpty) {
      final alertsToShow = _alerts.take(3).toList();
      return Column(
        children: [
          ...alertsToShow.map((n) => _buildHomeNotificationItem(n)).toList(),
          if (_alerts.length > 3)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.more_horiz, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_alerts.length - 3} more alerts',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade50,
              Colors.green.shade100.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Systems Good!',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    _currentEncouragingMessage,
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHomeNotificationItem(Map<String, dynamic> notification) {
    final timestamp = notification['timestamp'] as int? ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final timeAgo = _getTimeAgo(date);

    final alertType =
        notification['alertType'] ?? (notification['type'] ?? 'Notification');
    final message = notification['message'] ?? '';
    final severity = notification['severity'] ?? 'info';
    final basketId = notification['basketId'] ?? '';

    final isCritical = severity == 'critical';
    final isWarning = severity == 'warning';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: AppColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Poppins",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.black.withOpacity(0.8),
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
              color: AppColors.black.withOpacity(0.6),
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

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    bool hasError = false,
    bool isLoading = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasError ? Colors.red.shade50 : color,
          borderRadius: BorderRadius.circular(12),
          border:
              hasError
                  ? Border.all(color: Colors.red.shade300, width: 1)
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w400,
                color: hasError ? Colors.red.shade700 : AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            isLoading
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
                : Text(
                  value,
                  style: TextStyle(
                    fontSize: hasError ? 16 : 24,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w800,
                    color: hasError ? Colors.red.shade700 : AppColors.black,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasketCard(
    String name,
    String imagePath,
    String basketId, {
    DateTime? plantingDate,
    String? imageUrl,
    String? locationTag,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve:
          Curves.easeOutCubic, // Changed from easeOutBack to avoid values > 1.0
      builder: (context, value, child) {
        // Clamp the value to ensure it's within valid range
        final clampedValue = value.clamp(0.0, 1.0);

        return Transform.scale(
          scale: clampedValue,
          child: Opacity(
            opacity: clampedValue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      _isHarvestMode
                          ? null
                          : () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        PlantDetailsScreen(
                                          basketName: name,
                                          basketId: basketId,
                                          plantingDate: plantingDate,
                                        ),
                                transitionsBuilder: (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;

                                  var tween = Tween(
                                    begin: begin,
                                    end: end,
                                  ).chain(CurveTween(curve: curve));

                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration: const Duration(
                                  milliseconds: 300,
                                ),
                              ),
                            );
                          },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _isHarvestMode
                              ? AppColors.accent.withOpacity(0.5)
                              : AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Base64Image(
                            imageData: imageUrl,
                            fallbackAsset: imagePath,
                            width: 140,
                            height: 140,
                            fit:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? BoxFit.cover
                                    : BoxFit.contain,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _resolveLocationLabel(locationTag, basketId),
                                style: TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.brown,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: AppColors.background,
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavItem(
            index: 0,
            imagePath: 'assets/images/plant_icon.png',
            onTap:
                _isHarvestMode
                    ? null
                    : () {
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
            isDisabled: _isHarvestMode,
          ),
          const SizedBox(width: 40),
          _buildNavItem(
            index: 1,
            imagePath: 'assets/images/add_icon.png',
            onTap:
                _isHarvestMode
                    ? null
                    : () {
                      setState(() {
                        _currentIndex = 1;
                      });
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const NewBasketScreen(),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
                            const begin = Offset(0.0, 1.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOut;

                            var tween = Tween(
                              begin: begin,
                              end: end,
                            ).chain(CurveTween(curve: curve));

                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
            isDisabled: _isHarvestMode,
          ),
          const SizedBox(width: 40),
          _buildNavItem(
            index: 2,
            imagePath: 'assets/images/statistics_icon.png',
            onTap: () {
              setState(() {
                _currentIndex = 2;
              });
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          const StatisticsScreen(),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
            isDisabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String imagePath,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          imagePath,
          width: 32,
          height: 32,
          color:
              isDisabled
                  ? AppColors.neutral.withOpacity(0.3)
                  : (isSelected ? AppColors.primary : AppColors.neutral),
        ),
      ),
    );
  }
}
