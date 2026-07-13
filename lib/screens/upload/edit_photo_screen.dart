import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_spacing.dart';
import 'upload_details_screen.dart';
import 'widgets/upload_edit_media_toolbar.dart';
import 'widgets/upload_music_picker_sheet.dart';
import 'widgets/upload_post_chrome_buttons.dart';

/// Edit photo screen: close, Next, photo preview, Figma tool toolbar.
class EditPhotoScreen extends StatefulWidget {
  const EditPhotoScreen({
    super.key,
    required this.asset,
    this.initialEditedFile,
  });

  final AssetEntity asset;
  final File? initialEditedFile;

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  static const Color _pink = Color(0xFFDE106B);

  File? _editedPhotoFile;
  late Future<File?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _editedPhotoFile = widget.initialEditedFile;
    _previewFuture = _loadPreviewFile();
  }

  Future<File?> _loadPreviewFile() async {
    return _editedPhotoFile ?? await widget.asset.file;
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

  void _showEditorNotAvailable(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name is not available for photos yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openMusicPicker() {
    showUploadMusicPickerSheet(context).then((track) {
      if (!mounted || track == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected ${track.title}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _onToolTap(UploadEditMediaTool tool) {
    switch (tool) {
      case UploadEditMediaTool.music:
        _openMusicPicker();
      case UploadEditMediaTool.adjust:
        _showEditorNotAvailable('Adjust');
      case UploadEditMediaTool.filter:
        _showEditorNotAvailable('Filter');
      case UploadEditMediaTool.trim:
        _openCrop();
      case UploadEditMediaTool.speed:
        _showEditorNotAvailable('Speed');
      case UploadEditMediaTool.delete:
        _discardEdits();
    }
  }

  void _discardEdits() {
    if (_editedPhotoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No edits to discard.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0020),
        title: const Text(
          'Discard changes?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove edited photo and show the original library image again.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _editedPhotoFile = null;
                _previewFuture = widget.asset.file;
              });
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _showExitSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExitSheet(
        onContinue: () => Navigator.pop(ctx),
        onExit: () {
          Navigator.pop(ctx);
          Navigator.pop(context, _editedPhotoFile);
        },
      ),
    );
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
                return Image.file(snapshot.data!, fit: BoxFit.cover);
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
          _buildGradients(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              children: [
                UploadPostCloseButton(onTap: _showExitSheet),
                const Spacer(),
                UploadNextPillButton(onTap: _goToDetails),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: UploadEditMediaToolbar(onToolTap: _onToolTap),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitSheet extends StatelessWidget {
  const _ExitSheet({
    required this.onContinue,
    required this.onExit,
  });

  final VoidCallback onContinue;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E0A1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Are you sure you want to quit uploading?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.white),
            title: const Text(
              'Continue Editing',
              style: TextStyle(color: Colors.white),
            ),
            onTap: onContinue,
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text(
              'Exit Editing',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: onExit,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
