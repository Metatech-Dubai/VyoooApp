import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_manager/photo_manager.dart';

import 'upload_details_screen.dart';

/// Preview selected photo before upload; optional crop (rotate / aspect) then Next.
class UploadPhotoPreviewScreen extends StatefulWidget {
  const UploadPhotoPreviewScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<UploadPhotoPreviewScreen> createState() =>
      _UploadPhotoPreviewScreenState();
}

class _UploadPhotoPreviewScreenState extends State<UploadPhotoPreviewScreen> {
  static const Color _pink = Color(0xFFDE106B);

  File? _editedPhotoFile;
  late Future<File?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.asset.file;
  }

  Future<void> _openCrop() async {
    final File? source = _editedPhotoFile ?? await widget.asset.file;
    if (source == null || !mounted) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: source.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: _pink,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop',
            rotateButtonsHidden: false,
            aspectRatioLockEnabled: false,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );
      if (!mounted || cropped == null) return;
      setState(() {
        _editedPhotoFile = File(cropped.path);
        _previewFuture = Future<File?>.value(_editedPhotoFile);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Crop failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToDetails() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UploadDetailsScreen(
          asset: widget.asset,
          photoFileOverride: _editedPhotoFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<File?>(
            future: _previewFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.file(snapshot.data!, fit: BoxFit.contain);
              }
              if (snapshot.connectionState == ConnectionState.done) {
                return Center(
                  child: Text(
                    'Could not load photo',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                IconButton(
                  onPressed: _openCrop,
                  icon: const Icon(Icons.crop, color: Colors.white, size: 26),
                  tooltip: 'Crop',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _goToDetails,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
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
}
