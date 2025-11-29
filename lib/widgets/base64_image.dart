import 'package:flutter/material.dart';
import 'dart:convert';

class Base64Image extends StatelessWidget {
  final String? imageData;
  final String fallbackAsset;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const Base64Image({
    super.key,
    this.imageData,
    required this.fallbackAsset,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // If no image data or empty, use fallback asset
    if (imageData == null || imageData!.isEmpty) {
      return _buildImageWidget(
        Image.asset(fallbackAsset, fit: fit),
      );
    }

    // Check if it's a base64 data URL
    if (imageData!.startsWith('data:image/')) {
      try {
        // Extract base64 part from data URL
        final base64String = imageData!.split(',')[1];
        final bytes = base64Decode(base64String);
        
        return _buildImageWidget(
          Image.memory(
            bytes,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(fallbackAsset, fit: fit);
            },
          ),
        );
      } catch (e) {
        // If base64 decoding fails, use fallback
        return _buildImageWidget(
          Image.asset(fallbackAsset, fit: fit),
        );
      }
    }

    // If it's a regular URL, try to load it
    if (imageData!.startsWith('http')) {
      return _buildImageWidget(
        Image.network(
          imageData!,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(fallbackAsset, fit: fit);
          },
        ),
      );
    }

    // Default to fallback
    return _buildImageWidget(
      Image.asset(fallbackAsset, fit: fit),
    );
  }

  Widget _buildImageWidget(Widget image) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(
          width: width,
          height: height,
          child: image,
        ),
      );
    }
    
    return SizedBox(
      width: width,
      height: height,
      child: image,
    );
  }
}
