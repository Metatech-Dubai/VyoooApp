import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../services/image_picker_service.dart';
import '../music/music_picker_sheet.dart';
import 'crop_photo_screen.dart';
import 'personal_information_screen.dart';

/// Subscriber Edit Profile: avatar, Edit picture, Name/Username/Bio/Music, Personal information settings.
/// Username shows green check (available) or red X + error text (taken). Bio has character counter.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.initialName = 'Matt Rife',
    this.initialUsername = 'mattrife_x',
    this.initialBio = 'In the right place, at the right time',
    this.initialMusic = 'Zulfein • Mehul Mahesh, DJ A...',
    this.avatarUrl,
  });

  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String initialMusic;
  final String? avatarUrl;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _UsernameStatus { none, available, taken }

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _musicController;

  _UsernameStatus _usernameStatus = _UsernameStatus.none;

  /// Picked local file path after Edit picture → crop → Save.
  String? _pickedImagePath;

  static const int _bioMaxLength = 140;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _bioController = TextEditingController(text: widget.initialBio);
    _musicController = TextEditingController(text: widget.initialMusic);
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _musicController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    if (text.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.none);
      return;
    }
    // Simulate validation: "mattrife_22" or containing "22" as suffix = taken (for demo)
    final taken = text.toLowerCase() == 'mattrife_22' || text.endsWith('22');
    setState(() => _usernameStatus = taken ? _UsernameStatus.taken : _UsernameStatus.available);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      _buildProfilePictureSection(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildNameField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildUsernameField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildBioField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildMusicField(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildPersonalInfoLink(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onEditPicture() async {
    final path = await ImagePickerService().pickFromGallery();
    if (!mounted || path == null) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CropPhotoScreen(imagePath: path),
      ),
    );
    if (!mounted) return;
    if (result != null) setState(() => _pickedImagePath = result);
  }

  Widget _buildProfilePictureSection() {
    final avatarUrl = widget.avatarUrl;
    final hasLocal = _pickedImagePath != null;
    final file = hasLocal ? File(_pickedImagePath!) : null;
    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          backgroundImage: hasLocal && file != null
              ? FileImage(file)
              : (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
          child: (avatarUrl == null || avatarUrl.isEmpty) && !hasLocal
              ? Icon(Icons.person_rounded, size: 56, color: Colors.white.withValues(alpha: 0.6))
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _onEditPicture,
          child: const Text(
            'Edit picture',
            style: TextStyle(
              color: Color(0xFFDE106B),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return _EditProfileRow(
      label: 'Name',
      child: TextField(
        controller: _nameController,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
        decoration: _inputDecoration(hint: ''),
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditProfileRow(
          label: 'Username',
          child: TextField(
            controller: _usernameController,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 16,
            ),
            decoration: _inputDecoration(hint: 'username').copyWith(
              suffixIcon: _usernameStatus == _UsernameStatus.available
                  ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 22)
                  : _usernameStatus == _UsernameStatus.taken
                      ? Icon(Icons.cancel_rounded, color: AppColors.deleteRed, size: 22)
                      : null,
            ),
          ),
        ),
        if (_usernameStatus == _UsernameStatus.taken) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Text(
              'This username is already taken',
              style: TextStyle(color: AppColors.deleteRed, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditProfileRow(
          label: 'Bio',
          child: TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: _bioMaxLength,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
            decoration: _inputDecoration(hint: 'Add your bio').copyWith(
              counterText: '',
              contentPadding: const EdgeInsets.only(bottom: 20),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _bioController,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${value.text.length}/$_bioMaxLength',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showMusicPickerSheet(
                context,
                currentDisplay: _musicController.text,
                onDone: (track) {
                  setState(() => _musicController.text = track.profileDisplay);
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Music',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _musicController.text,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.25)),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 16),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.only(bottom: 8),
      isDense: true,
    );
  }

  Widget _buildPersonalInfoLink() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PersonalInformationScreen(),
          ),
        );
      },
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: const Color(0xFFDE106B)),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Personal information settings',
            style: TextStyle(
              color: Color(0xFFDE106B),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label on left, input on right; single underline across.
class _EditProfileRow extends StatelessWidget {
  const _EditProfileRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: child),
      ],
    );
  }
}
