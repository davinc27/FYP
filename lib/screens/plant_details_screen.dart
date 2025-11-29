// screens/plant_details_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../widgets/base64_image.dart';
import '../models/basket.dart';
import '../models/sensor_data.dart';
import '../services/firebase_service.dart';

class PlantDetailsScreen extends StatefulWidget {
  final String basketName;
  final String basketId;
  final DateTime? plantingDate;

  const PlantDetailsScreen({
    super.key,
    required this.basketName,
    required this.basketId,
    this.plantingDate,
  });

  @override
  State<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  // Real sensor data from Firebase
  double temperature = 0.0;
  double humidity = 0.0;
  double soilMoisture = 0.0;

  // Manual input data (editable by user)
  double soilEC = 70.0;
  double soilPH = 6.5;
  double lightIntensity = 850.0; // in lux

  bool _isDeleting = false;
  bool _isEditing = false;
  bool _isDataLoading = true;
  bool _isChangingImage = false;

  // Controllers for editable fields
  final TextEditingController _soilECController = TextEditingController();
  final TextEditingController _soilPHController = TextEditingController();
  final TextEditingController _lightIntensityController =
      TextEditingController();
  final TextEditingController _locationTagController = TextEditingController();

  // Stream subscriptions (unused; using one-time fetch for stability)
  StreamSubscription<SensorData?>? _sensorDataSubscription;

  // Basket data for location tag
  Basket? _basketData;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSensorData();
    _loadManualData();
    _loadBasketData();
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
    _soilECController.dispose();
    _soilPHController.dispose();
    _lightIntensityController.dispose();
    _locationTagController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _soilECController.text = soilEC.toString();
    _soilPHController.text = soilPH.toString();
    _lightIntensityController.text = lightIntensity.toString();
    _locationTagController.text = _basketData?.locationTag ?? 'Row 2 Basket 1';
  }

  Future<void> _loadSensorData() async {
    try {
      setState(() {
        _isDataLoading = true;
      });

      // Fetch global temp/humidity from any available basket (same as Home screen)
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

      // Fetch soil moisture for the current basket specifically
      final currentBasketData = await FirebaseService.getLatestSensorData(
        widget.basketId,
      );

      if (!mounted) return;

      setState(() {
        if (firstAvailable != null) {
          temperature = firstAvailable.temperature;
          humidity = firstAvailable.humidity;
        }
        if (currentBasketData != null) {
          soilMoisture = currentBasketData.soilMoisture;
        }
        _isDataLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }

  void _loadManualData() {
    // Load manual data from Firebase (if available)
    // For now, using default values
    // TODO: Implement loading from Firebase
  }

  Future<void> _loadBasketData() async {
    try {
      final basket = await FirebaseService.getBasket(widget.basketId);
      if (mounted && basket != null) {
        setState(() {
          _basketData = basket;
          _locationTagController.text =
              basket.locationTag.isNotEmpty
                  ? basket.locationTag
                  : 'Row 2 Basket 1';
        });
      }
    } catch (e) {
      print('Error loading basket data: $e');
    }
  }

  Future<void> _deleteBasket() async {
    // Show confirmation dialog
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            'Delete Basket',
            style: TextStyle(
              color: AppColors.primary,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${widget.basketName}"? This action cannot be undone.',
            style: TextStyle(
              color: AppColors.primary,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        await FirebaseService.deleteBasket(widget.basketId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Basket deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // Go back to home screen
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting basket: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleEditMode() async {
    if (_isEditing) {
      // Save changes
      try {
        // Update manual data in Firebase
        await FirebaseService.updateBasket(widget.basketId, {
          'soilEC': double.tryParse(_soilECController.text) ?? soilEC,
          'soilPH': double.tryParse(_soilPHController.text) ?? soilPH,
          'lightIntensity':
              double.tryParse(_lightIntensityController.text) ?? lightIntensity,
          'locationTag':
              _locationTagController.text.trim().isNotEmpty
                  ? _locationTagController.text.trim()
                  : 'Row 2 Basket 1',
        });

        // Update local state
        setState(() {
          soilEC = double.tryParse(_soilECController.text) ?? soilEC;
          soilPH = double.tryParse(_soilPHController.text) ?? soilPH;
          lightIntensity =
              double.tryParse(_lightIntensityController.text) ?? lightIntensity;
          // Reload basket data to get updated locationTag
          _loadBasketData();
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Changes saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Enter edit mode
      setState(() {
        _isEditing = true;
      });
    }
  }

  Future<void> _changeImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text(
                  'Take New Photo',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadNewImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadNewImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadNewImage(File imageFile) async {
    setState(() {
      _isChangingImage = true;
    });

    try {
      // Upload new image
      String? newImageUrl = await FirebaseService.uploadBasketImage(
        imageFile,
        widget.basketId,
      );

      if (newImageUrl != null) {
        // Update basket with new image URL
        await FirebaseService.updateBasket(widget.basketId, {
          'imageUrl': newImageUrl,
        });

        // Reload basket data to refresh the UI
        await _loadBasketData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final growthStage = _calculateGrowthStage();
    final weeksSincePlanting = _calculateWeeksSincePlanting();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brown,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          // Edit button
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isEditing ? AppColors.primary : AppColors.brown,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: _toggleEditMode,
                icon: Icon(
                  _isEditing ? Icons.save : Icons.edit,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Delete button
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
            decoration: BoxDecoration(
              color: _isDeleting ? AppColors.neutral : Colors.red.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: _isDeleting ? null : _deleteBasket,
                icon:
                    _isDeleting
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                        : Icon(Icons.delete, color: AppColors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Location Tag Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.basketName,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Poppins",
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$weeksSincePlanting weeks - $growthStage',
                        style: TextStyle(
                          color: AppColors.brown,
                          fontSize: 14,
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Location Tag chip - now editable
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brown,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child:
                      _isEditing
                          ? SizedBox(
                            width: 120,
                            height: 24,
                            child: TextField(
                              controller: _locationTagController,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Poppins",
                              ),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: AppColors.white,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: AppColors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          )
                          : Text(
                            _basketData?.locationTag.isNotEmpty == true
                                ? _basketData!.locationTag
                                : 'Row 2 Basket 1',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: "Poppins",
                            ),
                          ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Plant Image - Large and full-width
            Container(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Main plant image - Full width only if custom image uploaded
                  _basketData?.imageUrl != null &&
                          _basketData!.imageUrl!.isNotEmpty
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Base64Image(
                          imageData: _basketData!.imageUrl,
                          fallbackAsset: 'assets/images/melon_soil.png',
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.6,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      )
                      : Image.asset(
                        'assets/images/melon_soil.png',
                        height: MediaQuery.of(context).size.height * 0.6,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),

                  // Image change button (top right corner)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _isChangingImage ? null : _changeImage,
                        icon:
                            _isChangingImage
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                )
                                : Icon(
                                  Icons.camera_alt,
                                  color: AppColors.white,
                                  size: 20,
                                ),
                      ),
                    ),
                  ),

                  // Semi-transparent overlay for better text visibility (only for uploaded images)
                  if (_basketData?.imageUrl != null &&
                      _basketData!.imageUrl!.isNotEmpty)
                    Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),

                  // Sensor metric cards positioned around the plant
                  // Top left - Temperature (Real-time from sensors)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: _buildMetricCard(
                      label: 'Temp',
                      value:
                          _isDataLoading
                              ? '...'
                              : '${temperature.toStringAsFixed(0)}°C',
                      color: AppColors.blue,
                    ),
                  ),

                  // Top right - Humidity (Real-time from sensors)
                  Positioned(
                    top: 20,
                    right:
                        80, // Moved left to avoid conflict with image change button
                    child: _buildMetricCard(
                      label: 'Humidity',
                      value:
                          _isDataLoading
                              ? '...'
                              : '${humidity.toStringAsFixed(0)}%',
                      color: AppColors.neutral,
                    ),
                  ),

                  // Bottom left - Soil Moisture (Real-time from sensors)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: _buildMetricCard(
                      label: 'Soil Moist.',
                      value:
                          _isDataLoading
                              ? '...'
                              : '${soilMoisture.toStringAsFixed(0)}%',
                      color: AppColors.brown,
                      textColor: AppColors.white,
                    ),
                  ),

                  // Bottom right - Soil EC (Editable by user)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: _buildEditableMetricCard(
                      label: 'Soil EC',
                      value: soilEC.toStringAsFixed(0),
                      unit: '%',
                      color: AppColors.peach,
                      controller: _soilECController,
                      isEditing: _isEditing,
                    ),
                  ),

                  // Middle left - Soil pH (Editable by user)
                  Positioned(
                    left: 20,
                    top: MediaQuery.of(context).size.height * 0.3,
                    child: _buildEditableMetricCard(
                      label: 'Soil pH',
                      value: soilPH.toStringAsFixed(1),
                      unit: '',
                      color: AppColors.secondary,
                      controller: _soilPHController,
                      isEditing: _isEditing,
                    ),
                  ),

                  // Middle right - Light Intensity (Editable by user)
                  Positioned(
                    right: 20,
                    top: MediaQuery.of(context).size.height * 0.3,
                    child: _buildEditableMetricCard(
                      label: 'Light',
                      value: lightIntensity.toStringAsFixed(0),
                      unit: ' lux',
                      color: AppColors.accent,
                      controller: _lightIntensityController,
                      isEditing: _isEditing,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Growth Stage Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth Stage Information',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Poppins",
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGrowthStageInfo(growthStage, weeksSincePlanting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor ?? AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: "Poppins",
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor ?? AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: "Poppins",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableMetricCard({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required TextEditingController controller,
    required bool isEditing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: "Poppins",
            ),
          ),
          if (isEditing)
            SizedBox(
              width: 60,
              height: 30,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Poppins",
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            )
          else
            Text(
              '$value$unit',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: "Poppins",
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrowthStageInfo(String stage, int weeks) {
    String description = '';
    String recommendations = '';

    switch (stage) {
      case 'Seedling Stage':
        description =
            'Early growth phase with developing roots and first true leaves.';
        recommendations =
            '• Keep soil consistently moist\n• Maintain temperature 20-25°C\n• Provide gentle light';
        break;
      case 'Vegetative Stage':
        description = 'Rapid leaf and stem growth phase.';
        recommendations =
            '• Increase watering frequency\n• Provide full sunlight\n• Start light fertilization';
        break;
      case 'Flowering Stage':
        description = 'Flower development and pollination phase.';
        recommendations =
            '• Maintain consistent moisture\n• Ensure good air circulation\n• Monitor for pests';
        break;
      case 'Fruit Setting Stage':
        description = 'Fruit development and maturation phase.';
        recommendations =
            '• Reduce watering slightly\n• Provide support for heavy fruits\n• Monitor for diseases';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Stage: $stage',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: "Poppins",
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: AppColors.brown,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Recommendations:',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: "Poppins",
          ),
        ),
        const SizedBox(height: 4),
        Text(
          recommendations,
          style: TextStyle(
            color: AppColors.brown,
            fontSize: 13,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _calculateGrowthStage() {
    if (widget.plantingDate == null) {
      return 'Seedling Stage';
    }

    final weeksSincePlanting = _calculateWeeksSincePlanting();

    if (weeksSincePlanting >= 1 && weeksSincePlanting <= 2) {
      return 'Seedling Stage';
    } else if (weeksSincePlanting >= 3 && weeksSincePlanting <= 4) {
      return 'Vegetative Stage';
    } else if (weeksSincePlanting >= 5 && weeksSincePlanting <= 6) {
      return 'Flowering Stage';
    } else if (weeksSincePlanting >= 7 && weeksSincePlanting <= 11) {
      return 'Fruit Setting Stage';
    } else {
      return 'Mature Stage';
    }
  }

  int _calculateWeeksSincePlanting() {
    if (widget.plantingDate == null) {
      return 0;
    }

    final now = DateTime.now();
    final difference = now.difference(widget.plantingDate!);
    final weeks = (difference.inDays / 7).floor();
    return weeks;
  }
}
