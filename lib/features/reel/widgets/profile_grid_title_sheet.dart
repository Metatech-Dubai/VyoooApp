import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_light_surface.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/profile/profile_grid_thumbnail.dart';
import '../../../core/widgets/profile/profile_grid_thumbnail_service.dart';
import '../../../core/widgets/profile/profile_grid_title.dart';
import '../../../core/widgets/profile/profile_grid_title_service.dart';
import '../../../core/widgets/profile/profile_reel_grid_navigation.dart';
import '../../../services/image_picker_service.dart';

/// Edit profile grid tile title and optional custom thumbnail.
Future<void> showProfileGridTitleSheet({
  required BuildContext context,
  required Map<String, dynamic> post,
}) {
  final reelId = (post['id'] as String? ?? '').trim();
  final ownerUid = (post['userId'] as String? ?? '').trim();
  if (reelId.isEmpty || ownerUid.isEmpty) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ProfileGridTitleSheetBody(
      reelId: reelId,
      ownerUid: ownerUid,
      post: post,
    ),
  );
}

class _ProfileGridTitleSheetBody extends StatefulWidget {
  const _ProfileGridTitleSheetBody({
    required this.reelId,
    required this.ownerUid,
    required this.post,
  });

  final String reelId;
  final String ownerUid;
  final Map<String, dynamic> post;

  @override
  State<_ProfileGridTitleSheetBody> createState() =>
      _ProfileGridTitleSheetBodyState();
}

class _ProfileGridTitleSheetBodyState extends State<_ProfileGridTitleSheetBody> {
  late final TextEditingController _controller;
  final ImagePickerService _imagePicker = ImagePickerService();

  bool _saving = false;
  String? _pendingThumbPath;
  bool _resetThumbnail = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ProfileGridTitle.fromReel(widget.post),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _savedCustomThumb => ProfileGridThumbnail.fromReel(widget.post);

  bool get _hasCustomThumb =>
      !_resetThumbnail &&
      (_pendingThumbPath != null || _savedCustomThumb.isNotEmpty);

  String? get _previewNetworkUrl {
    if (_resetThumbnail) {
      return ProfileReelGridNavigation.defaultThumbnailFromReel(widget.post);
    }
    if (_pendingThumbPath != null) return null;
    if (_savedCustomThumb.isNotEmpty) return _savedCustomThumb;
    return ProfileReelGridNavigation.defaultThumbnailFromReel(widget.post);
  }

  Future<void> _pickThumbnail() async {
    final path = await _imagePicker.pickFromGallery();
    if (!mounted || path == null) return;
    setState(() {
      _pendingThumbPath = path;
      _resetThumbnail = false;
    });
  }

  void _resetToDefaultThumbnail() {
    setState(() {
      _pendingThumbPath = null;
      _resetThumbnail = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    var ok = true;
    if (_resetThumbnail) {
      ok = await ProfileGridThumbnailService.clearThumbnail(
        reelId: widget.reelId,
        ownerUserId: widget.ownerUid,
      );
      if (ok) widget.post['profileGridThumbnailUrl'] = '';
    } else if (_pendingThumbPath != null) {
      final url = await ProfileGridThumbnailService.setThumbnailFromFile(
        reelId: widget.reelId,
        ownerUserId: widget.ownerUid,
        file: File(_pendingThumbPath!),
      );
      ok = url != null;
      if (ok) widget.post['profileGridThumbnailUrl'] = url;
    }

    if (ok) {
      ok = await ProfileGridTitleService.updateTitle(
        reelId: widget.reelId,
        ownerUserId: widget.ownerUid,
        title: _controller.text,
      );
    }

    if (!mounted) return;
    if (ok) {
      widget.post['profileGridTitle'] =
          ProfileGridTitle.normalizeForSave(_controller.text);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not update profile grid. Try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _previewNetworkUrl;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AppBottomSheet.shell(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBottomSheet.dragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profile grid',
                    style: TextStyle(
                      color: AppLightSurface.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Custom thumbnail and title appear on your profile grid only.',
                  style: AppTypography.authSmallBody.copyWith(
                    color: AppLightSurface.secondaryText,
                  ),
                ),
              ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: _pendingThumbPath != null
                                ? Image.file(
                                    File(_pendingThumbPath!),
                                    fit: BoxFit.cover,
                                  )
                                : previewUrl != null && previewUrl.isNotEmpty
                                    ? Image.network(
                                        previewUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _thumbPlaceholder(),
                                      )
                                    : _thumbPlaceholder(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed: _saving ? null : _pickThumbnail,
                                child: const Text('Choose thumbnail'),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextButton(
                                onPressed: _saving || !_hasCustomThumb
                                    ? null
                                    : _resetToDefaultThumbnail,
                                child: Text(
                                  'Use default thumbnail',
                                  style: TextStyle(
                                    color: AppLightSurface.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Grid title',
                        style: TextStyle(
                          color: AppLightSurface.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Up to ${ProfileGridTitle.maxLength} characters. Leave empty to hide.',
                        style: AppTypography.authSmallBody.copyWith(
                          color: AppLightSurface.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      maxLength: ProfileGridTitle.maxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      style: AppTypography.input.copyWith(
                        color: AppLightSurface.primaryText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Summer tour',
                        hintStyle: AppTypography.input.copyWith(
                          color: AppLightSurface.mutedText,
                        ),
                        counterStyle: AppTypography.authSmallBody.copyWith(
                          color: AppLightSurface.mutedText,
                        ),
                        filled: true,
                        fillColor: AppLightSurface.cardFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppLightSurface.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppLightSurface.border,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  _controller.clear();
                                  _save();
                                },
                          child: Text(
                            'Clear title',
                            style: TextStyle(color: AppLightSurface.mutedText),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _thumbPlaceholder() {
    return ColoredBox(
      color: AppLightSurface.cardFill,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppLightSurface.mutedText,
          size: 32,
        ),
      ),
    );
  }
}
