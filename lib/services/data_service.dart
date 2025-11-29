// services/data_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../models/sensor_data.dart';

class DataService {
  static List<SensorData>? _cachedData;
  static Map<String, List<SensorData>> _filteredDataCache = {};
  static Map<String, Map<String, double>> _averagesCache = {};
  static Map<String, List<Map<String, dynamic>>> _chartDataCache = {};

  // Clear cached data to free memory
  static void clearCache() {
    _cachedData = null;
    _filteredDataCache.clear();
    _averagesCache.clear();
    _chartDataCache.clear();
    developer.log('All caches cleared to free memory');
  }

  static Future<List<SensorData>> loadSensorData() async {
    if (_cachedData != null) {
      developer.log('Returning cached data: ${_cachedData!.length} items');
      return _cachedData!;
    }

    try {
      developer.log('Loading sensor data from JSON file...');
      final String jsonString = await rootBundle.loadString(
        'muskmelon_historical_cleaned_wide_clean.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      developer.log('Parsed JSON: ${jsonList.length} items');

      // Load full dataset for proper data analysis
      developer.log('Loading full dataset: ${jsonList.length} items');

      _cachedData = jsonList.map((json) => SensorData.fromJson(json)).toList();
      developer.log('Created SensorData objects: ${_cachedData!.length} items');

      if (_cachedData!.isNotEmpty) {
        developer.log('First data point: ${_cachedData!.first}');
        developer.log('Last data point: ${_cachedData!.last}');
      }

      return _cachedData!;
    } catch (e) {
      developer.log('Error loading sensor data: $e');
      return [];
    }
  }

  // Load sensor data with lazy loading for better performance
  static Future<List<SensorData>> loadSensorDataLazy() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    // Load data in background without blocking UI
    return loadSensorData();
  }

  // Get a subset of data for quick loading
  static Future<List<SensorData>> loadRecentSensorData({
    int limit = 100,
  }) async {
    try {
      if (_cachedData != null) {
        // Return recent data from cache
        final sortedData = List<SensorData>.from(_cachedData!)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return sortedData.take(limit).toList();
      }

      // Load from JSON and return recent data
      final allData = await loadSensorData();
      final sortedData = List<SensorData>.from(allData)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sortedData.take(limit).toList();
    } catch (e) {
      developer.log('Error loading recent sensor data: $e');
      return [];
    }
  }

  static List<SensorData> filterDataByPeriod(
    List<SensorData> data,
    String period, {
    String? selectedWeek,
    String? selectedMonth,
  }) {
    if (data.isEmpty) return data;

    // Create cache key
    final cacheKey = '${period}_${selectedWeek ?? ''}_${selectedMonth ?? ''}';

    // Return cached data if available
    if (_filteredDataCache.containsKey(cacheKey)) {
      developer.log('Using cached filtered data for $cacheKey');
      return _filteredDataCache[cacheKey]!;
    }

    // Get the date range from the actual data
    final sortedData = List<SensorData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final firstDate = sortedData.first.timestamp;
    final lastDate = sortedData.last.timestamp;

    developer.log('Data range: ${firstDate} to ${lastDate}');
    developer.log('Total data points: ${data.length}');

    List<SensorData> result;
    switch (period) {
      case 'Today':
        // Show data from September 1-4, 2025 (current up-to-date data range)
        final startDate = DateTime(2025, 9, 1);
        final endDate = DateTime(2025, 9, 4, 23, 59, 59);
        result =
            data
                .where(
                  (item) =>
                      item.timestamp.isAfter(
                        startDate.subtract(const Duration(hours: 1)),
                      ) &&
                      item.timestamp.isBefore(
                        endDate.add(const Duration(hours: 1)),
                      ),
                )
                .toList();

      case 'Weekly':
        // Get specific week data based on selection
        if (selectedWeek != null && !selectedWeek.startsWith('This Week')) {
          // Parse the selected week from the dropdown
          // Format: "Week 7/7 - 12/7" or "This Week (7/7 - 12/7)"
          String weekString = selectedWeek;
          if (weekString.startsWith('This Week (')) {
            weekString = weekString.substring(
              12,
              weekString.length - 1,
            ); // Remove "This Week (" and ")"
          } else if (weekString.startsWith('Week ')) {
            weekString = weekString.substring(5); // Remove "Week "
          }

          final weekParts = weekString.split(' - ');
          if (weekParts.length == 2) {
            final startParts = weekParts[0].split('/');
            final endParts = weekParts[1].split('/');
            if (startParts.length == 2 && endParts.length == 2) {
              // Use the year from the actual data (2025)
              final weekStart = DateTime(
                2025, // Use 2025 as the data is from 2025
                int.parse(startParts[1]),
                int.parse(startParts[0]),
              );
              final weekEnd = DateTime(
                2025, // Use 2025 as the data is from 2025
                int.parse(endParts[1]),
                int.parse(endParts[0]),
              );
              result =
                  data
                      .where(
                        (item) =>
                            item.timestamp.isAfter(
                              weekStart.subtract(const Duration(hours: 1)),
                            ) &&
                            item.timestamp.isBefore(
                              weekEnd.add(const Duration(days: 1)),
                            ),
                      )
                      .toList();
            }
          }
        }
        // Default to last 7 days from actual data
        final weekEnd = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final weekStart = weekEnd.subtract(const Duration(days: 7));
        result =
            data
                .where(
                  (item) =>
                      item.timestamp.isAfter(
                        weekStart.subtract(const Duration(hours: 1)),
                      ) &&
                      item.timestamp.isBefore(
                        weekEnd.add(const Duration(days: 1)),
                      ),
                )
                .toList();

      case 'Monthly':
        // Get specific month data based on selection
        if (selectedMonth != null && !selectedMonth.startsWith('This Month')) {
          // Parse the selected month from the dropdown
          final monthParts = selectedMonth.split(' ');
          if (monthParts.length >= 2) {
            final monthName = monthParts[0];
            final year = int.parse(monthParts[1]);
            final monthNumber = _getMonthNumber(monthName);
            if (monthNumber != null) {
              final monthStart = DateTime(year, monthNumber, 1);
              final monthEnd = DateTime(year, monthNumber + 1, 0);
              result =
                  data
                      .where(
                        (item) =>
                            item.timestamp.isAfter(
                              monthStart.subtract(const Duration(hours: 1)),
                            ) &&
                            item.timestamp.isBefore(
                              monthEnd.add(const Duration(days: 1)),
                            ),
                      )
                      .toList();
            }
          }
        }
        // Default to last 30 days from actual data
        final monthEnd = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final monthStart = monthEnd.subtract(const Duration(days: 30));
        result =
            data
                .where(
                  (item) =>
                      item.timestamp.isAfter(
                        monthStart.subtract(const Duration(hours: 1)),
                      ) &&
                      item.timestamp.isBefore(
                        monthEnd.add(const Duration(days: 1)),
                      ),
                )
                .toList();

      default:
        result = data;
    }

    // Cache the filtered result
    _filteredDataCache[cacheKey] = result;
    developer.log('Cached filtered data for $cacheKey: ${result.length} items');
    return result;
  }

  static int? _getMonthNumber(String monthName) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    return months[monthName];
  }

  static Map<String, double> calculateAverages(List<SensorData> data) {
    if (data.isEmpty) {
      return {
        'temperature': 0.0,
        'humidity': 0.0,
        'soilMoisture': 0.0,
        'soilPH': 0.0,
        'soilEC': 0.0,
        'lightIntensity': 0.0,
      };
    }

    // Create cache key based on data length and first/last timestamps
    final cacheKey =
        '${data.length}_${data.first.timestamp.millisecondsSinceEpoch}_${data.last.timestamp.millisecondsSinceEpoch}';

    // Return cached averages if available
    if (_averagesCache.containsKey(cacheKey)) {
      developer.log('Using cached averages for $cacheKey');
      return _averagesCache[cacheKey]!;
    }

    double tempSum = 0;
    double humiditySum = 0;
    double soilMoistureSum = 0;
    double soilPHSum = 0;
    double soilECSum = 0;
    double lightSum = 0;

    for (var item in data) {
      tempSum += item.temperature;
      humiditySum += item.humidity;
      soilMoistureSum += item.soilMoisture;
      soilPHSum += item.soilPH;
      soilECSum += item.soilEC;
      lightSum += item.lightIntensity;
    }

    final count = data.length.toDouble();

    final result = {
      'temperature': double.parse((tempSum / count).toStringAsFixed(2)),
      'humidity': double.parse((humiditySum / count).toStringAsFixed(2)),
      'soilMoisture': double.parse(
        (soilMoistureSum / count).toStringAsFixed(2),
      ),
      'soilPH': double.parse((soilPHSum / count).toStringAsFixed(2)),
      'soilEC': double.parse((soilECSum / count).toStringAsFixed(2)),
      'lightIntensity': double.parse((lightSum / count).toStringAsFixed(2)),
    };

    // Cache the calculated averages
    _averagesCache[cacheKey] = result;
    developer.log('Cached averages for $cacheKey');
    return result;
  }

  static List<Map<String, dynamic>> prepareChartData(
    List<SensorData> data,
    String parameter,
    String period,
  ) {
    if (data.isEmpty) return [];

    // Create cache key
    final cacheKey =
        '${parameter}_${period}_${data.length}_${data.first.timestamp.millisecondsSinceEpoch}_${data.last.timestamp.millisecondsSinceEpoch}';

    // Return cached chart data if available
    if (_chartDataCache.containsKey(cacheKey)) {
      developer.log('Using cached chart data for $cacheKey');
      return _chartDataCache[cacheKey]!;
    }

    // Sort data by timestamp
    final sortedData = List<SensorData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Process data based on period with appropriate aggregation and limits
    List<SensorData> processedData;
    switch (period) {
      case 'Today':
        // For today (Sept 1-4), show data every 4 hours for better performance
        processedData =
            _aggregateHourlyData(sortedData, interval: 4).take(12).toList();
        break;
      case 'Weekly':
        // For weekly, show daily data (max 7 days)
        processedData = _aggregateDailyData(sortedData).take(7).toList();
        break;
      case 'Monthly':
        // For monthly, show weekly data (max 4 weeks)
        processedData = _aggregateWeeklyData(sortedData).take(4).toList();
        break;
      default:
        processedData = sortedData.take(15).toList();
    }

    final result =
        processedData.map((item) {
          double value;
          switch (parameter) {
            case 'Temperature':
              value = item.temperature;
              break;
            case 'Humidity':
              value = item.humidity;
              break;
            case 'Soil Moisture':
              value = item.soilMoisture;
              break;
            case 'Soil pH':
              value = item.soilPH;
              break;
            case 'Soil EC':
              value = item.soilEC;
              break;
            case 'Light Intensity':
              value = item.lightIntensity;
              break;
            default:
              value = 0.0;
          }

          return {
            'x': item.timestamp.millisecondsSinceEpoch.toDouble(),
            'y': value,
            'timestamp': item.timestamp,
          };
        }).toList();

    // Cache the chart data
    _chartDataCache[cacheKey] = result;
    developer.log('Cached chart data for $cacheKey: ${result.length} points');
    return result;
  }

  // Aggregate data by hour for today view
  static List<SensorData> _aggregateHourlyData(
    List<SensorData> data, {
    int interval = 1,
  }) {
    if (data.isEmpty) return [];

    final Map<String, List<SensorData>> hourlyGroups = {};

    for (final item in data) {
      // Group by hour with interval support
      final hour = (item.timestamp.hour / interval).floor() * interval;
      final hourKey =
          '${item.timestamp.year}-${item.timestamp.month}-${item.timestamp.day}-$hour';
      hourlyGroups[hourKey] ??= [];
      hourlyGroups[hourKey]!.add(item);
    }

    return hourlyGroups.values.map((hourData) {
        final avgTemp = double.parse(
          (hourData.map((e) => e.temperature).reduce((a, b) => a + b) /
                  hourData.length)
              .toStringAsFixed(2),
        );
        final avgHumidity = double.parse(
          (hourData.map((e) => e.humidity).reduce((a, b) => a + b) /
                  hourData.length)
              .toStringAsFixed(2),
        );
        final avgSoilMoisture = double.parse(
          (hourData.map((e) => e.soilMoisture).reduce((a, b) => a + b) /
                  hourData.length)
              .toStringAsFixed(2),
        );
        final avgSoilPH = double.parse(
          (hourData.map((e) => e.soilPH).reduce((a, b) => a + b) /
                  hourData.length)
              .toStringAsFixed(2),
        );
        final avgSoilEC = double.parse(
          (hourData.map((e) => e.soilEC).reduce((a, b) => a + b) /
                  hourData.length)
              .toStringAsFixed(2),
        );
        final avgLight = double.parse(
          (hourData.map((e) => e.lightIntensity).reduce((a, b) => a + b) /
                  hourData.length)
              .toStringAsFixed(2),
        );

        return SensorData(
          timestamp: hourData.first.timestamp,
          temperature: avgTemp,
          humidity: avgHumidity,
          soilMoisture: avgSoilMoisture,
          soilPH: avgSoilPH,
          soilEC: avgSoilEC,
          lightIntensity: avgLight,
          basketId: hourData.first.basketId,
        );
      }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Aggregate data by day for weekly view
  static List<SensorData> _aggregateDailyData(List<SensorData> data) {
    if (data.isEmpty) return [];

    final Map<String, List<SensorData>> dailyGroups = {};

    for (final item in data) {
      final dayKey =
          '${item.timestamp.year}-${item.timestamp.month}-${item.timestamp.day}';
      dailyGroups[dayKey] ??= [];
      dailyGroups[dayKey]!.add(item);
    }

    return dailyGroups.values.map((dayData) {
        final avgTemp = double.parse(
          (dayData.map((e) => e.temperature).reduce((a, b) => a + b) /
                  dayData.length)
              .toStringAsFixed(2),
        );
        final avgHumidity = double.parse(
          (dayData.map((e) => e.humidity).reduce((a, b) => a + b) /
                  dayData.length)
              .toStringAsFixed(2),
        );
        final avgSoilMoisture = double.parse(
          (dayData.map((e) => e.soilMoisture).reduce((a, b) => a + b) /
                  dayData.length)
              .toStringAsFixed(2),
        );
        final avgSoilPH = double.parse(
          (dayData.map((e) => e.soilPH).reduce((a, b) => a + b) /
                  dayData.length)
              .toStringAsFixed(2),
        );
        final avgSoilEC = double.parse(
          (dayData.map((e) => e.soilEC).reduce((a, b) => a + b) /
                  dayData.length)
              .toStringAsFixed(2),
        );
        final avgLight = double.parse(
          (dayData.map((e) => e.lightIntensity).reduce((a, b) => a + b) /
                  dayData.length)
              .toStringAsFixed(2),
        );

        return SensorData(
          timestamp: dayData.first.timestamp,
          temperature: avgTemp,
          humidity: avgHumidity,
          soilMoisture: avgSoilMoisture,
          soilPH: avgSoilPH,
          soilEC: avgSoilEC,
          lightIntensity: avgLight,
          basketId: dayData.first.basketId,
        );
      }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Aggregate data by week for monthly view
  static List<SensorData> _aggregateWeeklyData(List<SensorData> data) {
    if (data.isEmpty) return [];

    final Map<String, List<SensorData>> weeklyGroups = {};

    for (final item in data) {
      final weekNumber = ((item.timestamp.day - 1) / 7).floor() + 1;
      final weekKey =
          '${item.timestamp.year}-${item.timestamp.month}-Week$weekNumber';
      weeklyGroups[weekKey] ??= [];
      weeklyGroups[weekKey]!.add(item);
    }

    return weeklyGroups.values.map((weekData) {
        final avgTemp = double.parse(
          (weekData.map((e) => e.temperature).reduce((a, b) => a + b) /
                  weekData.length)
              .toStringAsFixed(2),
        );
        final avgHumidity = double.parse(
          (weekData.map((e) => e.humidity).reduce((a, b) => a + b) /
                  weekData.length)
              .toStringAsFixed(2),
        );
        final avgSoilMoisture = double.parse(
          (weekData.map((e) => e.soilMoisture).reduce((a, b) => a + b) /
                  weekData.length)
              .toStringAsFixed(2),
        );
        final avgSoilPH = double.parse(
          (weekData.map((e) => e.soilPH).reduce((a, b) => a + b) /
                  weekData.length)
              .toStringAsFixed(2),
        );
        final avgSoilEC = double.parse(
          (weekData.map((e) => e.soilEC).reduce((a, b) => a + b) /
                  weekData.length)
              .toStringAsFixed(2),
        );
        final avgLight = double.parse(
          (weekData.map((e) => e.lightIntensity).reduce((a, b) => a + b) /
                  weekData.length)
              .toStringAsFixed(2),
        );

        return SensorData(
          timestamp: weekData.first.timestamp,
          temperature: avgTemp,
          humidity: avgHumidity,
          soilMoisture: avgSoilMoisture,
          soilPH: avgSoilPH,
          soilEC: avgSoilEC,
          lightIntensity: avgLight,
          basketId: weekData.first.basketId,
        );
      }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static String formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}';
  }

  // Method to determine watering schedule based on weather conditions
  static List<Map<String, String>> getWateringSchedule(
    List<SensorData> todayData,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get today's data
    final todaySensorData =
        todayData
            .where(
              (item) =>
                  item.timestamp.isAfter(today) &&
                  item.timestamp.isBefore(today.add(const Duration(days: 1))),
            )
            .toList();

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
    String secondWateringTime;
    if (todaySensorData.isNotEmpty) {
      // Calculate average temperature and humidity for the day
      final avgTemp =
          todaySensorData.map((e) => e.temperature).reduce((a, b) => a + b) /
          todaySensorData.length;
      final avgHumidity =
          todaySensorData.map((e) => e.humidity).reduce((a, b) => a + b) /
          todaySensorData.length;

      if (avgTemp > 30 || avgHumidity < 60) {
        // Hot and dry conditions - water at 10 AM
        secondWateringTime = '10:00 AM';
      } else {
        // Normal conditions - water at 12 PM
        secondWateringTime = '12:00 PM';
      }
    } else {
      // Default to 10 AM if no data available
      secondWateringTime = '10:00 AM';
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
}
