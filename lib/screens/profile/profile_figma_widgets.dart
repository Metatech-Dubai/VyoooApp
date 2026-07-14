import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'profile_figma_tokens.dart';

/// Circular profile photo with optional Figma story ring SVG (131×131, #E51147).
class ProfileFigmaAvatar extends StatelessWidget {
  const ProfileFigmaAvatar({
    super.key,
    required this.imageUrl,
    this.hasStory = false,
    this.onTap,
    this.outerSize,
  });

  final String? imageUrl;
  final bool hasStory;
  final VoidCallback? onTap;
  /// When set, story-ring insets scale from the 131px Figma artboard.
  final double? outerSize;

  static bool isValidNetworkUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  double get _outer => outerSize ?? ProfileFigmaTokens.avatarOuterSize;

  double get _storyRingScale =>
      _outer / ProfileFigmaTokens.avatarOuterSize;

  @override
  Widget build(BuildContext context) {
    final outer = _outer;

    Widget child;
    if (hasStory) {
      final scale = _storyRingScale;
      final inner = ProfileFigmaTokens.avatarStoryRingInnerSize * scale;
      final whiteGap = ProfileFigmaTokens.avatarStoryWhiteGap * scale;
      final photoSize = ProfileFigmaTokens.avatarStoryPhotoSize * scale;

      child = SizedBox(
        width: outer,
        height: outer,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: inner,
              height: inner,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ProfileFigmaTokens.screenBackground,
              ),
              padding: EdgeInsets.all(whiteGap),
              child: _buildPhotoDisc(diameter: photoSize),
            ),
            IgnorePointer(
              child: SvgPicture.asset(
                ProfileAssets.profileAvatarStoryRing,
                width: outer,
                height: outer,
                fit: BoxFit.fill,
              ),
            ),
          ],
        ),
      );
    } else {
      child = SizedBox(
        width: outer,
        height: outer,
        child: Center(child: _buildPhotoDisc(diameter: outer)),
      );
    }

    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    }

    return child;
  }

  Widget _buildPhotoDisc({required double diameter}) {
    final radius = diameter / 2;
    final hasImage = isValidNetworkUrl(imageUrl);

    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: ColoredBox(
          color: ProfileFigmaTokens.cardBackground,
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  width: diameter,
                  height: diameter,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_rounded,
                    size: radius,
                    color: ProfileFigmaTokens.secondaryText
                        .withValues(alpha: 0.5),
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: radius,
                  color: ProfileFigmaTokens.secondaryText.withValues(alpha: 0.5),
                ),
        ),
      ),
    );
  }
}

/// Profile header band — centered avatar with trailing menu (Figma).
class ProfileFigmaAvatarHeaderRow extends StatelessWidget {
  const ProfileFigmaAvatarHeaderRow({
    super.key,
    required this.avatar,
    this.onMenuTap,
    this.rowHeight,
  });

  final Widget avatar;
  final VoidCallback? onMenuTap;
  final double? rowHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight ?? ProfileFigmaTokens.avatarOuterSize,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(alignment: Alignment.center, child: avatar),
          if (onMenuTap != null)
            Positioned(
              top: ProfileFigmaTokens.profileHeaderMenuTopInset,
              right: 0,
              child: ProfileFigmaHeaderMenuButton(onTap: onMenuTap!),
            ),
        ],
      ),
    );
  }
}

/// Hamburger menu beside the profile avatar row (Figma top-right).
class ProfileFigmaHeaderMenuButton extends StatelessWidget {
  const ProfileFigmaHeaderMenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.menu_rounded,
            size: 24,
            color: ProfileFigmaTokens.primaryText,
          ),
        ),
      ),
    );
  }
}

class ProfileFigmaStatChip extends StatelessWidget {
  const ProfileFigmaStatChip({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius =
        BorderRadius.circular(ProfileFigmaTokens.statChipRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: ProfileFigmaTokens.statChipWidth,
          height: ProfileFigmaTokens.statChipHeight,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.statChipBackground,
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.profileStatValue,
              ),
              SizedBox(height: ProfileFigmaTokens.statChipValueLabelGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.profileStatChipLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Posts / Followers / Following row (Figma 85×55 chips, 12px gap).
class ProfileFigmaStatChipsRow extends StatelessWidget {
  const ProfileFigmaStatChipsRow({
    super.key,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final String postCount;
  final String followerCount;
  final String followingCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileFigmaStatChip(
          label: 'Posts',
          value: postCount,
        ),
        const SizedBox(width: ProfileFigmaTokens.statChipGap),
        ProfileFigmaStatChip(
          label: 'Followers',
          value: followerCount,
          onTap: onFollowersTap,
        ),
        const SizedBox(width: ProfileFigmaTokens.statChipGap),
        ProfileFigmaStatChip(
          label: 'Following',
          value: followingCount,
          onTap: onFollowingTap,
        ),
      ],
    );
  }
}

/// Edit Profile — Figma pill 146×40 #1C1C1C + white label.
class ProfileFigmaActionButton extends StatelessWidget {
  const ProfileFigmaActionButton({
    super.key,
    required this.onPressed,
    this.label = 'Edit Profile',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final radius =
        BorderRadius.circular(ProfileFigmaTokens.actionButtonRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          width: ProfileFigmaTokens.actionButtonWidth,
          height: ProfileFigmaTokens.actionButtonHeight,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.actionButtonFill,
            borderRadius: radius,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.profileActionButtonLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular secondary action (Share, Story+) — #E9E8E7 via SVG or fallback.
class ProfileFigmaIconActionButton extends StatelessWidget {
  const ProfileFigmaIconActionButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.iconAssetPath,
    this.svgAssetPath,
  });

  final VoidCallback onPressed;
  final IconData? icon;
  final String? iconAssetPath;
  final String? svgAssetPath;

  @override
  Widget build(BuildContext context) {
    final size = ProfileFigmaTokens.actionIconButtonSize;

    if (svgAssetPath != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SvgPicture.asset(
            svgAssetPath!,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.secondaryActionFill,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: iconAssetPath != null
                ? Image.asset(
                    iconAssetPath!,
                    width: ProfileFigmaTokens.actionIconSize,
                    height: ProfileFigmaTokens.actionIconSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    color: ProfileFigmaTokens.primaryText,
                  )
                : Icon(
                    icon ?? Icons.add_rounded,
                    size: ProfileFigmaTokens.actionIconSize,
                    color: ProfileFigmaTokens.primaryText,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Own-profile action row — Edit Profile | Share | Story+ (Figma 338×40).
class ProfileFigmaActionButtonsRow extends StatelessWidget {
  const ProfileFigmaActionButtonsRow({
    super.key,
    required this.onEditProfile,
    required this.onShare,
    required this.onStory,
    this.editLabel = 'Edit Profile',
  });

  final VoidCallback onEditProfile;
  final VoidCallback onShare;
  final VoidCallback onStory;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ProfileFigmaTokens.profileActionRowMaxWidth,
        ),
        child: SizedBox(
          height: ProfileFigmaTokens.actionButtonHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileFigmaActionButton(
                onPressed: onEditProfile,
                label: editLabel,
              ),
              const SizedBox(width: ProfileFigmaTokens.actionButtonGap),
              ProfileFigmaIconActionButton(
                svgAssetPath: ProfileAssets.profileActionShare,
                onPressed: onShare,
              ),
              const SizedBox(width: ProfileFigmaTokens.actionButtonGap),
              ProfileFigmaIconActionButton(
                svgAssetPath: ProfileAssets.profileActionPlus,
                onPressed: onStory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileFigmaTabBar extends StatelessWidget {
  const ProfileFigmaTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.savedTabIndex,
    this.onSavedTap,
    this.onBookmarkTap,
    this.compact = false,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int? savedTabIndex;
  final VoidCallback? onSavedTap;
  final VoidCallback? onBookmarkTap;
  final bool compact;

  BoxDecoration _tabTrackDecoration({
    required double radius,
    required bool compact,
  }) {
    return BoxDecoration(
      color: ProfileFigmaTokens.tabTrack,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: compact ? null : ProfileFigmaTokens.tabBarElementShadow,
    );
  }

  BoxDecoration _accessoryDecoration({
    required double radius,
    required bool compact,
  }) {
    return BoxDecoration(
      color: ProfileFigmaTokens.tabAccessoryFill,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: compact ? null : ProfileFigmaTokens.tabBarElementShadow,
    );
  }

  Widget _accessoryButton({
    required String iconAsset,
    required VoidCallback onTap,
    required bool compact,
    required double iconWidth,
    required double iconHeight,
  }) {
    final size = compact ? 30.0 : ProfileFigmaTokens.tabAccessorySize;
    final radius =
        compact ? 10.0 : ProfileFigmaTokens.tabAccessoryRadius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: Colors.black.withValues(alpha: 0.08),
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: Container(
          width: size,
          height: size,
          decoration: _accessoryDecoration(radius: radius, compact: compact),
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: iconWidth,
              height: iconHeight,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final innerPad =
        compact ? 2.0 : ProfileFigmaTokens.tabBarInnerPadding;
    final trackHeight =
        compact ? 32.0 : ProfileFigmaTokens.tabBarTrackHeight;
    final trackRadius =
        compact ? AppRadius.pill : ProfileFigmaTokens.tabBarTrackRadius;
    final pillRadius = compact
        ? AppRadius.pill
        : ProfileFigmaTokens.tabSelectedPillRadius;
    final pillWidth =
        compact ? 56.0 : ProfileFigmaTokens.tabSelectedPillWidth;
    final pillHeight =
        compact ? 26.0 : ProfileFigmaTokens.tabSelectedPillHeight;
    final accessoryGap =
        compact ? 2.0 : ProfileFigmaTokens.tabBarAccessoryGap;
    final selectedTabFont =
        compact ? 13.0 : ProfileFigmaTokens.tabSelectedFontSize;
    final unselectedTabFont =
        compact ? 13.0 : ProfileFigmaTokens.tabUnselectedFontSize;
    final savedIndex = savedTabIndex;
    final isSavedSelected =
        savedIndex != null && selectedIndex == savedIndex;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact
              ? double.infinity
              : ProfileFigmaTokens.profileTabBarRowMaxWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                height: trackHeight,
                padding: EdgeInsets.all(innerPad),
                decoration: _tabTrackDecoration(
                  radius: trackRadius,
                  compact: compact,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(tabs.length, (index) {
                    final isSelected =
                        index == selectedIndex && !isSavedSelected;
                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTabSelected(index),
                          borderRadius: BorderRadius.circular(pillRadius),
                          splashColor: ProfileFigmaTokens.tabSelectedPillFill
                              .withValues(alpha: 0.12),
                          highlightColor:
                              ProfileFigmaTokens.tabSelectedPillFill
                                  .withValues(alpha: 0.08),
                          child: Align(
                            alignment: isSelected
                                ? Alignment.centerLeft
                                : Alignment.center,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              width: isSelected ? pillWidth : null,
                              height: isSelected ? pillHeight : null,
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: ProfileFigmaTokens
                                          .tabSelectedPillFill,
                                      borderRadius:
                                          BorderRadius.circular(pillRadius),
                                    )
                                  : null,
                              alignment: Alignment.center,
                              child: Text(
                                tabs[index],
                                style: isSelected
                                    ? AppTypography.profileTabSelectedLabel
                                        .copyWith(fontSize: selectedTabFont)
                                    : AppTypography.profileTabUnselectedLabel
                                        .copyWith(
                                          fontSize: unselectedTabFont,
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (onBookmarkTap != null) ...[
              SizedBox(width: accessoryGap),
              _accessoryButton(
                iconAsset: ProfileAssets.profileTabBookmarkIcon,
                onTap: onBookmarkTap!,
                compact: compact,
                iconWidth: compact
                    ? 14.0
                    : ProfileFigmaTokens.tabBookmarkIconSize,
                iconHeight: compact
                    ? 14.0
                    : ProfileFigmaTokens.tabBookmarkIconSize,
              ),
            ],
            if (savedIndex != null && onSavedTap != null) ...[
              SizedBox(width: accessoryGap),
              _accessoryButton(
                iconAsset: ProfileAssets.profileTabHeartIcon,
                onTap: onSavedTap!,
                compact: compact,
                iconWidth: compact
                    ? 13.0
                    : ProfileFigmaTokens.tabHeartIconWidth,
                iconHeight: compact
                    ? 12.0
                    : ProfileFigmaTokens.tabHeartIconHeight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Left-aligns [child] with the Feed pill / highlights column.
class ProfileContentColumnAlign extends StatelessWidget {
  const ProfileContentColumnAlign({
    super.key,
    required this.child,
    this.reserveTabAccessories = false,
    this.alignWithFeedPill = false,
  });

  final Widget child;
  final bool reserveTabAccessories;
  /// Nudge right by tab-track inner pad so left edge matches Feed black pill.
  final bool alignWithFeedPill;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (alignWithFeedPill) {
      content = Padding(
        padding: const EdgeInsets.only(
          left: ProfileFigmaTokens.profileHighlightsLeftInset,
        ),
        child: content,
      );
    }

    if (!reserveTabAccessories) {
      return Align(alignment: Alignment.centerLeft, child: content);
    }

    final accessoryWidth = ProfileFigmaTokens.tabAccessoryWidth;
    final accessoryGap = ProfileFigmaTokens.tabBarAccessoryGap;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Align(alignment: Alignment.centerLeft, child: content),
        ),
        SizedBox(width: accessoryGap),
        SizedBox(width: accessoryWidth),
        SizedBox(width: accessoryGap),
        SizedBox(width: accessoryWidth),
      ],
    );
  }
}

/// Lays out [child] in the tab-track column of [ProfileFigmaTabBar].
/// When [alignWithPostsStart] is true, content begins under the Posts tab label.
class ProfileTabTrackRow extends StatelessWidget {
  const ProfileTabTrackRow({
    super.key,
    required this.child,
    this.showBookmarkAccessory = false,
    this.showStarAccessory = false,
    this.alignWithPostsStart = false,
  });

  final Widget child;
  final bool showBookmarkAccessory;
  final bool showStarAccessory;
  final bool alignWithPostsStart;

  @override
  Widget build(BuildContext context) {
    final accessoryWidth = ProfileFigmaTokens.tabAccessoryWidth;
    final outerPad = ProfileFigmaTokens.tabBarOuterPadding;

    final Widget trackChild;
    if (alignWithPostsStart) {
      trackChild = child;
    } else {
      trackChild = Padding(
        padding: EdgeInsets.symmetric(horizontal: outerPad),
        child: child,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: trackChild),
        if (showBookmarkAccessory) ...[
          SizedBox(width: ProfileFigmaTokens.tabBarAccessoryGap),
          SizedBox(width: accessoryWidth),
        ],
        if (showStarAccessory) ...[
          SizedBox(width: ProfileFigmaTokens.tabBarAccessoryGap),
          SizedBox(width: accessoryWidth),
        ],
      ],
    );
  }
}

/// Aligns [child] under the first tab (Posts) matching [ProfileFigmaTabBar] layout.
class ProfileTabUnderFirstTab extends StatelessWidget {
  const ProfileTabUnderFirstTab({
    super.key,
    required this.tabCount,
    required this.child,
    this.showBookmarkAccessory = false,
    this.showStarAccessory = false,
    this.compact = false,
  });

  final int tabCount;
  final Widget child;
  final bool showBookmarkAccessory;
  final bool showStarAccessory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accessoryWidth =
        compact ? 30.0 : ProfileFigmaTokens.tabAccessoryWidth;
    final outerPad =
        compact ? 2.0 : ProfileFigmaTokens.tabBarOuterPadding;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: outerPad),
            child: Row(
              children: [
                Expanded(child: child),
                ...List.generate(
                  tabCount - 1,
                  (_) => const Expanded(child: SizedBox.shrink()),
                ),
              ],
            ),
          ),
        ),
        if (showBookmarkAccessory) ...[
          SizedBox(width: ProfileFigmaTokens.tabBarAccessoryGap),
          SizedBox(width: accessoryWidth),
        ],
        if (showStarAccessory) ...[
          SizedBox(width: ProfileFigmaTokens.tabBarAccessoryGap),
          SizedBox(width: accessoryWidth),
        ],
      ],
    );
  }
}

/// Highlights row opener — Figma 68×19 #1A1A1A tab with white chevron.
class ProfileHighlightsToggleHandle extends StatelessWidget {
  const ProfileHighlightsToggleHandle({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  static final BorderRadius _radius = BorderRadius.vertical(
    top: Radius.circular(ProfileFigmaTokens.highlightsToggleTopRadius),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ProfileFigmaTokens.highlightsToggleWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _radius,
          child: Container(
            height: ProfileFigmaTokens.highlightsToggleHeight,
            decoration: BoxDecoration(
              color: ProfileFigmaTokens.highlightsToggleFill,
              borderRadius: _radius,
            ),
            child: Center(
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: ProfileFigmaTokens.profileHighlightsAnimation,
                curve: Curves.easeInOutCubic,
                child: SvgPicture.asset(
                  ProfileAssets.profileHighlightsOpenerChevron,
                  width: ProfileFigmaTokens.highlightsToggleChevronWidth,
                  height: ProfileFigmaTokens.highlightsToggleChevronHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible highlights block — height + chevron animate open/close (260ms).
class ProfileHighlightsExpandableSection extends StatelessWidget {
  const ProfileHighlightsExpandableSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.highlights,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final Widget highlights;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: ProfileFigmaTokens.profileHighlightsAnimation,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: ProfileFigmaTokens.profileHighlightsAnimation,
            curve: Curves.easeInOutCubic,
            height: expanded
                ? ProfileFigmaTokens.highlightsSectionTopGap
                : ProfileFigmaTokens.highlightsToggleTopGap,
          ),
          if (expanded) ...[
            highlights,
            const SizedBox(
              height: ProfileFigmaTokens.highlightsToggleTopGap,
            ),
          ],
          ProfileContentColumnAlign(
            reserveTabAccessories: true,
            alignWithFeedPill: true,
            child: ProfileHighlightsToggleHandle(
              expanded: expanded,
              onTap: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark "+" tile with "Highlights" label underneath (Figma 68×85).
class ProfileHighlightAddChip extends StatelessWidget {
  const ProfileHighlightAddChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius =
        BorderRadius.circular(ProfileFigmaTokens.highlightTileRadius);

    return SizedBox(
      width: ProfileFigmaTokens.highlightTileWidth,
      height: ProfileFigmaTokens.highlightRowHeight,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: ClipRRect(
                borderRadius: radius,
                child: SvgPicture.asset(
                  ProfileAssets.profileHighlightAddTile,
                  width: ProfileFigmaTokens.highlightTileWidth,
                  height: ProfileFigmaTokens.highlightTileHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: ProfileFigmaTokens.highlightLabelGap),
          SizedBox(
            height: ProfileFigmaTokens.highlightLabelAreaHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                'Highlights',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.profileHighlightAddLabel.copyWith(
                  color: ProfileFigmaTokens.highlightAddLabelColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Own-profile avatar + centered display name — height matches side drawer (150).
class ProfileFigmaAvatarNameBand extends StatelessWidget {
  const ProfileFigmaAvatarNameBand({
    super.key,
    required this.avatar,
    required this.displayName,
    required this.isVerified,
    this.badgeColor = ProfileFigmaTokens.verifiedBadgeGreen,
    this.onMenuTap,
  });

  final Widget avatar;
  final String displayName;
  final bool isVerified;
  final Color badgeColor;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProfileFigmaTokens.profileAvatarNameBandHeight,
      child: Column(
        children: [
          ProfileFigmaAvatarHeaderRow(
            rowHeight: ProfileFigmaTokens.profileHeaderAvatarSize,
            onMenuTap: onMenuTap,
            avatar: avatar,
          ),
          const SizedBox(
            height: ProfileFigmaTokens.profileHeaderAvatarNameGap,
          ),
          ProfileFigmaDisplayNameRow(
            displayName: displayName,
            isVerified: isVerified,
            badgeColor: badgeColor,
          ),
        ],
      ),
    );
  }
}

class ProfileFigmaDisplayNameRow extends StatelessWidget {
  const ProfileFigmaDisplayNameRow({
    super.key,
    required this.displayName,
    required this.isVerified,
    this.badgeColor = ProfileFigmaTokens.verifiedBadgeGreen,
  });

  final String displayName;
  final bool isVerified;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProfileFigmaTokens.displayNameRowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.profileDisplayName,
          ),
          if (isVerified) ...[
            const SizedBox(width: ProfileFigmaTokens.nameVerifiedGap),
            ProfileFigmaVerifiedBadge(color: badgeColor),
          ],
        ],
      ),
    );
  }
}

/// Verification badge beside the profile display name (Figma 16.67px).
class ProfileFigmaVerifiedBadge extends StatelessWidget {
  const ProfileFigmaVerifiedBadge({super.key, required this.color});

  final Color color;

  bool get _usesFigmaAsset => color == ProfileFigmaTokens.verifiedBadgeGreen;

  @override
  Widget build(BuildContext context) {
    final size = ProfileFigmaTokens.verifiedBadgeSize;
    if (_usesFigmaAsset) {
      return SvgPicture.asset(
        ProfileAssets.profileVerifiedBadge,
        width: size,
        height: size,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 10,
        color: Colors.white,
      ),
    );
  }
}

/// Figma other-user profile top bar: avatar, name, handle, follow chip, close.
class OtherUserProfileTopBar extends StatelessWidget {
  const OtherUserProfileTopBar({
    super.key,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.followLabel,
    required this.followOutlined,
    required this.followBusy,
    required this.onFollowTap,
    required this.onClose,
  });

  final String displayName;
  final String username;
  final String avatarUrl;
  final String followLabel;
  final bool followOutlined;
  final bool followBusy;
  final VoidCallback onFollowTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        top + AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: ProfileFigmaTokens.otherUserHeaderAvatarRadius,
            backgroundColor: ProfileFigmaTokens.cardBackground,
            backgroundImage: ProfileFigmaAvatar.isValidNetworkUrl(avatarUrl)
                ? NetworkImage(avatarUrl)
                : null,
            child: !ProfileFigmaAvatar.isValidNetworkUrl(avatarUrl)
                ? Icon(
                    Icons.person_rounded,
                    size: ProfileFigmaTokens.otherUserHeaderAvatarRadius,
                    color: ProfileFigmaTokens.secondaryText.withValues(alpha: 0.5),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: ProfileFigmaTokens.primaryText,
                    fontSize: ProfileFigmaTokens.otherUserHeaderNameFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${ProfileFigmaTokens.displayUsername(username)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: ProfileFigmaTokens.otherUserHeaderHandleColor,
                    fontSize: ProfileFigmaTokens.otherUserHeaderHandleFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ProfileFigmaHeaderFollowChip(
            label: followLabel,
            outlined: followOutlined,
            busy: followBusy,
            onTap: followBusy ? () {} : onFollowTap,
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              size: 22,
              color: ProfileFigmaTokens.secondaryText,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

/// Outlined "Following" / filled "Follow" chip for profile header.
class ProfileFigmaHeaderFollowChip extends StatelessWidget {
  const ProfileFigmaHeaderFollowChip({
    super.key,
    required this.label,
    required this.outlined,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool outlined;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : AppColors.brandPink,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: outlined
                ? Border.all(
                    color: ProfileFigmaTokens.profileFollowingBorder,
                    width: 1,
                  )
                : null,
          ),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ProfileFigmaTokens.primaryText,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    color: outlined
                        ? ProfileFigmaTokens.primaryText
                        : Colors.white,
                    fontSize: ProfileFigmaTokens.otherUserHeaderFollowFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Profile bio — Figma 16px / #808080, centered; collapses to 30 chars + See more.
class ProfileBioText extends StatefulWidget {
  const ProfileBioText({
    super.key,
    required this.bio,
    this.textAlign = TextAlign.center,
  });

  final String bio;
  final TextAlign textAlign;

  @override
  State<ProfileBioText> createState() => _ProfileBioTextState();
}

class _ProfileBioTextState extends State<ProfileBioText> {
  bool _expanded = false;

  String _bioUpTo(int maxChars, String raw) {
    if (raw.length <= maxChars) return raw;
    return raw.substring(0, maxChars);
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.bio.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final collapsedLen = ProfileFigmaTokens.profileBioCollapsedLength;
    final expandedLen = ProfileFigmaTokens.profileBioMaxDisplayLength;
    final needsExpand = raw.length > collapsedLen;

    if (!needsExpand) {
      return Text(
        raw,
        textAlign: widget.textAlign,
        style: AppTypography.profileBio,
      );
    }

    if (_expanded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _bioUpTo(expandedLen, raw),
            textAlign: widget.textAlign,
            style: AppTypography.profileBio,
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'See less',
                textAlign: widget.textAlign,
                style: AppTypography.profileBioSeeMore,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _bioUpTo(collapsedLen, raw),
          textAlign: widget.textAlign,
          style: AppTypography.profileBio,
        ),
        GestureDetector(
          onTap: () => setState(() => _expanded = true),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'See more',
              textAlign: widget.textAlign,
              style: AppTypography.profileBioSeeMore,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileFigmaMusicLine extends StatelessWidget {
  const ProfileFigmaMusicLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.play_circle_outline_rounded,
          size: ProfileFigmaTokens.profileBioMusicIconSize,
          color: ProfileFigmaTokens.profileBioMusicColor,
        ),
        const SizedBox(width: ProfileFigmaTokens.profileBioMusicIconGap),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.profileMusicLine,
          ),
        ),
      ],
    );
  }
}

/// Bio + profile music block (Figma 338×64 max).
class ProfileFigmaBioMusicSection extends StatelessWidget {
  const ProfileFigmaBioMusicSection({
    super.key,
    required this.bio,
    required this.musicLabel,
  });

  final String bio;
  final String musicLabel;

  @override
  Widget build(BuildContext context) {
    final bioText = bio.trim();
    final musicText = musicLabel.trim();
    if (bioText.isEmpty && musicText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ProfileFigmaTokens.profileBioMusicMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bioText.isNotEmpty) ProfileBioText(bio: bioText),
            if (bioText.isNotEmpty && musicText.isNotEmpty)
              const SizedBox(height: ProfileFigmaTokens.profileBioMusicGap),
            if (musicText.isNotEmpty)
              ProfileFigmaMusicLine(label: musicText),
          ],
        ),
      ),
    );
  }
}

/// Left-edge drawer rail — collapsed 12px peek → expanded 43px with icons.
class ProfileSideDrawer extends StatefulWidget {
  const ProfileSideDrawer({
    super.key,
    required this.onWalletTap,
    required this.onChatTap,
    required this.onRevenueTap,
  });

  final VoidCallback onWalletTap;
  final VoidCallback onChatTap;
  final VoidCallback onRevenueTap;

  @override
  State<ProfileSideDrawer> createState() => _ProfileSideDrawerState();
}

class _ProfileSideDrawerState extends State<ProfileSideDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOrigin = 0;

  static const List<double> _iconCenterYs = <double>[33, 75, 118];

  static double get _expandedWidth => ProfileFigmaTokens.profileSideRailWidth;

  static double get _collapsedWidth =>
      ProfileFigmaTokens.profileSideRailCollapsedWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ProfileFigmaTokens.profileSideDrawerAnimation,
      value: 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isExpanded => _controller.value >= 0.5;

  void _toggle() {
    if (_isExpanded) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _onDragStart(DragStartDetails details) {
    _dragOrigin = _controller.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final travel = _expandedWidth - _collapsedWidth;
    if (travel <= 0) return;
    _controller.value = (_dragOrigin + delta / travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 280) {
      if (velocity > 0) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      return;
    }
    if (_controller.value >= 0.5) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = ProfileFigmaTokens.profileSideRailHeight;
    final tapHeight = ProfileFigmaTokens.profileSideRailTapHeight;
    final callbacks = <VoidCallback>[
      widget.onWalletTap,
      widget.onChatTap,
      widget.onRevenueTap,
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final outerWidth =
            _collapsedWidth + (_expandedWidth - _collapsedWidth) * t;
        final iconOpacity = t.clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onTap: t < 0.85 ? _toggle : null,
          behavior: HitTestBehavior.translucent,
          child: SizedBox(
            width: outerWidth,
            height: height,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.hardEdge,
                children: [
                  Opacity(
                    opacity: 1 - iconOpacity,
                    child: SvgPicture.asset(
                      ProfileAssets.profileSideDrawerCollapsed,
                      width: _collapsedWidth,
                      height: height,
                      fit: BoxFit.fill,
                    ),
                  ),
                  SizedBox(
                    width: _expandedWidth,
                    height: height,
                    child: Opacity(
                      opacity: iconOpacity,
                      child: Stack(
                        children: [
                          SvgPicture.asset(
                            ProfileAssets.profileSideDrawer,
                            width: _expandedWidth,
                            height: height,
                            fit: BoxFit.fill,
                          ),
                          IgnorePointer(
                            ignoring: t < 0.85,
                            child: Stack(
                              children: [
                                for (var i = 0; i < callbacks.length; i++)
                                  Positioned(
                                    top: _iconCenterYs[i] - tapHeight / 2,
                                    left: 0,
                                    width: _expandedWidth,
                                    height: tapHeight,
                                    child: _ProfileSideDrawerTapZone(
                                      onTap: callbacks[i],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSideDrawerTapZone extends StatelessWidget {
  const _ProfileSideDrawerTapZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: ProfileFigmaTokens.sideDrawerIconColor.withValues(
          alpha: 0.12,
        ),
        highlightColor: ProfileFigmaTokens.sideDrawerIconColor.withValues(
          alpha: 0.08,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
