import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/strings/app_strings.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/subscription/membership_tier.dart';
import '../../features/subscription/subscription_screen.dart';
import 'blocked_users_screen.dart';
import 'change_password_screen.dart';
import '../profile/personal_information_screen.dart';
import 'two_factor_screen.dart';
import 'verification_request_screen.dart';
import '../../core/theme/app_light_surface.dart';

/// Account screen: Current Plan, Login & Security.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  children: [
                    _buildSectionHeader('Current Plan'),
                    const SizedBox(height: 4),
                    _buildSectionSubheader(
                      'Your plan determines access and features',
                    ),
                    const SizedBox(height: 16),
                    _buildCurrentPlanCard(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Login & Security'),
                    const SizedBox(height: 4),
                    _buildSectionSubheader(
                      'Manage your passwords and security methods.',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppLightSurface.cardFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppLightSurface.border,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _AccountRow(
                            label: AppStrings.personalInformation,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PersonalInformationScreen(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _AccountRow(
                            label: AppStrings.changePassword,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ChangePasswordScreen(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _AccountRow(
                            label: AppStrings.twoFactorAuthentication,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TwoFactorScreen(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _AccountRow(
                            label: AppStrings.requestVerification,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const VerificationRequestScreen(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _AccountRow(
                            label: AppStrings.blockedAccounts,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BlockedUsersScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: AppStrings.account);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
                    color: AppLightSurface.primaryText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildSectionSubheader(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppLightSurface.secondaryText,
        fontSize: 13,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppLightSurface.cardFill,
      indent: 0,
      endIndent: 0,
    );
  }

  Widget _buildCurrentPlanCard(BuildContext context) {
    final controller = context.watch<SubscriptionController>();
    final tier = controller.currentTier;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppLightSurface.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppLightSurface.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _planSubtitle(tier),
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _planPriceLine(tier),
                  style: TextStyle(
                    color: AppLightSurface.secondaryText,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF81945),
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 32),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Upgrade Plan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _planSubtitle(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.none:
        return 'Free · Standard Plan';
      case MembershipTier.standard:
        return 'Monthly · Standard Plan';
      case MembershipTier.subscriber:
        return 'Monthly · Subscriber';
      case MembershipTier.creator:
        return 'Monthly · Creator';
    }
  }

  String _planPriceLine(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.none:
        return 'Free - Upgrade to unlock features';
      case MembershipTier.standard:
        return '\$4.99 - Renews on 04 Jan 2026';
      case MembershipTier.subscriber:
        return '\$4.99/M - Premium features active';
      case MembershipTier.creator:
        return '\$19.99/M - Creator features active';
    }
  }

}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppLightSurface.secondaryText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
