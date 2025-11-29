// screens/new_basket_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;
import '../utils/app_colors.dart';
import '../models/basket.dart';
import '../services/firebase_service.dart';

class NewBasketScreen extends StatefulWidget {
  const NewBasketScreen({super.key});

  @override
  State<NewBasketScreen> createState() => _NewBasketScreenState();
}

class _NewBasketScreenState extends State<NewBasketScreen> {
  final _basketNameController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedGrowthStage = 'Seedling Stage';
  final String _selectedWateringMode =
      'Semi-Automatic'; // Fixed to Semi-Automatic
  String _locationTag = '';

  // Image picker variables
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingBasket = false;

  @override
  void dispose() {
    _basketNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Calculate planting date range based on selected growth stage
  List<DateTime> _getPlantingDateRange(String growthStage) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (growthStage) {
      case 'Seedling Stage':
        // 1-2 weeks ago
        return [
          today.subtract(Duration(days: 14)), // 2 weeks ago
          today.subtract(Duration(days: 7)), // 1 week ago
        ];
      case 'Vegetative Stage':
        // 3-4 weeks ago
        return [
          today.subtract(Duration(days: 28)), // 4 weeks ago
          today.subtract(Duration(days: 21)), // 3 weeks ago
        ];
      case 'Flowering Stage':
        // 5-6 weeks ago
        return [
          today.subtract(Duration(days: 42)), // 6 weeks ago
          today.subtract(Duration(days: 35)), // 5 weeks ago
        ];
      case 'Fruit Setting Stage':
        // 7-11 weeks ago
        return [
          today.subtract(Duration(days: 77)), // 11 weeks ago
          today.subtract(Duration(days: 49)), // 7 weeks ago
        ];
      default:
        // Default to 1-2 weeks ago for unknown stages
        return [
          today.subtract(Duration(days: 14)),
          today.subtract(Duration(days: 7)),
        ];
    }
  }

  // Get available planting dates for the selected growth stage
  List<DateTime> _getAvailablePlantingDates() {
    final range = _getPlantingDateRange(_selectedGrowthStage);
    final startDate = range[0];
    final endDate = range[1];
    final List<DateTime> availableDates = [];

    // Generate dates within the range (weekly intervals)
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      availableDates.add(currentDate);
      currentDate = currentDate.add(Duration(days: 7)); // Weekly intervals
    }

    return availableDates;
  }

  // Image picker methods
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorMessage('Error taking photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        // Check if file extension is valid
        final String extension = image.path.toLowerCase();
        if (extension.endsWith('.jpg') ||
            extension.endsWith('.jpeg') ||
            extension.endsWith('.png')) {
          setState(() {
            _selectedImage = File(image.path);
          });
        } else {
          _showErrorMessage('Please select a JPG, JPEG, or PNG image.');
        }
      }
    } catch (e) {
      _showErrorMessage('Error selecting image: $e');
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              if (_selectedImage != null)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Remove Photo',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _createBasket() async {
    // Validate inputs
    if (_basketNameController.text.trim().isEmpty) {
      _showErrorMessage('Please enter a basket name');
      return;
    }

    if (_selectedDate == null) {
      _showErrorMessage('Please select a planting date');
      return;
    }

    if (_locationTag.trim().isEmpty) {
      _showErrorMessage('Please enter a location tag');
      return;
    }

    setState(() {
      _isCreatingBasket = true;
    });

    try {
      // Test Firebase connection first
      bool isConnected = await FirebaseService.testConnection().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      // If primary test fails, try fallback method
      if (!isConnected) {
        developer.log('Primary connection test failed, trying fallback...');
        isConnected = await FirebaseService.testConnectionFallback().timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
      }

      if (!isConnected) {
        _showErrorMessage(
          'Cannot connect to database. Check your internet connection.',
        );
        return;
      }

      // Create initial basket without image
      Basket newBasket = Basket(
        id: '', // Firebase will generate ID
        name: _basketNameController.text.trim(),
        plantingDate: _selectedDate!,
        growthStage: _selectedGrowthStage,
        wateringMode: _selectedWateringMode,
        locationTag: _locationTag.trim(),
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        imageUrl: null, // Will be updated if image is uploaded
      );

      print('Creating basket with data: ${newBasket.toFirebase()}');

      // Create basket in Firebase
      String basketId = await FirebaseService.createBasket(
        newBasket,
      ).timeout(const Duration(seconds: 15), onTimeout: () => '');
      print('Basket created with ID: $basketId');

      if (basketId.isNotEmpty) {
        String? imageUrl;

        // Upload image if selected
        if (_selectedImage != null) {
          imageUrl = await FirebaseService.uploadBasketImage(
            _selectedImage!,
            basketId,
          ).timeout(const Duration(seconds: 25), onTimeout: () => null);

          // Update basket with image URL
          if (imageUrl != null) {
            await FirebaseService.updateBasket(basketId, {
              'imageUrl': imageUrl,
            }).timeout(const Duration(seconds: 10), onTimeout: () {});
          }
        }

        _showSuccessMessage('Basket created successfully!');

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        _showErrorMessage('Failed to create basket. Please try again.');
      }
    } catch (e) {
      _showErrorMessage('Error creating basket: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBasket = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableDates = _getAvailablePlantingDates();

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
          child: IconButton(
            icon: Image.asset(
              'assets/images/back_icon.png',
              width: 24,
              height: 24,
              color: AppColors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Add New Basket',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: "Poppins",
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),

            // Basket Name
            _buildInputField(
              icon: Icons.local_florist,
              label: 'Basket Name',
              controller: _basketNameController,
              hint: 'Enter basket name',
            ),
            const SizedBox(height: 16),

            // Growth Stage Dropdown (This affects planting date range)
            _buildDropdownField(
              icon: Icons.grass,
              label: 'Growth Stage',
              value: _selectedGrowthStage,
              items: [
                'Seedling Stage',
                'Vegetative Stage',
                'Flowering Stage',
                'Fruit Setting Stage',
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGrowthStage = value!;
                  // Reset selected date when growth stage changes
                  _selectedDate = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Planting Date (Smart date selection based on growth stage)
            _buildSmartDateField(
              icon: Icons.calendar_today,
              label: 'Planting Date',
              selectedDate: _selectedDate,
              availableDates: availableDates,
              growthStage: _selectedGrowthStage,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
            const SizedBox(height: 16),

            // Watering Mode (Fixed to Semi-Automatic)
            _buildDisabledDropdownField(
              icon: Icons.water_drop,
              label: 'Watering Mode',
              value: _selectedWateringMode,
              items: ['Semi-Automatic'],
              onChanged: null, // Disabled
            ),
            const SizedBox(height: 16),

            // Location Tag
            _buildInputField(
              icon: Icons.location_on,
              label: 'Location Tag',
              controller: TextEditingController(text: _locationTag),
              hint: 'e.g., R2B1 (Row 2 Basket 1)',
              onChanged: (value) {
                _locationTag = value;
              },
            ),
            const SizedBox(height: 16),

            // Notes
            _buildInputField(
              icon: Icons.note,
              label: 'Notes',
              controller: _notesController,
              hint: 'Add any additional notes',
            ),
            const SizedBox(height: 16),

            // Upload Picture Section
            _buildUploadPictureSection(),
            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreatingBasket ? null : _createBasket,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isCreatingBasket ? AppColors.neutral : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isCreatingBasket
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Creating...',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                        : Text(
                          'Create Basket',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontFamily: "Poppins",
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPictureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Picture',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Info text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.neutral),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add a photo to help identify your plant. Supports JPG, JPEG, PNG formats.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Image preview or upload button
        _selectedImage != null ? _buildImagePreview() : _buildUploadButton(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral),
      ),
      child: Column(
        children: [
          // Image preview
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _showImagePickerDialog,
                  icon: Icon(Icons.edit, color: AppColors.primary),
                  label: Text(
                    'Change',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neutral,
          style: BorderStyle.solid,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: _showImagePickerDialog,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 48, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              'Add Plant Photo',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to upload or take photo',
              style: TextStyle(
                color: AppColors.neutral,
                fontSize: 12,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.neutral,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neutral),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neutral),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartDateField({
    required IconData icon,
    required String label,
    required DateTime? selectedDate,
    required List<DateTime> availableDates,
    required String growthStage,
    required Function(DateTime) onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Growth stage info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.neutral),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Based on $growthStage: Select a date ${_getDateRangeDescription(growthStage)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Date selection
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<DateTime>(
            value: selectedDate,
            items:
                availableDates.map((DateTime date) {
                  return DropdownMenuItem<DateTime>(
                    value: date,
                    child: Text(
                      '${date.day}/${date.month}/${date.year} (${_getWeekDescription(date)})',
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
            onChanged: (date) {
              if (date != null) {
                onDateSelected(date);
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledDropdownField({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required Function(String?)? onChanged,
  }) {
    // Validate that the value exists in the items list
    String validatedValue = value;
    if (!items.contains(value)) {
      // If the value doesn't exist in the items list, use the first item as fallback
      validatedValue = items.isNotEmpty ? items.first : '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: validatedValue.isEmpty ? null : validatedValue,
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }).toList(),
          onChanged: onChanged, // This will be null, making it disabled
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neutral),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neutral),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            filled: true,
            fillColor: AppColors.neutral.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Validate that the value exists in the items list
    String validatedValue = value;
    if (!items.contains(value)) {
      // If the value doesn't exist in the items list, use the first item as fallback
      validatedValue = items.isNotEmpty ? items.first : '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: validatedValue.isEmpty ? null : validatedValue,
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neutral),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neutral),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  String _getDateRangeDescription(String growthStage) {
    switch (growthStage) {
      case 'Seedling Stage':
        return '1-2 weeks ago';
      case 'Vegetative Stage':
        return '3-4 weeks ago';
      case 'Flowering Stage':
        return '5-6 weeks ago';
      case 'Fruit Setting Stage':
        return '7-11 weeks ago';
      default:
        return '1-2 weeks ago';
    }
  }

  String _getWeekDescription(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    final weeks = (difference / 7).floor();

    if (weeks == 1) {
      return '1 week ago';
    } else {
      return '$weeks weeks ago';
    }
  }
}
