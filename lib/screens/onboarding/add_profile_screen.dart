import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/profile_photo_source_sheet.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import '../../services/image_picker_service.dart';
import '../../state/onboarding_state.dart';
class AddProfileScreen extends StatefulWidget {
  const AddProfileScreen({
    super.key,
    this.onboardingState,
    this.imagePickerService,
  });

  final OnboardingState? onboardingState;
  final ImagePickerService? imagePickerService;

  @override
  State<AddProfileScreen> createState() => _AddProfileScreenState();
}

class _AddProfileScreenState extends State<AddProfileScreen> {
  static const double _horizontalPadding = 28;
  static const double _progressFill = 0.6;

  OnboardingState get _state => widget.onboardingState ?? _defaultState;
  ImagePickerService get _imageService =>
      widget.imagePickerService ?? ImagePickerService();

  static final OnboardingState _defaultState = OnboardingState();

  String? _profileImagePath;
  bool _isPicking = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _profileImagePath = _state.profileImagePath;
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() => _profileImagePath = _state.profileImagePath);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPicking) return;
    final source = await showProfilePhotoSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _isPicking = true);
    try {
      final pickedPath = source == ProfilePhotoPickSource.camera
          ? await _imageService.pickFromCamera()
          : await _imageService.pickFromGallery();
      if (!mounted || pickedPath == null) return;
      final croppedPath = await _cropProfileImage(pickedPath);
      if (mounted && croppedPath != null) {
        _state.profileImagePath = croppedPath;
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<String?> _cropProfileImage(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo',
            toolbarColor: AppColors.brandPurple,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppColors.brandPink,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
            cropStyle: CropStyle.circle,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Crop profile photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );
      return cropped?.path;
    } catch (error) {
      debugPrint('Profile crop failed: $error');
      return sourcePath;
    }
  }

  Future<void> _onNext() async {
    if (_isUploading) return;
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    setState(() => _isUploading = true);
    try {
      if (_profileImagePath != null) {
        try {
          await StorageService().uploadProfileImage(
            imageFile: File(_profileImagePath!),
            uid: uid,
          );
        } catch (error) {
          // Upload failed (e.g. Firebase Storage not enabled or rules).
          // Don't block onboarding on the photo; continue without it.
          debugPrint('Profile image upload failed: $error');
        }
      }
      // The photo is optional: mark the step complete (with or without an
      // image) so the onboarding gate advances to location / interests.
      await UserService().updateUserProfile(
        uid: uid,
        profileImageSetupComplete: true,
      );
    } catch (error) {
      debugPrint('Profile step completion failed: $error');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.authFlow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const VyoooBrandLogo(size: AppSizes.authLogoHeight),
                const SizedBox(height: 16),
                _buildProgressBar(),

                /// MIDDLE SECTION (CENTERED)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 40),

                      const Text(
                        'Add a Profile page',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.defaultTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Select a photo that matches your vibe',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),
          AuthFloatingNavRow(
            onBack: _onBack,
            onForward: _onNext,
            forwardEnabled: !_isUploading,
            forwardLoading: _isUploading,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final fillWidth = fullWidth * _progressFill;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  width: fullWidth,
                  height: 3,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                SizedBox(
                  width: fillWidth,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPink,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(10),
                        right: Radius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: _isPicking ? null : _pickImage,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _profileImagePath != null
                  ? _buildAvatarImage()
                  : _buildDefaultAvatar(),
            ),
          ),

          /// sparkle icon
          Positioned(
            top: 8,
            left: 10,
            child: Image.asset(
              'assets/vyooO_icons/Profile/profile_sparkle.png',
              width: 50,
              height: 50,
            ),
          ),

          /// camera button
          Positioned(
            right: -2,
            bottom: 10,
            child: GestureDetector(
              onTap: _isPicking ? null : _pickImage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF14001E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: _isPicking
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Image.asset(
                        'assets/vyooO_icons/Profile/arrow.png',
                        width: 22,
                        height: 22,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      key: const ValueKey('default'),
      width: 221,
      height: 221,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: White10.value, width: 1),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        size: 80,
        color: AppColors.brandPink,
      ),
    );
  }

  Widget _buildAvatarImage() {
    final path = _profileImagePath!;
    return Container(
      key: ValueKey(path),
      width: 221,
      height: 221,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: White10.value, width: 1),
        image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
      ),
    );
  }

  Future<void> _onBack() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }
}
