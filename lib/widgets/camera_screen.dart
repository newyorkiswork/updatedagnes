import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  final Function(File) onImageCaptured;

  const CameraScreen({
    super.key,
    required this.onImageCaptured,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePicture() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📸 Taking picture with camera...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        print('✅ Picture taken: ${image.path}');
        final imageFile = File(image.path);
        widget.onImageCaptured(imageFile);
        Navigator.pop(context);
      } else {
        print('❌ No image captured');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image captured')),
          );
        }
      }
    } catch (e) {
      print('❌ Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📁 Opening gallery...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        print('✅ Image selected from gallery: ${image.path}');
        final imageFile = File(image.path);
        widget.onImageCaptured(imageFile);
        Navigator.pop(context);
      } else {
        print('❌ No image selected from gallery');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
        }
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Product'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camera icon
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 80,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Instructions
                  const Text(
                    'Choose how to scan your product',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Text(
                    'You can take a photo with your camera\nor select an existing image from your gallery',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Camera button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton.icon(
                      onPressed: _takePicture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 28),
                      label: const Text(
                        'Take Photo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Gallery button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library, size: 28),
                      label: const Text(
                        'Choose from Gallery',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Tips
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber,
                          size: 24,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tip: Make sure the product is well-lit and clearly visible in the photo for better results.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 