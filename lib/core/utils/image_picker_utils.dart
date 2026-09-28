import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Helper utility for client-side image picking & target compression (< 1080p and ~80% quality)
class ImagePickerUtils {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from [source] and compresses it on device targeting < 1080p and ~80% quality.
  static Future<File?> pickAndCompressImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (picked != null) {
        return File(picked.path);
      }
    } catch (_) {}
    return null;
  }
}
