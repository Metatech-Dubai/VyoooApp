import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Personal Information screen: info text, Email / Phone / Date of Birth rows with dividers.
/// Opened from Edit Profile → "Personal information settings". Design matches spec.
class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({
    super.key,
    this.email,
    this.phone,
    this.dateOfBirth,
  });

  final String? email;
  final String? phone;
  final String? dateOfBirth;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: uid == null
                      ? _buildContent(context, email: email ?? '', phone: phone ?? '+61 450 826 623', dateOfBirth: dateOfBirth ?? '26 May 2000')
                      : FutureBuilder<PersonalInfoData?>(
                          future: _loadPersonalInfo(uid),
                          builder: (context, snapshot) {
                            final data = snapshot.data;
                            final userEmail = data?.email ?? email ?? AuthService().currentUser?.email ?? '';
                            final userPhone = data?.phone ?? phone ?? '+61 450 826 623';
                            final userDob = data?.dateOfBirth ?? dateOfBirth ?? '26 May 2000';
                            return _buildContent(context, email: userEmail, phone: userPhone, dateOfBirth: userDob);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<PersonalInfoData?> _loadPersonalInfo(String uid) async {
    final user = await UserService().getUser(uid);
    if (user == null) return null;
    return PersonalInfoData(
      email: user.email,
      phone: null,
      dateOfBirth: user.dob,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Personal Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String email,
    required String phone,
    required String dateOfBirth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Provide your personal information, even if the account is for something such as a business or pet. It won\'t be part of your public profile.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'To keep your account secure, don\'t enter an email address or phone number that belongs to someone else.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _InfoRow(label: 'Email', value: email.isNotEmpty ? email : '—', showDivider: true),
        _InfoRow(label: 'Phone', value: phone.isNotEmpty ? phone : '—', showDivider: true),
        _InfoRow(label: 'Date of Birth', value: dateOfBirth.isNotEmpty ? dateOfBirth : '—', showDivider: false),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class PersonalInfoData {
  const PersonalInfoData({required this.email, this.phone, this.dateOfBirth});
  final String email;
  final String? phone;
  final String? dateOfBirth;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
      ],
    );
  }
}
