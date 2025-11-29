// models/sensor_data.dart
class SensorData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double soilPH;
  final double soilEC;
  final double lightIntensity;
  final String? basketId;

  SensorData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.soilPH,
    required this.soilEC,
    required this.lightIntensity,
    this.basketId,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: DateTime.parse(json['timestamp']),
      temperature: _parseDouble(json['temperature']),
      humidity: _parseDouble(json['humidity']),
      soilMoisture: _parseDouble(json['soil_moisture']),
      soilPH: _parseDouble(json['soil_ph']),
      soilEC: _parseDouble(json['soil_ec']),
      lightIntensity: _parseDouble(json['light']),
      basketId: json['basketId'] as String?,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.toLowerCase() == 'nan' || value == 'NaN') return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Constructor for Firebase service compatibility
  factory SensorData.fromFirebase({
    required DateTime timestamp,
    required double temperature,
    required double humidity,
    required double soilMoisture,
    required double soilPH,
    required double soilEC,
    required String basketId,
  }) {
    return SensorData(
      timestamp: timestamp,
      temperature: temperature,
      humidity: humidity,
      soilMoisture: soilMoisture,
      soilPH: soilPH,
      soilEC: soilEC,
      lightIntensity: 0.0, // Default value for Firebase data
      basketId: basketId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'soil_moisture': soilMoisture,
      'soil_ph': soilPH,
      'soil_ec': soilEC,
      'light': lightIntensity,
    };
  }

  @override
  String toString() {
    return 'SensorData(timestamp: $timestamp, temperature: $temperature, humidity: $humidity, soilMoisture: $soilMoisture, soilPH: $soilPH, soilEC: $soilEC, lightIntensity: $lightIntensity)';
  }
}
