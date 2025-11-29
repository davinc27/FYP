import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/sensor_data.dart';
import '../models/basket.dart';
import 'fcm_service.dart';
import 'email_service.dart';

class FirebaseService {
  static FirebaseDatabase? _firebaseDatabase;
  static DatabaseReference? _database;

  // Initialize Firebase with explicit database URL
  static void initializeFirebase() {
    if (_database != null) {
      developer.log('Firebase Service already initialized');
      return;
    }

    try {
      _firebaseDatabase = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://terra-iot-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      _database = _firebaseDatabase!.ref();
      developer.log(
        'Firebase Service initialized with URL: ${_firebaseDatabase!.databaseURL}',
      );
    } catch (e) {
      developer.log('Error initializing Firebase Service: $e');
    }
  }

  // Initialize Firebase, FCM, and Email Service
  static Future<void> initializeFirebaseAndFCM() async {
    initializeFirebase();
    await FCMService.initialize();
    // Initialize email service asynchronously to avoid blocking startup
    EmailService.initialize().catchError((e) {
      developer.log('Email service initialization error: $e');
    });
  }

  // Getter to ensure Firebase is initialized
  static DatabaseReference get _db {
    if (_database == null) {
      developer.log('Firebase not initialized, initializing now...');
      initializeFirebase();
    }
    return _database!;
  }

  // Collection references - matching your actual Firebase structure
  static DatabaseReference get baskets => _db.child('baskets');
  static DatabaseReference get sensorData => _db.child('sensorData');
  static DatabaseReference get systemStatus => _db.child('systemStatus');
  static DatabaseReference get notifications => _db.child('notifications');
  static DatabaseReference get userSettings => _db.child('userSettings');

  // Test Firebase connectivity
  static Future<bool> testConnection() async {
    try {
      developer.log('Testing Firebase connection...');
      developer.log(
        'Database URL: ${_firebaseDatabase?.databaseURL ?? 'Not initialized'}',
      );

      // Test basic connection with a more reliable method
      try {
        // Use a simple write/read test instead of relying on specific data paths
        String testKey =
            'connection_test_${DateTime.now().millisecondsSinceEpoch}';
        String testValue = 'test_${DateTime.now().millisecondsSinceEpoch}';

        // Write test data
        await _db
            .child('test')
            .child(testKey)
            .set(testValue)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw TimeoutException('Write timeout');
              },
            );

        // Read test data
        DatabaseEvent event = await _db
            .child('test')
            .child(testKey)
            .once()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw TimeoutException('Read timeout');
              },
            );

        // Clean up test data
        await _db.child('test').child(testKey).remove();

        if (event.snapshot.value == testValue) {
          developer.log('Firebase connection test successful');
          return true;
        } else {
          developer.log('Firebase connection test failed: data mismatch');
          return false;
        }
      } catch (e) {
        developer.log('Firebase connection test failed: $e');
        return false;
      }
    } catch (e) {
      developer.log('Firebase connection test failed: $e');
      developer.log('Error details: ${e.toString()}');
      return false;
    }
  }

  // Fallback connection test that doesn't require specific data paths
  static Future<bool> testConnectionFallback() async {
    try {
      developer.log('Testing Firebase connection (fallback method)...');

      // Simple connection test using .info/connected
      await _db
          .child('.info/connected')
          .once()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException('Connection timeout');
            },
          );

      developer.log('Firebase fallback connection test successful');
      return true;
    } catch (e) {
      developer.log('Firebase fallback connection test failed: $e');
      return false;
    }
  }

  // ============ BASKET OPERATIONS ============

  // Create new basket with proper ID mapping
  static Future<String> createBasket(Basket basket) async {
    try {
      developer.log('Creating basket: ${basket.name}');

      // Determine the next available basket ID
      String basketId = await _getNextBasketId();

      // Create basket data
      Map<String, dynamic> basketData = {
        'name': basket.name,
        'plantingDate': basket.plantingDate.millisecondsSinceEpoch,
        'growthStage': basket.growthStage,
        'wateringMode': basket.wateringMode,
        'locationTag': basket.locationTag,
        'notes': basket.notes,
        'imageUrl': basket.imageUrl,
        'basketKey':
            basketId, // Store the actual sensor data key (basket1, basket2, etc.)
        'createdAt': ServerValue.timestamp,
      };

      developer.log('Basket data to save: $basketData');

      // Save to baskets collection with a generated key
      DatabaseReference newBasketRef = baskets.push();
      await newBasketRef.set(basketData);

      String generatedId = newBasketRef.key ?? '';
      developer.log(
        'Basket created successfully with ID: $generatedId, mapped to sensor: $basketId',
      );

      return generatedId;
    } catch (e) {
      developer.log('Error creating basket: $e');
      rethrow;
    }
  }

  // Get the next available basket ID (basket1, basket2, etc.)
  static Future<String> _getNextBasketId() async {
    try {
      // Check which basket IDs are already in use
      DatabaseEvent event = await baskets.once();
      Set<String> usedBasketKeys = {};

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value != null && value['basketKey'] != null) {
            usedBasketKeys.add(value['basketKey']);
          }
        });
      }

      // Find the first available basket ID (basket1 through basket6)
      for (int i = 1; i <= 6; i++) {
        String basketKey = 'basket$i';
        if (!usedBasketKeys.contains(basketKey)) {
          return basketKey;
        }
      }

      // If all baskets are used, return basket1 as fallback
      return 'basket1';
    } catch (e) {
      developer.log('Error getting next basket ID: $e');
      return 'basket1';
    }
  }

  // Get all baskets with proper sensor data mapping
  static Stream<List<Basket>> getBasketsStream() {
    return baskets.onValue
        .map((event) {
          List<Basket> basketList = [];
          try {
            developer.log(
              'Firebase baskets stream - snapshot exists: ${event.snapshot.exists}',
            );
            developer.log(
              'Firebase baskets stream - raw value: ${event.snapshot.value}',
            );

            if (event.snapshot.value != null) {
              Map<dynamic, dynamic> data =
                  event.snapshot.value as Map<dynamic, dynamic>;

              data.forEach((key, value) {
                if (value != null) {
                  try {
                    developer.log('Processing basket data: $key -> $value');
                    basketList.add(
                      Basket(
                        id:
                            value['basketKey'] ??
                            key.toString(), // Use basketKey for sensor mapping
                        name: value['name'] ?? 'Unnamed Basket',
                        plantingDate: DateTime.fromMillisecondsSinceEpoch(
                          value['plantingDate'] ??
                              DateTime.now().millisecondsSinceEpoch,
                        ),
                        growthStage: value['growthStage'] ?? 'Seedling Stage',
                        wateringMode: value['wateringMode'] ?? 'Semi-Automatic',
                        locationTag: value['locationTag'] ?? '',
                        notes: value['notes'],
                        imageUrl: value['imageUrl'],
                      ),
                    );
                  } catch (e) {
                    developer.log(
                      'Error creating basket from data: $e, data: $value',
                    );
                  }
                }
              });
            } else {
              developer.log('No baskets data found in Firebase');
            }

            basketList.sort((a, b) => a.name.compareTo(b.name));
            developer.log(
              'Firebase baskets stream - returning ${basketList.length} baskets',
            );
            return basketList;
          } catch (e) {
            developer.log('Error in getBasketsStream: $e');
            return <Basket>[];
          }
        })
        .handleError((error) {
          developer.log('Firebase baskets stream error: $error');
          return <Basket>[];
        });
  }

  // Get single basket
  static Future<Basket?> getBasket(String basketId) async {
    try {
      // First try to find by basketKey
      DatabaseEvent event =
          await baskets.orderByChild('basketKey').equalTo(basketId).once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> allData =
            event.snapshot.value as Map<dynamic, dynamic>;
        // Get the first matching basket
        var firstKey = allData.keys.first;
        Map<dynamic, dynamic> data = allData[firstKey];

        return Basket(
          id: basketId,
          name: data['name'] ?? 'Unnamed Basket',
          plantingDate: DateTime.fromMillisecondsSinceEpoch(
            data['plantingDate'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          growthStage: data['growthStage'] ?? 'Seedling Stage',
          wateringMode: data['wateringMode'] ?? 'Semi-Automatic',
          locationTag: data['locationTag'] ?? '',
          notes: data['notes'],
          imageUrl: data['imageUrl'],
        );
      }
      return null;
    } catch (e) {
      developer.log('Error getting basket: $e');
      return null;
    }
  }

  // Update basket
  static Future<void> updateBasket(
    String basketId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Find the basket by basketKey and update it
      DatabaseEvent event =
          await baskets.orderByChild('basketKey').equalTo(basketId).once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> allData =
            event.snapshot.value as Map<dynamic, dynamic>;
        var firstKey = allData.keys.first;
        await baskets.child(firstKey).update(data);
      }
    } catch (e) {
      developer.log('Error updating basket: $e');
      rethrow;
    }
  }

  // Delete basket with image cleanup
  static Future<void> deleteBasket(String basketId) async {
    try {
      // Find the basket by basketKey
      DatabaseEvent event =
          await baskets.orderByChild('basketKey').equalTo(basketId).once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> allData =
            event.snapshot.value as Map<dynamic, dynamic>;
        var firstKey = allData.keys.first;
        Map<dynamic, dynamic> data = allData[firstKey];

        // Delete the image from Storage if it exists
        String? imageUrl = data['imageUrl'];
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await deleteBasketImage(imageUrl);
        }

        // Delete the basket from Database
        await baskets.child(firstKey).remove();
      }
    } catch (e) {
      developer.log('Error deleting basket: $e');
      rethrow;
    }
  }

  // ============ IMAGE OPERATIONS (Using Realtime Database - FREE) ============

  // Convert image to Base64 and compress it for Realtime Database storage
  static Future<String?> uploadBasketImage(
    File imageFile,
    String basketId,
  ) async {
    try {
      developer.log('Converting image to Base64 for basket: $basketId');

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Check file size (limit to 300KB for efficient storage)
      if (bytes.length > 300000) {
        // If image is too large, compress it
        // You can use image package or just reduce quality
        developer.log('Image size: ${bytes.length} bytes - needs compression');

        // For now, we'll just use the image as-is
        // In production, you'd want to compress it using the image package
      }

      // Convert to base64
      final base64String = base64Encode(bytes);
      developer.log(
        'Image converted to Base64, size: ${base64String.length} characters',
      );

      // Store in Realtime Database instead of Storage
      // We'll return a special marker that indicates this is base64 data
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      developer.log('Error converting image: $e');
      return null;
    }
  }

  // Delete basket image (for base64, we just remove it from the database)
  static Future<void> deleteBasketImage(String imageUrl) async {
    try {
      // If it's a base64 image, it will be deleted with the basket
      // No separate deletion needed
      developer.log('Image will be deleted with basket data');
    } catch (e) {
      developer.log('Error in deleteBasketImage: $e');
    }
  }

  // ============ SENSOR DATA OPERATIONS ============

  // Get real-time sensor data stream for a basket (DISABLED to prevent OOM)
  static Stream<SensorData?> getSensorDataStream(String basketId) {
    developer.log('Sensor data stream DISABLED to prevent OutOfMemoryError');
    developer.log(
      'Database URL: ${_firebaseDatabase?.databaseURL ?? 'Not initialized'}',
    );

    // Return empty stream to prevent Firebase sync
    return Stream.value(null);

    // DISABLED: Original Firebase stream code
    /*
    return sensorData
        .child(basketId) // Use basketId directly (basket1, basket2, etc.)
        .child('latest')
        .onValue
        .map((event) {
          try {
            developer.log('Sensor data stream event received for $basketId');
            developer.log('Snapshot exists: ${event.snapshot.exists}');

            if (!event.snapshot.exists || event.snapshot.value == null) {
              developer.log('No data exists for $basketId/latest');
              return null;
            }

            final dynamic raw = event.snapshot.value;
            developer.log('Raw data type: ${raw.runtimeType}');
            developer.log('Raw data: $raw');

            // Handle different data formats
            Map<dynamic, dynamic> data;
            if (raw is Map) {
              data = raw;
            } else {
              developer.log('Data is not a Map, returning null');
              return null;
            }

            // Parse temperature - handle both int and double
            double temperature = 0.0;
            if (data['temperature'] != null) {
              if (data['temperature'] is num) {
                temperature = (data['temperature'] as num).toDouble();
              } else {
                developer.log(
                  'Temperature is not a number: ${data['temperature']}',
                );
              }
            }

            // Parse humidity - handle both int and double
            double humidity = 0.0;
            if (data['humidity'] != null) {
              if (data['humidity'] is num) {
                humidity = (data['humidity'] as num).toDouble();
              } else {
                developer.log('Humidity is not a number: ${data['humidity']}');
              }
            }

            // Parse soil moisture - can be direct value or from moistureDetails
            double avgMoisture = 0.0;
            if (data['soilMoisture'] != null && data['soilMoisture'] is num) {
              avgMoisture = (data['soilMoisture'] as num).toDouble();
            } else if (data['moistureDetails'] != null) {
              Map<dynamic, dynamic> moistureDetails = data['moistureDetails'];
              double total = 0.0;
              int count = 0;
              moistureDetails.forEach((key, value) {
                if (value != null && value is num) {
                  total += value.toDouble();
                  count++;
                }
              });
              if (count > 0) {
                avgMoisture = total / count;
              }
            }

            // Parse timestamp
            DateTime timestamp = DateTime.now();
            if (data['timestamp'] != null) {
              if (data['timestamp'] is int) {
                timestamp = DateTime.fromMillisecondsSinceEpoch(
                  data['timestamp'] as int,
                );
              } else if (data['timestamp'] is String) {
                int? ts = int.tryParse(data['timestamp'].toString());
                if (ts != null) {
                  timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
                }
              } else if (data['timestamp'] is num) {
                timestamp = DateTime.fromMillisecondsSinceEpoch(
                  (data['timestamp'] as num).toInt(),
                );
              }
            }

            developer.log(
              'Parsed data - Temp: $temperature, Humidity: $humidity, Moisture: $avgMoisture',
            );

            return SensorData.fromFirebase(
              temperature: temperature,
              humidity: humidity,
              soilMoisture: avgMoisture,
              soilEC: 0.0, // Not sent by Arduino
              soilPH: 0.0, // Not sent by Arduino
              timestamp: timestamp,
              basketId: basketId,
            );
          } catch (e, stackTrace) {
            developer.log('Error parsing sensor data: $e');
            developer.log('Stack trace: $stackTrace');
            return null;
          }
        })
        .handleError((error) {
          developer.log('Sensor data stream error: $error');
          return null;
        });
    */
  }

  // Cache for latest sensor data to reduce Firebase calls
  static final Map<String, SensorData> _latestSensorDataCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 2);

  // Get latest sensor data once (not stream) with caching
  static Future<SensorData?> getLatestSensorData(String basketId) async {
    try {
      developer.log('🔍 [DEBUG] Starting getLatestSensorData for $basketId');

      // Check if Firebase is initialized
      if (_database == null) {
        developer.log('❌ [DEBUG] Firebase database not initialized!');
        return null;
      }

      developer.log('✅ [DEBUG] Firebase database is initialized');

      // Check cache first
      if (_latestSensorDataCache.containsKey(basketId) &&
          _cacheTimestamps.containsKey(basketId)) {
        final cacheTime = _cacheTimestamps[basketId]!;
        if (DateTime.now().difference(cacheTime) < _cacheValidityDuration) {
          developer.log('✅ [DEBUG] Using cached sensor data for $basketId');
          return _latestSensorDataCache[basketId];
        } else {
          developer.log(
            '⏰ [DEBUG] Cache expired for $basketId, fetching fresh data',
          );
        }
      }

      developer.log(
        '🌐 [DEBUG] Getting latest sensor data for $basketId from Firebase',
      );
      developer.log(
        '🔗 [DEBUG] Database URL: ${_firebaseDatabase?.databaseURL}',
      );
      developer.log('📡 [DEBUG] Attempting to connect to Firebase...');

      // Add timeout to prevent hanging
      DatabaseEvent event = await FirebaseService.sensorData
          .child(basketId)
          .child('latest')
          .once()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              developer.log(
                '⏰ [DEBUG] Firebase timeout after 10 seconds for $basketId',
              );
              throw TimeoutException(
                'Firebase timeout',
                const Duration(seconds: 10),
              );
            },
          );

      developer.log('✅ [DEBUG] Firebase connection successful for $basketId');
      developer.log('📊 [DEBUG] Snapshot exists: ${event.snapshot.exists}');
      developer.log('📊 [DEBUG] Snapshot value: ${event.snapshot.value}');

      if (!event.snapshot.exists || event.snapshot.value == null) {
        developer.log('❌ [DEBUG] No data exists for $basketId/latest');
        return null;
      }

      final dynamic raw = event.snapshot.value;
      developer.log('✅ [DEBUG] Retrieved data: $raw');

      if (raw is! Map) {
        developer.log('❌ [DEBUG] Data is not a Map, type: ${raw.runtimeType}');
        return null;
      }

      Map<dynamic, dynamic> data = raw;
      developer.log('✅ [DEBUG] Data parsed successfully as Map');

      // Parse with safe defaults
      double temperature = 0.0;
      if (data['temperature'] != null && data['temperature'] is num) {
        temperature = (data['temperature'] as num).toDouble();
        developer.log('🌡️ [DEBUG] Temperature: $temperature');
      }

      double humidity = 0.0;
      if (data['humidity'] != null && data['humidity'] is num) {
        humidity = (data['humidity'] as num).toDouble();
        developer.log('💧 [DEBUG] Humidity: $humidity');
      }

      double avgMoisture = 0.0;
      if (data['soilMoisture'] != null && data['soilMoisture'] is num) {
        avgMoisture = (data['soilMoisture'] as num).toDouble();
        developer.log('🌱 [DEBUG] Soil Moisture: $avgMoisture');
      }

      final sensorData = SensorData.fromFirebase(
        temperature: temperature,
        humidity: humidity,
        soilMoisture: avgMoisture,
        soilEC: 0.0,
        soilPH: 0.0,
        timestamp: DateTime.now(),
        basketId: basketId,
      );

      // Cache the result
      _latestSensorDataCache[basketId] = sensorData;
      _cacheTimestamps[basketId] = DateTime.now();
      developer.log('💾 [DEBUG] Data cached for $basketId');

      developer.log(
        '✅ [DEBUG] Successfully retrieved and parsed sensor data for $basketId',
      );
      return sensorData;
    } catch (e) {
      developer.log(
        '❌ [DEBUG] Error getting latest sensor data for $basketId: $e',
      );
      developer.log('❌ [DEBUG] Error type: ${e.runtimeType}');
      if (e.toString().contains('timeout')) {
        developer.log('⏰ [DEBUG] This appears to be a network timeout issue');
      }
      if (e.toString().contains('permission')) {
        developer.log('🔒 [DEBUG] This appears to be a permission issue');
      }
      if (e.toString().contains('network')) {
        developer.log(
          '🌐 [DEBUG] This appears to be a network connectivity issue',
        );
      }
      return null;
    }
  }

  // Get latest sensor data for multiple baskets in parallel
  static Future<Map<String, SensorData?>> getLatestSensorDataForBaskets(
    List<String> basketIds,
  ) async {
    try {
      developer.log(
        'Getting latest sensor data for ${basketIds.length} baskets in parallel',
      );

      // Create futures for all baskets
      final futures = basketIds.map((basketId) async {
        final data = await getLatestSensorData(basketId);
        return MapEntry(basketId, data);
      });

      // Wait for all futures to complete
      final results = await Future.wait(futures);

      // Convert to map
      final Map<String, SensorData?> result = {};
      for (final entry in results) {
        result[entry.key] = entry.value;
      }

      developer.log('Retrieved data for ${results.length} baskets');
      return result;
    } catch (e) {
      developer.log('Error getting latest sensor data for baskets: $e');
      return {};
    }
  }

  // Clear sensor data cache
  static void clearSensorDataCache() {
    _latestSensorDataCache.clear();
    _cacheTimestamps.clear();
    developer.log('Sensor data cache cleared');
  }

  // Test Firebase connectivity
  static Future<bool> testFirebaseConnection() async {
    try {
      developer.log('🧪 [CONNECTIVITY TEST] Testing Firebase connection...');

      if (_database == null) {
        developer.log('❌ [CONNECTIVITY TEST] Firebase not initialized');
        return false;
      }

      developer.log(
        '🔗 [CONNECTIVITY TEST] Database URL: ${_firebaseDatabase?.databaseURL}',
      );

      // Try to read a simple value with timeout
      final testRef = _database!.child('test').child('connection');
      final event = await testRef.once().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          developer.log('⏰ [CONNECTIVITY TEST] Connection timeout');
          throw TimeoutException(
            'Connection test timeout',
            const Duration(seconds: 5),
          );
        },
      );

      developer.log('✅ [CONNECTIVITY TEST] Firebase connection successful');
      developer.log(
        '📊 [CONNECTIVITY TEST] Test data: ${event.snapshot.value}',
      );
      return true;
    } catch (e) {
      developer.log('❌ [CONNECTIVITY TEST] Firebase connection failed: $e');
      developer.log('❌ [CONNECTIVITY TEST] Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Test specific basket data access
  static Future<bool> testBasketDataAccess(String basketId) async {
    try {
      developer.log('🧪 [BASKET TEST] Testing data access for $basketId...');

      final event = await sensorData
          .child(basketId)
          .child('latest')
          .once()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              developer.log('⏰ [BASKET TEST] Timeout accessing $basketId');
              throw TimeoutException(
                'Basket data timeout',
                const Duration(seconds: 5),
              );
            },
          );

      developer.log('✅ [BASKET TEST] Successfully accessed $basketId');
      developer.log('📊 [BASKET TEST] Data exists: ${event.snapshot.exists}');
      developer.log('📊 [BASKET TEST] Data value: ${event.snapshot.value}');
      return true;
    } catch (e) {
      developer.log('❌ [BASKET TEST] Failed to access $basketId: $e');
      return false;
    }
  }

  // Get historical sensor data for charts with pagination and limits
  static Future<List<SensorData>> getHistoricalData(
    String basketId,
    DateTime startDate,
    DateTime endDate, {
    int limit = 100, // Limit to prevent OOM
  }) async {
    try {
      developer.log('Getting historical data for $basketId with limit: $limit');

      // Use query to limit data and order by timestamp
      Query query = sensorData
          .child(basketId)
          .child('history')
          .orderByChild('timestamp')
          .startAt(startDate.millisecondsSinceEpoch)
          .endAt(endDate.millisecondsSinceEpoch)
          .limitToLast(limit); // Limit to last N records

      DatabaseEvent event = await query.once();

      List<SensorData> sensorDataList = [];
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;

        // Process data in batches to prevent memory issues
        int processedCount = 0;
        data.forEach((key, value) {
          if (value != null && processedCount < limit) {
            try {
              // Calculate average moisture from details
              double avgMoisture = 0.0;
              if (value['moistureDetails'] != null) {
                Map<dynamic, dynamic> moistureDetails =
                    value['moistureDetails'];
                double total = 0.0;
                int count = 0;
                moistureDetails.forEach((key, val) {
                  if (val != null && val is num) {
                    total += val.toDouble();
                    count++;
                  }
                });
                if (count > 0) {
                  avgMoisture = total / count;
                }
              } else if (value['soilMoisture'] != null) {
                avgMoisture = (value['soilMoisture'] as num).toDouble();
              }

              SensorData sensorDataItem = SensorData.fromFirebase(
                temperature: ((value['temperature'] ?? 0) as num).toDouble(),
                humidity: ((value['humidity'] ?? 0) as num).toDouble(),
                soilMoisture: avgMoisture,
                soilEC: 0.0,
                soilPH: 0.0,
                timestamp:
                    value['timestamp'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                          value['timestamp'],
                        )
                        : DateTime.now(),
                basketId: basketId,
              );

              sensorDataList.add(sensorDataItem);
              processedCount++;
            } catch (e) {
              developer.log('Error processing historical data item: $e');
            }
          }
        });
      }

      sensorDataList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      developer.log(
        'Retrieved ${sensorDataList.length} historical data points',
      );
      return sensorDataList;
    } catch (e) {
      developer.log('Error getting historical data: $e');
      return [];
    }
  }

  // Get average values for statistics with memory optimization
  static Future<Map<String, double>> getAverageValues(String period) async {
    DateTime now = DateTime.now();
    DateTime startDate;
    int limit;

    switch (period) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        limit = 24; // Max 24 hours of data
        break;
      case 'Weekly':
        startDate = now.subtract(Duration(days: 7));
        limit = 50; // Max 50 data points for week
        break;
      case 'Monthly':
        startDate = now.subtract(Duration(days: 30));
        limit = 100; // Max 100 data points for month
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
        limit = 24;
    }

    try {
      List<SensorData> allData = [];

      // Get data from all active baskets with limits
      for (int i = 1; i <= 6; i++) {
        String basketKey = 'basket$i';
        List<SensorData> basketData = await getHistoricalData(
          basketKey,
          startDate,
          DateTime.now(),
          limit: limit ~/ 6, // Distribute limit across baskets
        );
        allData.addAll(basketData);

        // Prevent memory buildup
        if (allData.length > limit) {
          allData = allData.take(limit).toList();
          break;
        }
      }

      if (allData.isEmpty) {
        // Return default values if no data
        return {
          'temperature': 25.0,
          'humidity': 60.0,
          'soilMoisture': 40.0,
          'soilEC': 0.0,
          'soilPH': 0.0,
          'lightIntensity': 850.0,
        };
      }

      // Calculate averages
      double totalTemp = 0;
      double totalHumidity = 0;
      double totalSoilMoisture = 0;

      for (var data in allData) {
        totalTemp += data.temperature;
        totalHumidity += data.humidity;
        totalSoilMoisture += data.soilMoisture;
      }

      int count = allData.length;
      developer.log('Calculated averages from $count data points for $period');

      return {
        'temperature': totalTemp / count,
        'humidity': totalHumidity / count,
        'soilMoisture': totalSoilMoisture / count,
        'soilEC': 0.0, // Not available from Arduino
        'soilPH': 0.0, // Not available from Arduino
        'lightIntensity': 850.0, // Default value
      };
    } catch (e) {
      developer.log('Error calculating averages: $e');
      return {
        'temperature': 25.0,
        'humidity': 60.0,
        'soilMoisture': 40.0,
        'soilEC': 0.0,
        'soilPH': 0.0,
        'lightIntensity': 850.0,
      };
    }
  }

  // Check for alerts with memory optimization (DISABLED to prevent OOM)
  static Stream<List<Map<String, dynamic>>> getAlertsStream() {
    developer.log('Alerts stream DISABLED to prevent OutOfMemoryError');
    // Return empty stream to prevent Firebase sync
    return Stream.value(<Map<String, dynamic>>[]);

    // DISABLED: Original Firebase stream code
    /*
    return sensorData.onValue
        .map((event) {
          List<Map<String, dynamic>> alerts = [];

          try {
            if (event.snapshot.value != null) {
              Map<dynamic, dynamic> data =
                  event.snapshot.value as Map<dynamic, dynamic>;

              // Process only latest data to prevent memory issues
              data.forEach((basketKey, basketValue) {
                if (basketValue != null && basketValue is Map) {
                  Map<dynamic, dynamic> basketData = basketValue;

                  // Only check latest data, not historical
                  if (basketData.containsKey('latest')) {
                    Map<dynamic, dynamic> latestData =
                        basketData['latest'] as Map<dynamic, dynamic>;

                    try {
                      double temperature =
                          ((latestData['temperature'] ?? 0) as num).toDouble();
                      double humidity =
                          ((latestData['humidity'] ?? 0) as num).toDouble();
                      double soilMoisture =
                          ((latestData['soilMoisture'] ?? 0) as num).toDouble();

                      // Alert conditions
                      if (humidity < 60 && humidity > 0) {
                        alerts.add({
                          'basketId': basketKey.toString(),
                          'type': 'Low Humidity',
                          'message':
                              'Humidity is ${humidity.toStringAsFixed(0)}%. Consider increasing ventilation moisture.',
                          'severity': 'warning',
                        });
                      }

                      if (soilMoisture < 30 && soilMoisture > 0) {
                        alerts.add({
                          'basketId': basketKey.toString(),
                          'type': 'Water Needed',
                          'message':
                              'Soil moisture is low (${soilMoisture.toStringAsFixed(0)}%). Water your plants!',
                          'severity': 'critical',
                        });
                      }

                      if (temperature > 35) {
                        alerts.add({
                          'basketId': basketKey.toString(),
                          'type': 'High Temperature',
                          'message':
                              'Temperature is ${temperature.toStringAsFixed(1)}°C. Provide shade or cooling.',
                          'severity': 'warning',
                        });
                      }

                      if (temperature < 15 && temperature > 0) {
                        alerts.add({
                          'basketId': basketKey.toString(),
                          'type': 'Low Temperature',
                          'message':
                              'Temperature is ${temperature.toStringAsFixed(1)}°C. Melons need warmth!',
                          'severity': 'warning',
                        });
                      }
                    } catch (e) {
                      developer.log(
                        'Error processing alert data for $basketKey: $e',
                      );
                    }
                  }
                }
              });
            }
          } catch (e) {
            developer.log('Error in alerts stream processing: $e');
          }

          return alerts;
        })
        .handleError((error) {
          developer.log('Alerts stream error: $error');
          return <Map<String, dynamic>>[];
        });
    */
  }

  // Debug method to check Firebase data
  static Future<void> debugCheckAllData() async {
    try {
      developer.log('=== FIREBASE DEBUG CHECK ===');
      developer.log(
        'Database URL: ${_firebaseDatabase?.databaseURL ?? 'Not initialized'}',
      );
      developer.log('Database reference: $_database');

      // Check sensor data
      for (int i = 1; i <= 6; i++) {
        String basketId = 'basket$i';
        DatabaseEvent event = await sensorData.child(basketId).once();

        if (event.snapshot.exists) {
          developer.log('$basketId exists with data:');
          developer.log('  ${event.snapshot.value}');

          // Check latest specifically
          DatabaseEvent latestEvent =
              await sensorData.child(basketId).child('latest').once();
          if (latestEvent.snapshot.exists) {
            developer.log('  Latest data: ${latestEvent.snapshot.value}');
          } else {
            developer.log('  No latest data');
          }
        } else {
          developer.log('$basketId: No data');
        }
      }

      // Check baskets collection
      DatabaseEvent basketsEvent = await baskets.once();
      if (basketsEvent.snapshot.exists) {
        developer.log('Baskets collection: ${basketsEvent.snapshot.value}');
      } else {
        developer.log('No baskets in collection');
      }

      developer.log('=== END DEBUG CHECK ===');
    } catch (e) {
      developer.log('Debug check error: $e');
      developer.log('Stack trace: ${StackTrace.current}');
    }
  }

  // ============ FCM AND NOTIFICATION OPERATIONS ============

  // Save user notification preferences
  static Future<void> saveNotificationPreferences({
    required bool emailNotifications,
    required bool pushNotifications,
  }) async {
    try {
      String? fcmToken = FCMService.fcmToken;
      if (fcmToken == null) {
        developer.log('FCM token not available, cannot save preferences');
        return;
      }

      Map<String, dynamic> preferences = {
        'emailNotifications': emailNotifications,
        'pushNotifications': pushNotifications,
        'fcmToken': fcmToken,
        'lastUpdated': ServerValue.timestamp,
      };

      await userSettings.child('notificationPreferences').set(preferences);
      developer.log('Notification preferences saved successfully');
    } catch (e) {
      developer.log('Error saving notification preferences: $e');
      rethrow;
    }
  }

  // Get user notification preferences
  static Future<Map<String, dynamic>?> getNotificationPreferences() async {
    try {
      DatabaseEvent event =
          await userSettings.child('notificationPreferences').once();

      if (event.snapshot.exists && event.snapshot.value != null) {
        Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        return {
          'emailNotifications': data['emailNotifications'] ?? true,
          'pushNotifications': data['pushNotifications'] ?? true,
          'fcmToken': data['fcmToken'],
          'lastUpdated': data['lastUpdated'],
        };
      }

      return null;
    } catch (e) {
      developer.log('Error getting notification preferences: $e');
      return null;
    }
  }

  // Subscribe to plant alerts topic
  static Future<void> subscribeToPlantAlerts() async {
    try {
      await FCMService.subscribeToTopic('plant_alerts');
      developer.log('Subscribed to plant alerts topic');
    } catch (e) {
      developer.log('Error subscribing to plant alerts: $e');
    }
  }

  // Unsubscribe from plant alerts topic
  static Future<void> unsubscribeFromPlantAlerts() async {
    try {
      await FCMService.unsubscribeFromTopic('plant_alerts');
      developer.log('Unsubscribed from plant alerts topic');
    } catch (e) {
      developer.log('Error unsubscribing from plant alerts: $e');
    }
  }

  // Create alert notification in Firebase
  static Future<void> createAlertNotification({
    required String basketId,
    required String alertType,
    required String message,
    required String severity,
  }) async {
    try {
      String? fcmToken = FCMService.fcmToken;
      if (fcmToken == null) {
        developer.log(
          'FCM token not available, cannot create alert notification',
        );
        return;
      }

      Map<String, dynamic> alertNotification = {
        'basketId': basketId,
        'alertType': alertType,
        'message': message,
        'severity': severity,
        'timestamp': ServerValue.timestamp,
        'fcmToken': fcmToken,
        'read': false,
      };

      await notifications.push().set(alertNotification);
      developer.log('Alert notification created: $alertType for $basketId');
    } catch (e) {
      developer.log('Error creating alert notification: $e');
    }
  }

  // Get notification history
  static Stream<List<Map<String, dynamic>>> getNotificationHistory() {
    return notifications.orderByChild('timestamp').limitToLast(50).onValue.map((
      event,
    ) {
      List<Map<String, dynamic>> notifications = [];

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value != null) {
            Map<String, dynamic> notification = Map<String, dynamic>.from(
              value,
            );
            notification['id'] = key;
            notifications.add(notification);
          }
        });
      }

      // Sort by timestamp (newest first)
      notifications.sort((a, b) {
        int timestampA = a['timestamp'] ?? 0;
        int timestampB = b['timestamp'] ?? 0;
        return timestampB.compareTo(timestampA);
      });

      return notifications;
    });
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await notifications.child(notificationId).update({'read': true});
      developer.log('Notification marked as read: $notificationId');
    } catch (e) {
      developer.log('Error marking notification as read: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      await notifications.remove();
      developer.log('All notifications cleared');
    } catch (e) {
      developer.log('Error clearing notifications: $e');
    }
  }

  // ============ EMAIL NOTIFICATION OPERATIONS ============

  // Send email notification (placeholder implementation)
  static Future<bool> sendEmailNotification({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    try {
      if (!EmailService.isAvailable) {
        developer.log('Email service not available');
        return false;
      }

      bool success = await EmailService.sendEmailNotification(
        recipientEmail: recipientEmail,
        subject: subject,
        body: body,
      );

      if (success) {
        // Log email notification in Firebase
        await notifications.push().set({
          'type': 'email',
          'recipient': recipientEmail,
          'subject': subject,
          'timestamp': ServerValue.timestamp,
          'status': 'sent',
        });
      }

      return success;
    } catch (e) {
      developer.log('Error sending email notification: $e');
      return false;
    }
  }

  // Send plant alert email
  static Future<bool> sendPlantAlertEmail({
    required String recipientEmail,
    required String basketId,
    required String alertType,
    required String message,
    required String severity,
  }) async {
    try {
      if (!EmailService.isAvailable) {
        developer.log('Email service not available');
        return false;
      }

      bool success = await EmailService.sendPlantAlertEmail(
        recipientEmail: recipientEmail,
        basketId: basketId,
        alertType: alertType,
        message: message,
        severity: severity,
      );

      if (success) {
        // Log email alert in Firebase
        await notifications.push().set({
          'type': 'email_alert',
          'recipient': recipientEmail,
          'basketId': basketId,
          'alertType': alertType,
          'message': message,
          'severity': severity,
          'timestamp': ServerValue.timestamp,
          'status': 'sent',
        });
      }

      return success;
    } catch (e) {
      developer.log('Error sending plant alert email: $e');
      return false;
    }
  }

  // Get email service status
  static Map<String, dynamic> getEmailServiceStatus() {
    return EmailService.getServiceStatus();
  }
}
