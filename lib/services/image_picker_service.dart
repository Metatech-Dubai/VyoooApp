import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Abstraction for picking images. Keeps UI free of picker logic.
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Picks from gallery. Returns file path or null if cancelled.
  Future<String?> pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    return x?.path;
  }

  /// Picks from camera. Returns file path or null if cancelled.
  Future<String?> pickFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    return x?.path;
  }

  /// Shows source choice (camera / gallery) via callback; returns chosen path.
  /// [onChooseSource] should show dialog/bottom sheet and return 'camera' or 'gallery' or null.
  Future<String?> pickProfileImage({
    required Future<String?> Function() onChooseSource,
  }) async {
    final source = await onChooseSource();
    if (source == 'camera') return pickFromCamera();
    if (source == 'gallery') return pickFromGallery();
    return null;
  }
}
