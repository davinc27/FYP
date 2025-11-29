// screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'home_screen.dart';
import 'new_basket_screen.dart';
import '../utils/app_colors.dart';
import '../services/data_service.dart';
import '../models/sensor_data.dart';

class StatisticsScreen extends StatefulWidget {
  final bool fromHarvestMode;

  const StatisticsScreen({super.key, this.fromHarvestMode = false});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedPeriod = 'Today';
  final int _currentIndex = 2;

  @override
  bool get wantKeepAlive => true;

  // Data storage
  List<SensorData> _allData = [];
  List<SensorData> _filteredData = [];
  Map<String, double> _averages = {
    'temperature': 0.0,
    'humidity': 0.0,
    'soilMoisture': 0.0,
    'soilEC': 0.0,
    'soilPH': 0.0,
    'lightIntensity': 0.0,
  };
  bool _isLoading = true;

  // Current date and time for dynamic scheduling
  DateTime _currentDateTime = DateTime.now();

  // Lazy loading for charts
  final Map<String, List<Map<String, dynamic>>> _chartDataCache = {};
  final Set<String> _loadedCharts = {};

  // Additional filtering options
  String? _selectedWeek;
  String? _selectedMonth;
  List<String> _availableWeeks = [];
  List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _updateCurrentTime();
    _loadData();

    // Update time every minute to keep schedules current
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _updateCurrentTime();
      }
    });
  }

  void _updateCurrentTime() {
    setState(() {
      _currentDateTime = DateTime.now();
    });
  }

  List<Map<String, String>> _getCurrentWateringSchedule() {
    final now = _currentDateTime;
    final today = DateTime(now.year, now.month, now.day);

    List<Map<String, String>> schedule = [];

    // Always water at 8 AM
    final morningTime = DateTime(today.year, today.month, today.day, 8, 0);
    final isMorningCompleted = now.isAfter(morningTime);

    schedule.add({
      'time': '08:00 AM',
      'status': isMorningCompleted ? 'Completed' : 'Pending',
      'completed': isMorningCompleted.toString(),
    });

    // Determine second watering based on weather conditions
    String secondWateringTime = '10:00 AM'; // Default to 10 AM

    if (_filteredData.isNotEmpty) {
      // Calculate average temperature and humidity for today's data
      final todayData =
          _filteredData
              .where(
                (item) =>
                    item.timestamp.isAfter(today) &&
                    item.timestamp.isBefore(today.add(const Duration(days: 1))),
              )
              .toList();

      if (todayData.isNotEmpty) {
        final avgTemp =
            todayData.map((e) => e.temperature).reduce((a, b) => a + b) /
            todayData.length;
        final avgHumidity =
            todayData.map((e) => e.humidity).reduce((a, b) => a + b) /
            todayData.length;

        if (avgTemp > 30 || avgHumidity < 60) {
          secondWateringTime = '10:00 AM';
        } else {
          secondWateringTime = '12:00 PM';
        }
      }
    }

    final secondTime =
        secondWateringTime == '10:00 AM'
            ? DateTime(today.year, today.month, today.day, 10, 0)
            : DateTime(today.year, today.month, today.day, 12, 0);
    final isSecondCompleted = now.isAfter(secondTime);

    schedule.add({
      'time': secondWateringTime,
      'status': isSecondCompleted ? 'Completed' : 'Pending',
      'completed': isSecondCompleted.toString(),
    });

    return schedule;
  }

  bool _isFertilizingDayPassed(String dayName) {
    final today = _currentDateTime.weekday;
    final dayMap = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };

    final targetDay = dayMap[dayName] ?? 0;
    if (targetDay == 0) return false;

    // If it's the same day, check if it's past 8 AM (typical fertilizing time)
    if (today == targetDay) {
      return _currentDateTime.hour >= 8;
    }

    // If it's past the target day in the week
    return today > targetDay;
  }

  String _getFertilizingStatus(String dayName) {
    final today = _currentDateTime.weekday;
    final dayMap = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };

    final targetDay = dayMap[dayName] ?? 0;
    if (targetDay == 0) return 'Tue, Thu, Sat';

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (today == targetDay) {
      return _currentDateTime.hour >= 8 ? 'Completed' : 'Due Today';
    } else if (today > targetDay) {
      return 'Completed';
    } else {
      return 'Due ${dayNames[targetDay - 1]}';
    }
  }

  @override
  void dispose() {
    // Clear all caches when screen is disposed to free memory
    DataService.clearCache();
    _chartDataCache.clear();
    _loadedCharts.clear();
    _allData.clear();
    _filteredData.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await DataService.loadSensorData();
      setState(() {
        _allData = data;
        _filteredData = DataService.filterDataByPeriod(data, _selectedPeriod);
        _averages = DataService.calculateAverages(_filteredData);
        _isLoading = false;
      });

      developer.log('Loaded ${data.length} data points');
      developer.log(
        'Filtered data for $_selectedPeriod: ${_filteredData.length} items',
      );
      developer.log('Averages: $_averages');

      // Generate available weeks and months
      _generateAvailablePeriods();
    } catch (e) {
      developer.log('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateAvailablePeriods() {
    if (_allData.isEmpty) return;

    // Get actual data range instead of current date
    final sortedData = List<SensorData>.from(_allData)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final firstDate = sortedData.first.timestamp;
    final lastDate = sortedData.last.timestamp;

    developer.log(
      'Generating periods from data range: $firstDate to $lastDate',
    );

    final weeks = <String>[];
    final months = <String>[];

    // Generate weeks from actual data range (July 7, 2025 to September 4, 2025)
    DateTime currentWeekStart = DateTime(
      firstDate.year,
      firstDate.month,
      firstDate.day - firstDate.weekday + 1, // Start from Monday
    );

    // Continue generating weeks until we reach the end of the data
    while (currentWeekStart.isBefore(lastDate.add(const Duration(days: 7)))) {
      final weekEnd = currentWeekStart.add(const Duration(days: 6));

      // Only add weeks that have data
      if (currentWeekStart.isBefore(lastDate)) {
        // Check if this is the last week (most recent data)
        final isLastWeek = currentWeekStart
            .add(const Duration(days: 6))
            .isAfter(lastDate.subtract(const Duration(days: 1)));

        if (isLastWeek) {
          weeks.add(
            'This Week (${currentWeekStart.day}/${currentWeekStart.month} - ${weekEnd.day}/${weekEnd.month})',
          );
        } else {
          weeks.add(
            'Week ${currentWeekStart.day}/${currentWeekStart.month} - ${weekEnd.day}/${weekEnd.month}',
          );
        }
        developer.log(
          'Added week: ${currentWeekStart.day}/${currentWeekStart.month} - ${weekEnd.day}/${weekEnd.month}',
        );
      }

      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    // Generate months from actual data range (July 2025 to September 2025)
    DateTime currentMonth = DateTime(firstDate.year, firstDate.month);

    // Continue generating months until we reach the end of the data
    while (currentMonth.isBefore(lastDate.add(const Duration(days: 31)))) {
      final monthName = _getMonthName(currentMonth.month);

      // Only add months that have data
      if (currentMonth.isBefore(lastDate)) {
        // Check if this is the last month (most recent data)
        final isLastMonth =
            currentMonth.month == lastDate.month &&
            currentMonth.year == lastDate.year;

        if (isLastMonth) {
          months.add('This Month ($monthName ${currentMonth.year})');
        } else {
          months.add('$monthName ${currentMonth.year}');
        }
      }

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    }

    setState(() {
      _availableWeeks = weeks;
      _availableMonths = months;
      // Set initial selected values to show latest data
      _selectedWeek = weeks.isNotEmpty ? weeks.last : null;
      _selectedMonth = months.isNotEmpty ? months.last : null;
    });

    developer.log(
      'Generated ${weeks.length} weeks and ${months.length} months',
    );
    developer.log('Available weeks: $weeks');
    developer.log('Available months: $months');
    developer.log('First date: $firstDate');
    developer.log('Last date: $lastDate');
    developer.log('Current system date: ${DateTime.now()}');
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Future<void> _loadAverages() async {
    try {
      // Show loading indicator for better UX
      setState(() {
        _isLoading = true;
      });

      // Use cached data if available, otherwise process in background
      final filteredData = DataService.filterDataByPeriod(
        _allData,
        _selectedPeriod,
        selectedWeek: _selectedWeek,
        selectedMonth: _selectedMonth,
      );

      final averages = DataService.calculateAverages(filteredData);

      // Only update state if widget is still mounted
      if (mounted) {
        setState(() {
          _filteredData = filteredData;
          _averages = averages;
          _isLoading = false;
        });
      }

      developer.log(
        'Filtered data for $_selectedPeriod: ${_filteredData.length} items',
      );
      developer.log('Averages: $_averages');

      // Clear chart cache when period changes to free memory
      _chartDataCache.clear();
      _loadedCharts.clear();
    } catch (e) {
      developer.log('Error loading averages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Clear cache and retry if memory error
      if (e.toString().contains('OutOfMemory') ||
          e.toString().contains('memory')) {
        DataService.clearCache();
        _chartDataCache.clear();
        _loadedCharts.clear();
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:
          widget.fromHarvestMode
              ? AppBar(
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
              )
              : null,
      body: SafeArea(
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Statistics',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Poppins",
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stat cards grid (2 rows x 3 columns)
                      Column(
                        children: [
                          // First row of stat cards (Temperature, Humidity, Soil Moisture)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  iconPath: 'assets/images/temp_icon.png',
                                  label: 'Temperature',
                                  value:
                                      '${_averages['temperature']?.toStringAsFixed(2) ?? '25.00'}°C',
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  iconPath: 'assets/images/hum_icon.png',
                                  label: 'Humidity',
                                  value:
                                      '${_averages['humidity']?.toStringAsFixed(2) ?? '74.00'}%',
                                  color: AppColors.neutral,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  iconPath: 'assets/images/soil_icon.png',
                                  label: 'Soil Moisture',
                                  value:
                                      '${_averages['soilMoisture']?.toStringAsFixed(2) ?? '50.00'}%',
                                  color: AppColors.brown,
                                  textColor: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Second row of stat cards (pH, Soil EC, Light Intensity)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  iconPath:
                                      'assets/images/soil_icon.png', // Using soil icon for pH
                                  label: 'Soil pH',
                                  value:
                                      _averages['soilPH']?.toStringAsFixed(2) ??
                                      '6.50',
                                  color: AppColors.peach,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  iconPath:
                                      'assets/images/soil_icon.png', // Using soil icon for EC
                                  label: 'Soil EC',
                                  value:
                                      '${_averages['soilEC']?.toStringAsFixed(2) ?? '70.00'}%',
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  iconPath:
                                      'assets/images/temp_icon.png', // Using temp icon for light
                                  label: 'Light Intensity',
                                  value:
                                      '${_averages['lightIntensity']?.round() ?? 850} lux',
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Period Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _buildPeriodChip(
                                'Today',
                                _selectedPeriod == 'Today',
                              ),
                              const SizedBox(width: 8),
                              _buildPeriodChip(
                                'Weekly',
                                _selectedPeriod == 'Weekly',
                              ),
                              const SizedBox(width: 8),
                              _buildPeriodChip(
                                'Monthly',
                                _selectedPeriod == 'Monthly',
                              ),
                            ],
                          ),
                          if (_selectedPeriod == 'Weekly') ...[
                            const SizedBox(height: 12),
                            _availableWeeks.isNotEmpty
                                ? _buildWeekDropdown()
                                : _buildLoadingDropdown('Loading weeks...'),
                          ],
                          if (_selectedPeriod == 'Monthly') ...[
                            const SizedBox(height: 12),
                            _availableMonths.isNotEmpty
                                ? _buildMonthDropdown()
                                : _buildLoadingDropdown('Loading months...'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Temperature Chart
                      _buildChartSection('Temperature'),
                      const SizedBox(height: 24),

                      // Humidity Chart
                      _buildChartSection('Humidity'),
                      const SizedBox(height: 24),

                      // Soil Moisture Chart
                      _buildChartSection('Soil Moisture'),
                      const SizedBox(height: 24),

                      // Soil pH Chart
                      _buildChartSection('Soil pH'),
                      const SizedBox(height: 24),

                      // Soil EC Chart
                      _buildChartSection('Soil EC'),
                      const SizedBox(height: 24),

                      // Light Intensity Chart
                      _buildChartSection('Light Intensity'),
                      const SizedBox(height: 32),

                      // Watering Schedule Section
                      _buildWateringScheduleSection(),
                      const SizedBox(height: 24),

                      // Fertilizing Status/Schedule Section
                      _buildFertilizingSection(),
                      const SizedBox(height: 24),

                      // Pesticide Trapping Section
                      _buildPesticideTrappingSection(),
                      const SizedBox(height: 24),

                      // Plant Substrate Information Section
                      _buildPlantSubstrateSection(),
                    ],
                  ),
                ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStatCard({
    required String iconPath,
    required String label,
    required String value,
    required Color color,
    Color? textColor,
  }) {
    return Container(
      height: 120, // Fixed height for consistency
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Image.asset(
            iconPath,
            width: 28,
            height: 28,
            color: textColor ?? AppColors.primary,
          ),
          const SizedBox(height: 8),
          // Label with better text handling
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor ?? AppColors.primary,
                fontSize: 11,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Value with better text handling
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor ?? AppColors.primary,
                fontSize: 18,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadAverages(); // Reload data when period changes
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.neutral,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.primary,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: _selectedWeek,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(
          'Select Week',
          style: TextStyle(
            color: AppColors.neutral,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w500,
          ),
        ),
        items:
            _availableWeeks.map((String week) {
              return DropdownMenuItem<String>(
                value: week,
                child: Text(
                  week,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedWeek = newValue;
            });
            _loadAverages();
          }
        },
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: _selectedMonth,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(
          'Select Month',
          style: TextStyle(
            color: AppColors.neutral,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w500,
          ),
        ),
        items:
            _availableMonths.map((String month) {
              return DropdownMenuItem<String>(
                value: month,
                child: Text(
                  month,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedMonth = newValue;
            });
            _loadAverages();
          }
        },
      ),
    );
  }

  Widget _buildLoadingDropdown(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.neutral.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: AppColors.neutral,
              fontSize: 14,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(String title) {
    try {
      // Use DataService's built-in caching instead of local cache
      final chartData = DataService.prepareChartData(
        _filteredData,
        title,
        _selectedPeriod,
      );

      if (chartData.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        color: AppColors.neutral,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No data available for $title',
                        style: TextStyle(
                          color: AppColors.neutral,
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filtered data: ${_filteredData.length} items',
                        style: TextStyle(
                          color: AppColors.neutral.withOpacity(0.7),
                          fontFamily: "Poppins",
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 20.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine:
                          false, // Disable vertical lines for better performance
                      horizontalInterval: _getValueInterval(chartData, title),
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.neutral.withOpacity(0.15),
                          strokeWidth: 0.5,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: _getTimeInterval(chartData.length),
                          getTitlesWidget: (value, meta) {
                            if (value >= chartData.length)
                              return const Text('');
                            final timestamp =
                                chartData[value.toInt()]['timestamp']
                                    as DateTime;
                            return Text(
                              _formatChartTimeLabel(
                                timestamp,
                                chartData.length,
                              ),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontFamily: "Poppins",
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _getValueInterval(chartData, title),
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            // Format numbers based on their magnitude for better readability
                            String formattedValue;
                            if (value >= 1000) {
                              formattedValue =
                                  '${(value / 1000).toStringAsFixed(1)}k';
                            } else if (value >= 100) {
                              formattedValue = value.toStringAsFixed(0);
                            } else if (value >= 10) {
                              formattedValue = value.toStringAsFixed(1);
                            } else {
                              formattedValue = value.toStringAsFixed(2);
                            }

                            return Text(
                              formattedValue,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontFamily: "Poppins",
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: AppColors.neutral.withOpacity(0.2),
                      ),
                    ),
                    minX: 0,
                    maxX: (chartData.length - 1).toDouble(),
                    minY: _getMinValue(chartData, title),
                    maxY: _getMaxValue(chartData, title),
                    lineBarsData: [
                      LineChartBarData(
                        spots:
                            chartData.asMap().entries.map((entry) {
                              return FlSpot(
                                entry.key.toDouble(),
                                entry.value['y'] as double,
                              );
                            }).toList(),
                        isCurved: true,
                        color: _getChartColor(title),
                        barWidth: 3.0,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show:
                              chartData.length <=
                              20, // Show dots only for very small datasets
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: _getChartColor(title),
                              strokeWidth: 1,
                              strokeColor: AppColors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _getChartColor(title).withOpacity(0.15),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _getChartColor(title).withOpacity(0.3),
                              _getChartColor(title).withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log('Error building chart for $title: $e');
      // Return error container if chart fails
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading chart data',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  double _getTimeInterval(int dataLength) {
    if (dataLength <= 5) return 1;
    if (dataLength <= 10) return 2;
    if (dataLength <= 20) return 4;
    if (dataLength <= 40) return 8;
    return 12;
  }

  double _getValueInterval(List<Map<String, dynamic>> data, String title) {
    final values = data.map((d) => d['y'] as double).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;

    // Calculate appropriate interval based on range and data type
    double interval;
    if (range <= 2) {
      interval = 0.5;
    } else if (range <= 5) {
      interval = 1;
    } else if (range <= 10) {
      interval = 2;
    } else if (range <= 20) {
      interval = 5;
    } else if (range <= 50) {
      interval = 10;
    } else if (range <= 100) {
      interval = 20;
    } else if (range <= 500) {
      interval = 50;
    } else if (range <= 1000) {
      interval = 100;
    } else if (range <= 2000) {
      interval = 200;
    } else {
      interval = 500;
    }

    // Ensure we don't have too many labels (max 5 labels for better readability)
    final maxLabels = 5;
    final currentLabels = (range / interval).ceil();
    if (currentLabels > maxLabels) {
      interval = range / maxLabels;
    }

    return interval;
  }

  double _getMinValue(List<Map<String, dynamic>> data, String title) {
    final values = data.map((d) => d['y'] as double).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    return min - (min * 0.1);
  }

  double _getMaxValue(List<Map<String, dynamic>> data, String title) {
    final values = data.map((d) => d['y'] as double).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    return max + (max * 0.1);
  }

  Color _getChartColor(String title) {
    switch (title) {
      case 'Temperature':
        return AppColors.blue;
      case 'Humidity':
        return AppColors.neutral;
      case 'Soil Moisture':
        return AppColors.brown;
      case 'Soil pH':
        return AppColors.peach;
      case 'Soil EC':
        return AppColors.secondary;
      case 'Light Intensity':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _formatChartTimeLabel(DateTime timestamp, int totalPoints) {
    switch (_selectedPeriod) {
      case 'Today':
        // Show hour for today view with better spacing
        if (totalPoints <= 6) {
          return '${timestamp.hour.toString().padLeft(2, '0')}:00';
        } else if (totalPoints <= 12) {
          // Show every 2 hours
          if (timestamp.hour % 2 == 0) {
            return '${timestamp.hour.toString().padLeft(2, '0')}:00';
          }
          return '';
        } else {
          // Show every 4 hours
          if (timestamp.hour % 4 == 0) {
            return '${timestamp.hour.toString().padLeft(2, '0')}:00';
          }
          return '';
        }
      case 'Weekly':
        // Show day name for weekly view (Monday to Friday)
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = days[timestamp.weekday - 1];
        // Only show weekdays for better readability
        if (timestamp.weekday <= 5) {
          return dayName;
        }
        return '';
      case 'Monthly':
        // Show week number with proper week calculation
        final firstDayOfMonth = DateTime(timestamp.year, timestamp.month, 1);
        final firstMonday = firstDayOfMonth.add(
          Duration(days: (8 - firstDayOfMonth.weekday) % 7),
        );
        final weekNumber =
            ((timestamp.difference(firstMonday).inDays) / 7).floor() + 1;

        if (weekNumber >= 1 && weekNumber <= 4) {
          return 'W$weekNumber';
        }
        return '';
      default:
        return '${timestamp.day}/${timestamp.month}';
    }
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
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          const SizedBox(width: 40),
          _buildNavItem(
            index: 1,
            imagePath: 'assets/images/add_icon.png',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewBasketScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 40),
          _buildNavItem(
            index: 2,
            imagePath: 'assets/images/statistics_icon.png',
            onTap: () {
              // Already on statistics screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          imagePath,
          width: 32,
          height: 32,
          color: isSelected ? AppColors.primary : AppColors.neutral,
        ),
      ),
    );
  }

  Widget _buildWateringScheduleSection() {
    // Get current watering schedule with real-time status
    final wateringSchedule = _getCurrentWateringSchedule();

    final nextWatering = wateringSchedule.firstWhere(
      (item) => item['completed'] == 'false',
      orElse: () => {'time': 'No more watering today', 'status': 'Completed'},
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/mdi_watering-can.png',
                width: 24,
                height: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Watering Schedule',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...wateringSchedule
              .map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildScheduleRow(
                    'Today',
                    schedule['time']!,
                    schedule['status']!,
                    schedule['completed'] == 'true',
                  ),
                ),
              )
              .toList(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next watering: ${nextWatering['time']}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watering Schedule Info:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Always water at 8:00 AM\n• Second watering at 10:00 AM (hot/dry conditions) or 12:00 PM (normal conditions)\n• Schedule adjusts based on temperature and humidity',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
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

  Widget _buildFertilizingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fertilizing Schedule\n& Status',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showFertilizingDetailsDialog(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFertilizerCard(
                  'A+B Fertilizer\n(Drenching)',
                  _getFertilizingStatus('Tuesday'),
                  AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFertilizerCard(
                  'Foliar Spray',
                  _getFertilizingStatus('Tuesday'),
                  AppColors.peach,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleRow(
            'This Week',
            'Seaweed Extract',
            _isFertilizingDayPassed('Tuesday') ? 'Completed' : 'Due Tue',
            _isFertilizingDayPassed('Tuesday'),
          ),
          const SizedBox(height: 8),
          _buildScheduleRow(
            'This Week',
            'Fish Amino Acid',
            _isFertilizingDayPassed('Tuesday') ? 'Completed' : 'Due Tue',
            _isFertilizingDayPassed('Tuesday'),
          ),
          const SizedBox(height: 8),
          _buildScheduleRow(
            'This Week',
            'Trichoderma',
            _isFertilizingDayPassed('Tuesday') ? 'Completed' : 'Due Tue',
            _isFertilizingDayPassed('Tuesday'),
          ),
          const SizedBox(height: 8),
          _buildScheduleRow(
            'This Week',
            'Fulvic Acid',
            _isFertilizingDayPassed('Tuesday') ? 'Completed' : 'Due Tue',
            _isFertilizingDayPassed('Tuesday'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Schedule:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Tuesday: Complete fertilizer program + foliar spray\n• Thursday: Additional fertilization\n• Saturday: Additional fertilization\n• EC Target: 1.75',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
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

  Widget _buildPesticideTrappingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Pesticide Trapping & Control',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTrapCard(
                  'Yellow Sticky Traps',
                  'Active',
                  '12 traps deployed',
                  Colors.yellow.shade600,
                  AppColors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrapCard(
                  'Blue Sticky Traps',
                  'Active',
                  '12 traps deployed',
                  Colors.blue.shade600,
                  AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildTrapStatusRow('Deployment:', 'Since transplanting'),
                const SizedBox(height: 4),
                _buildTrapStatusRow('Removal:', 'After harvesting'),
                const SizedBox(height: 4),
                _buildTrapStatusRow('Total Baskets:', '6 baskets'),
                const SizedBox(height: 4),
                _buildTrapStatusRow('Traps per Basket:', '2 traps each'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pest Control Program:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Blue & Yellow sticky traps deployed (2 per basket, 12 total)\n• Traps deployed since transplanting, removed after harvesting\n• Thrips damage observation: Monitor plant leaves for shrinking\n• Whitefly damage observation: Monitor for leaf yellowing, honeydew excretion, leaf wilting/drop, stunted growth, and white insects on leaf undersides\n• Abamectin applied when necessary\n• Organic pesticide programs\n• Organic fungicide programs\n• Visual inspection through leaf condition monitoring',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
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

  Widget _buildScheduleRow(
    String period,
    String task,
    String status,
    bool isCompleted,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isCompleted ? Colors.green : AppColors.neutral.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: isCompleted ? Colors.green : AppColors.neutral,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$period - $task',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    color: isCompleted ? Colors.green : AppColors.neutral,
                    fontSize: 11,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFertilizerCard(
    String name,
    String status,
    Color backgroundColor,
  ) {
    return Container(
      height: 90, // Increased height to prevent overflow
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrapCard(
    String name,
    String status,
    String count,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      backgroundColor == Colors.yellow.shade600
                          ? Colors.yellow
                          : Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 12,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 11,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrapStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlantSubstrateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brown.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brown, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Plant Substrate Composition',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Substrate Mix Components:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSubstrateRow('Chicken Dung', 'Organic fertilizer base'),
                _buildSubstrateRow('Rice Husk', '≈80% (aeration & drainage)'),
                _buildSubstrateRow('Burnt Ashes', 'pH adjustment & nutrients'),
                _buildSubstrateRow('CaCO₃ (Calcium Carbonate)', 'pH buffering'),
                _buildSubstrateRow('RS555', 'Specialized nutrient mix'),
                _buildSubstrateRow(
                  'Effective Microorganisms (EM)',
                  'Beneficial microbes',
                ),
                _buildSubstrateRow(
                  'Beneficial Microbes/Fungicides',
                  'Disease prevention',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Specifications:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Electrical Conductivity (EC): ~1.2 mS/cm\n• Optimal pH range: 6.0-6.8\n• Rice husk to other components ratio: ~80:20\n• Balanced nutrient availability\n• Enhanced water retention and drainage',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
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

  Widget _buildSubstrateRow(String component, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: AppColors.brown,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.7),
                    fontSize: 11,
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

  void _showFertilizingDetailsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.eco, color: AppColors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fertilizing Program\nComplete SOP',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontFamily: "Poppins",
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Weekly Schedule
                        _buildDialogSection(
                          'Weekly Schedule',
                          Icons.calendar_today,
                          [
                            'Tuesday: Complete fertilizer program + foliar spray',
                            'Thursday: Additional fertilization',
                            'Saturday: Additional fertilization',
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Tuesday Program
                        _buildDialogSection(
                          'Tuesday - Complete Program',
                          Icons.science,
                          [
                            'Fertilizer A: 1ml/L (mix with water first)',
                            'Fertilizer B: 1ml/L',
                            'Seaweed: 2ml/L',
                            'Powerfeed Fish Amino Acid: 2ml/L',
                            'Trichoderma: 2g/L',
                            'Fulvic Acid: 3g/L',
                            'Target EC: 1.75',
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Thursday Program
                        _buildDialogSection(
                          'Thursday - Additional Fertilization',
                          Icons.science,
                          [
                            'Fertilizer A: 1ml/L (mix with water first)',
                            'Fertilizer B: 1ml/L',
                            'Seaweed: 2ml/L',
                            'Powerfeed Fish Amino Acid: 2ml/L',
                            'Target EC: 1.75',
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Saturday Program
                        _buildDialogSection(
                          'Saturday - Additional Fertilization',
                          Icons.science,
                          [
                            'Fertilizer A: 1ml/L (mix with water first)',
                            'Fertilizer B: 1ml/L',
                            'Seaweed: 2ml/L',
                            'Powerfeed Fish Amino Acid: 2ml/L',
                            'Target EC: 2.0',
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Preparation Steps
                        _buildDialogSection('Preparation Steps', Icons.build, [
                          'Use 200L Blue Tank for mixing',
                          'Take EC test - target EC 1.75 (or 2.0 for Saturday)',
                          'If 1ml/L of A & B not enough, add more fertilizer A + B',
                          'Test EC again to ensure target EC before applying',
                          'Apply to planting media after EC confirmation',
                        ]),
                        const SizedBox(height: 20),

                        // Foliar Spray
                        _buildDialogSection(
                          'Foliar Spray (Tuesday)',
                          Icons.water_drop,
                          [
                            'Abamectin: 1ml/L',
                            'MR. Ganick: 5ml/L',
                            'Powerfeed: 2ml/L',
                            'Seaweed: 2ml/L',
                            'Trichoderma: 2g/L',
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Important Notes
                        _buildDialogSection('Important Notes', Icons.warning, [
                          'Always mix fertilizer A with water first',
                          'EC testing is mandatory before application',
                          'Consistent EC targets across all rows',
                          'Use only 200L Blue Tank for consistency',
                          'Apply immediately after preparation',
                        ]),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Follow this SOP exactly for optimal plant nutrition and growth',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontFamily: "Poppins",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogSection(String title, IconData icon, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 8, right: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontFamily: "Poppins",
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}
