import 'sensor_data.dart';

class Basket {
  final String id;
  final String name;
  final DateTime plantingDate;
  final String growthStage;
  final String wateringMode;
  final String locationTag;
  final String? notes;
  final String? imageUrl;
  final SensorData? latestSensorData;

  Basket({
    required this.id,
    required this.name,
    required this.plantingDate,
    required this.growthStage,
    required this.wateringMode,
    required this.locationTag,
    this.notes,
    this.imageUrl,
    this.latestSensorData,
  });

  Map<String, dynamic> toFirebase() {
    return {
      'name': name,
      'plantingDate': plantingDate.millisecondsSinceEpoch,
      'growthStage': growthStage,
      'wateringMode': wateringMode,
      'locationTag': locationTag,
      'notes': notes,
      'imageUrl': imageUrl,
    };
  }
}
