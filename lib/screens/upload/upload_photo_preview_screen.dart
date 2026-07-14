import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'edit_photo_screen.dart';
import 'upload_details_screen.dart';
import 'widgets/upload_post_chrome_buttons.dart';

/// Preview selected photo before upload; optional edit then Next.
class UploadPhotoPreviewScreen extends StatefulWidget {
  const UploadPhotoPreviewScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<UploadPhotoPreviewScreen> createState() =>
      _UploadPhotoPreviewScreenState();
}

class _UploadPhotoPreviewScreenState extends State<UploadPhotoPreviewScreen> {
  File? _editedPhotoFile;
  late Future<File?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.asset.file;
  }

  void _openEditor() {
    Navigator.of(context)
        .push<File?>(
      MaterialPageRoute<File?>(
        builder: (_) => EditPhotoScreen(
          asset: widget.asset,
          initialEditedFile: _editedPhotoFile,
        ),
      ),
    )
        .then((edited) {
      if (!mounted || edited == null) return;
      setState(() {
        _editedPhotoFile = edited;
        _previewFuture = Future<File?>.value(edited);
      });
    });
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
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: UploadMediaPreviewToolbar(
                  mediaType: UploadPreviewMediaType.photo,
                  onCloseTap: () => Navigator.of(context).pop(),
                  onEditTap: _openEditor,
                  onNextTap: _goToDetails,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
