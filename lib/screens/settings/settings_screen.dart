import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/app_user_model.dart';
import '../../core/profile/creator_monetization.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_light_surface.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dob_validation.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/logout_confirm_dialog.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import '../../features/vr/vr_screen.dart';
import '../account/account_screen.dart';
import '../account/delete_account_screen.dart';
import '../account/blocked_users_screen.dart';
import '../account/change_password_screen.dart';
import '../account/two_factor_screen.dart';
import '../account/verification_request_screen.dart';
import '../profile/personal_information_screen.dart';
import 'about_screen.dart';
import 'contact_support_screen.dart';
import 'creator_monetization_screen.dart';
import 'downloaded_videos_screen.dart';
import 'notifications_settings_screen.dart';
// Parental consent flow temporarily disabled; restore with the tile below.
// import 'parental_approvals_screen.dart';
import 'revenue_coming_soon_view.dart';
import 'privacy_policy_screen.dart';
import 'report_problem_screen.dart';
import 'saved_posts_screen.dart';
import 'settings_subscriptions_screen.dart';
import 'terms_service_screen.dart';
import 'wallet/wallet_coming_soon_view.dart';
import 'live_stream_monetisation_screen.dart';
import 'preferences/activity_settings_screen.dart';
import 'preferences/archive_settings_screen.dart';
import 'preferences/close_friends_screen.dart';
import 'preferences/comments_privacy_screen.dart';
import 'preferences/data_usage_settings_screen.dart';
import 'preferences/language_settings_screen.dart';
import 'preferences/messages_story_replies_screen.dart';
import 'preferences/story_reels_privacy_screen.dart';
import 'preferences/tags_mentions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static bool _showFamilyApprovalsTile(AppUserModel? user) {
    if (user == null) return true;
    final dobRaw = (user.dob ?? '').trim();
    if (dobRaw.isEmpty || !DobValidation.isValidDobString(dobRaw)) {
      return true;
    }
    final birth = DobValidation.tryParseIsoDob(dobRaw);
    if (birth == null) return true;
    return !DobValidation.requiresParentalConsent(birth);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: uid.isEmpty
                    ? _buildSettingsList(
                        context,
                        showFamilyApprovals: true,
                      )
                    : StreamBuilder<AppUserModel?>(
                        stream: UserService().userStream(uid),
                        builder: (context, snapshot) {
                          return _buildSettingsList(
                            context,
                            user: snapshot.data,
                            showFamilyApprovals:
                                _showFamilyApprovalsTile(snapshot.data),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context, {
    AppUserModel? user,
    required bool showFamilyApprovals,
  }) {
    final subscription = context.watch<SubscriptionController>();
    final showCreatorMonetization = user != null &&
        (canManageProfileMonetization(
              accountType: user.accountType,
              hasVyoooCreatorPlan: subscription.canOfferSubscriptions,
            ) ||
            user.monetizationEnabled) &&
        isSubscribeEligibleAccountType(user.accountType);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _sectionHeader(AppStrings.yourAccount),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Account.png',
            label: AppStrings.accountsCenter,
            subtitle: AppStrings.passwordSecurityVerification,
            onTap: () => _push(context, const AccountScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Account.png',
            label: AppStrings.personalInformation,
            onTap: () => _push(context, const PersonalInformationScreen()),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            label: AppStrings.passwordAndSecurity,
            onTap: () => _push(context, const ChangePasswordScreen()),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            label: AppStrings.twoFactorAuthentication,
            onTap: () => _push(context, const TwoFactorScreen()),
          ),
          _SettingsTile(
            icon: Icons.verified_outlined,
            label: AppStrings.requestVerification,
            onTap: () => _push(context, const VerificationRequestScreen()),
          ),
          _SettingsTile(
            icon: Icons.block_flipped,
            label: AppStrings.blockedAccounts,
            onTap: () => _push(context, const BlockedUsersScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader(AppStrings.howYouUseVyooo),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Home/Save.png',
            label: AppStrings.saved,
            subtitle: AppStrings.privateSavedPosts,
            onTap: () => _push(context, const SavedPostsScreen()),
          ),
          _SettingsTile(
            icon: Icons.archive_outlined,
            label: AppStrings.archive,
            onTap: () => _push(context, const ArchiveSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.history_rounded,
            label: AppStrings.yourActivity,
            onTap: () => _push(context, const ActivitySettingsScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Notification.png',
            label: AppStrings.notifications,
            onTap: () => _push(context, const NotificationSettingsScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Downloaded.png',
            label: AppStrings.downloadedVideos,
            isPremium: true,
            onTap: () => _push(context, const DownloadedVideosScreen()),
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: AppStrings.language,
            onTap: () => _push(context, const LanguageSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.data_usage_rounded,
            label: AppStrings.dataUsageAndMediaQuality,
            onTap: () => _push(context, const DataUsageSettingsScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader(AppStrings.whoCanSeeYourContent),
        _settingsGroup([
          _SettingsTile(
            icon: Icons.lock_person_outlined,
            label: AppStrings.accountPrivacy,
            subtitle: AppStrings.publicOrPrivateAccount,
            onTap: () => _push(context, const PersonalInformationScreen()),
          ),
          _SettingsTile(
            icon: Icons.people_outline_rounded,
            label: AppStrings.closeFriends,
            onTap: () => _push(context, const CloseFriendsScreen()),
          ),
          _SettingsTile(
            icon: Icons.volume_off_outlined,
            label: AppStrings.mutedAccounts,
            onTap: () => _push(context, const BlockedUsersScreen()),
          ),
          _SettingsTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: AppStrings.messagesAndStoryReplies,
            onTap: () => _push(context, const MessagesStoryRepliesScreen()),
          ),
          _SettingsTile(
            icon: Icons.tag_outlined,
            label: AppStrings.tagsAndMentions,
            onTap: () => _push(context, const TagsMentionsScreen()),
          ),
          _SettingsTile(
            icon: Icons.comment_outlined,
            label: AppStrings.comments,
            onTap: () => _push(context, const CommentsPrivacyScreen()),
          ),
          _SettingsTile(
            icon: Icons.slideshow_outlined,
            label: AppStrings.storyAndReels,
            onTap: () => _push(context, const StoryReelsPrivacyScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader(AppStrings.creatorTools),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Subscription.png',
            label: AppStrings.subscriptions,
            isPremium: true,
            onTap: () => _push(context, const SettingsSubscriptionsScreen()),
          ),
          if (showCreatorMonetization)
            _SettingsTile(
              iconPath: 'assets/vyooO_icons/Settings/Subscription.png',
              label: AppStrings.creatorSubscriptions,
              isPremium: true,
              onTap: () => _push(context, const CreatorMonetizationScreen()),
            ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Wallet.png',
            label: AppStrings.vyoooCoin,
            subtitle: AppStrings.comingSoon,
            isPremium: true,
            onTap: () => _push(
              context,
              const Scaffold(
                backgroundColor: Colors.black,
                body: WalletComingSoonView(),
              ),
            ),
          ),
          _SettingsTile(
            assetIconPath: 'assets/vyooO_icons/Home/vr.png',
            label: 'VR',
            onTap: () => _push(
              context,
              const Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(child: VrComingSoonView()),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.payments_outlined,
            label: AppStrings.revenue,
            subtitle: AppStrings.comingSoon,
            isPremium: true,
            onTap: () => _push(
              context,
              const Scaffold(
                backgroundColor: Colors.black,
                body: RevenueComingSoonView(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.live_tv_rounded,
            label: AppStrings.liveStreamMonetization,
            onTap: () => _push(context, const LiveStreamMonetisationScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader(AppStrings.supportAndAbout),
        _settingsGroup([
          // Parental consent flow temporarily disabled (min sign-up age is 16);
          // uncomment to restore the parent-side approvals entry.
          // if (showFamilyApprovals)
          //   _SettingsTile(
          //     iconPath: 'assets/vyooO_icons/Settings/About.png',
          //     label: 'Family Approvals',
          //     onTap: () => _push(context, const ParentalApprovalsScreen()),
          //   ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Customer Support.png',
            label: AppStrings.helpCenter,
            onTap: () => _push(context, const ContactSupportScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Report a problem.png',
            label: AppStrings.reportAProblem,
            onTap: () => _push(context, const ReportProblemScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/About.png',
            label: AppStrings.aboutVyooo,
            onTap: () => _push(context, const AboutScreen()),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: AppStrings.privacyPolicy,
            onTap: () => _push(context, const PrivacyPolicyScreen()),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: AppStrings.termsOfService,
            onTap: () => _push(context, const TermsServiceScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader(AppStrings.login),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Logout.png',
            label: AppStrings.logOut,
            isLogout: true,
            onTap: () => _logout(context),
          ),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            label: AppStrings.deleteAccount,
            isLogout: true,
            onTap: () => _push(context, const DeleteAccountScreen()),
          ),
        ]),
      ],
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: AppLightSurface.mutedText,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _settingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: AppLightSurface.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppLightSurface.border,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.md + 32 + AppSpacing.sm,
                color: AppLightSurface.divider,
              ),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: AppStrings.settings);
  }

  Future<void> _logout(BuildContext context) async {
    final bool? shouldLogout = await LogoutConfirmDialog.show(context);

    if (shouldLogout != true) return;

    await AuthService().signOutCurrentAccount();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.onTap,
    this.iconPath,
    this.assetIconPath,
    this.icon,
    this.subtitle,
    this.isPremium = false,
    this.isLogout = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? iconPath;
  final String? assetIconPath;
  final IconData? icon;
  final String? subtitle;
  final bool isPremium;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    final accent = AppLightSurface.primaryText;
    final labelColor = AppLightSurface.primaryText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md - 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Center(child: _buildLeading(accent)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: AppTypography.authDialogOption.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppLightSurface.cardFill,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppLightSurface.border),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: AppTypography.caption.copyWith(
                                color: AppLightSurface.primaryText,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: AppLightSurface.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLogout)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppLightSurface.chevron,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Color color) {
    if (assetIconPath != null) {
      return Image.asset(
        assetIconPath!,
        width: 22,
        height: 22,
        color: color,
      );
    }
    if (iconPath != null) {
      return Directionality(
        textDirection:
            isLogout ? TextDirection.rtl : TextDirection.ltr,
        child: Image.asset(
          iconPath!,
          width: 22,
          height: 22,
          color: color,
        ),
      );
    }
    return Icon(icon ?? Icons.settings_outlined, size: 22, color: color);
  }
}
