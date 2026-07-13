import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/bottom_nav_assets.dart';
import '../platform/app_system_ui.dart';
import '../theme/app_fonts.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/bottom_nav_figma_tokens.dart';
import 'bottom_nav_create_menu.dart';
import 'feed_reel_progress_bar.dart';
import 'live_feed_scrub_preview.dart';
import 'live_feed_stream_progress_bar.dart';
import '../../screens/profile/profile_figma_tokens.dart';

/// Custom bottom nav wrapper matching the VyooO design language.
/// Index: 0 Home, 1 Go Live (broadcast), 2 Create (+), 3 Messages, 4 Profile.
/// Search is opened from the home feed header / hashtag links, not this tab.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
    this.unreadNotificationCount = 0,
    this.unreadChatCount = 0,
    this.useFeedChrome = false,
    this.feedReelProgress,
    this.feedLiveProgress,
    this.onFeedReelSeekUpdate,
    this.onFeedLiveSeekUpdate,
    this.onFeedLiveSeekStart,
    this.onFeedLiveSeekEnd,
    this.feedLiveScrubbing,
    this.feedLiveSeekPreviewBytes,
    this.feedLiveSeekPreviewTimeLabel,
    this.feedLiveSeekPreviewFallbackUrl,
    this.squareChromeBottomCorners = false,
    this.isCreateMenuOpen = false,
    this.createMenuProgress = 0,
    this.onCreateMenuToggle,
    this.onCreateAction,
  });

  final int currentIndex;
  final void Function(int) onTap;
  final String? profileImageUrl;
  final int unreadNotificationCount;
  final int unreadChatCount;

  /// Dark chrome + gradient scrim companion — home feed tab only.
  final bool useFeedChrome;

  /// Home reel progress (0–1). When non-null, renders full-bleed bar atop chrome.
  final ValueListenable<double?>? feedReelProgress;

  /// Broadcast live progress (0–1 live edge). When non-null, live stream bar atop chrome.
  final ValueListenable<double?>? feedLiveProgress;

  /// Scrub updates from the home reel chrome progress bar.
  final ValueChanged<double>? onFeedReelSeekUpdate;

  /// Scrub updates from the broadcast live chrome progress bar.
  final ValueChanged<double>? onFeedLiveSeekUpdate;

  /// Called when the user starts scrubbing the live progress bar.
  final VoidCallback? onFeedLiveSeekStart;

  /// Called when the user stops scrubbing the live progress bar.
  final VoidCallback? onFeedLiveSeekEnd;

  /// Live scrub state for preview thumbnail overlay.
  final ValueListenable<bool>? feedLiveScrubbing;
  final ValueListenable<Uint8List?>? feedLiveSeekPreviewBytes;
  final ValueListenable<String?>? feedLiveSeekPreviewTimeLabel;
  final ValueListenable<String?>? feedLiveSeekPreviewFallbackUrl;

  /// When true, bottom chrome uses square corners (broadcast tab).
  final bool squareChromeBottomCorners;

  /// Plus menu expanded — shows close (X) icon and [BottomNavCreateMenu].
  final bool isCreateMenuOpen;

  /// Animated open progress (`0`–`1`) for the create menu stack.
  final double createMenuProgress;

  /// Toggles the create hub menu (plus ↔ close).
  final VoidCallback? onCreateMenuToggle;

  /// VR / Post / Reel / Story / Live picks from the create menu.
  final ValueChanged<BottomNavCreateAction>? onCreateAction;

  static const Color _iconColor = ProfileFigmaTokens.primaryText;
  static const Color _navBarFill = BottomNavFigmaTokens.pillFill;
  static const Color _splashColor = Color(0x33750047);

  static const double _tapTargetSize = AppSizes.bottomNavTapTarget;

  Widget _buildProfileIcon(bool isSelected) {
    final size = AppSizes.bottomNavProfileIcon;
    final borderWidth =
        isSelected ? BottomNavFigmaTokens.profileAvatarBorderWidth : 0.0;
    final photoSize = size - borderWidth * 2;

    final Widget photo;
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;
    if (!hasProfileImage) {
      photo = _NavIconImage(
        assetPath: isSelected
            ? BottomNavAssets.profileSelected
            : BottomNavAssets.profileUnselected,
        size: photoSize,
      );
    } else {
      photo = ClipOval(
        child: Image.network(
          profileImageUrl!,
          fit: BoxFit.cover,
          width: photoSize,
          height: photoSize,
          errorBuilder: (_, error, stackTrace) => Image.asset(
            BottomNavAssets.profileDefault,
            fit: BoxFit.cover,
            width: photoSize,
            height: photoSize,
            errorBuilder: (_, error1, stack1) => Icon(
              Icons.person_rounded,
              size: photoSize * 0.7,
              color: _iconColor,
            ),
          ),
        ),
      );
    }

    if (!isSelected) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: photo),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: BottomNavFigmaTokens.profileAvatarBorderColor,
          width: borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: ClipOval(child: photo),
    );
  }

  Widget _buildNavTap({
    required VoidCallback onPressed,
    required Widget child,
    double? tapTargetSize,
  }) {
    final targetSize = tapTargetSize ?? _tapTargetSize;
    return SizedBox(
      width: targetSize,
      height: targetSize,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          radius: targetSize / 2,
          splashColor: _splashColor,
          highlightColor: _splashColor.withValues(alpha: 0.5),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildChatIcon(bool isSelected) {
    final count = unreadChatCount < 0 ? 0 : unreadChatCount;
    final showBadge = count > 0;
    final label = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: AppSizes.bottomNavIconSlot,
      height: AppSizes.bottomNavIconSlot,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _NavSvgIcon(
            assetPath: isSelected
                ? BottomNavAssets.chatSelected
                : BottomNavAssets.chatUnselected,
            width: isSelected ? 24 : 20,
            height: isSelected ? 24 : 20,
          ),
          if (showBadge)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _navBarFill, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nav icons + artwork height (excludes Android/iOS system nav inset).
  static const double barHeight = AppSizes.bottomNavBarHeight;

  /// Horizontal margin for the floating pill bar inside the chrome.
  static const double _horizontalMargin = BottomNavFigmaTokens.horizontalMargin;

  /// Space above the white pill inside the dark chrome strip (matches progress top gap).
  static const double _chromeTopPadding = AppSpacing.feedPostNavGap;

  /// iOS-only: fraction of the home-indicator inset below the bar (0.5 = floating pill look).
  static const double _iosSafeAreaBottomFactor = 0.5;

  /// Home reel progress band inside feed chrome (gap → 3px bar → gap).
  static double feedReelProgressBandHeight() =>
      AppSpacing.feedReelProgressTopGap +
      AppSizes.liveFeedStreamProgressHeight +
      AppSizes.liveFeedProgressToBottomNavGap;

  /// Broadcast live progress band — top gap → 3px bar → gap → nav.
  static double feedLiveProgressBandHeight() =>
      AppSpacing.feedReelProgressTopGap +
      AppSizes.liveFeedStreamProgressHeight +
      AppSizes.liveFeedProgressToBottomNavGap;

  /// Bottom nav height for overlay positioning.
  static double totalHeightFor(
    BuildContext context, {
    bool feedChrome = false,
    bool includeReelProgressBand = false,
    bool liveProgressBand = false,
  }) {
    final bottomInset = AppSystemUi.bottomChromeInset(
      context,
      iosInsetFactor: _iosSafeAreaBottomFactor,
    );
    final progressBand = feedChrome && includeReelProgressBand
        ? (liveProgressBand
            ? feedLiveProgressBandHeight()
            : feedReelProgressBandHeight())
        : 0.0;
    final chromeTop =
        feedChrome && !includeReelProgressBand ? _chromeTopPadding : 0.0;
    return progressBand + chromeTop + barHeight + bottomInset;
  }

  BoxDecoration get _pillDecoration => BoxDecoration(
        color: _navBarFill,
        borderRadius: BorderRadius.circular(BottomNavFigmaTokens.pillRadius),
        boxShadow: BottomNavFigmaTokens.pillShadow,
      );

  Widget _buildCreateMenuStack() {
    final onAction = onCreateAction;
    if (onAction == null || createMenuProgress <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: BottomNavFigmaTokens.createMenuToNavGap,
      ),
      child: BottomNavCreateMenu(
        progress: createMenuProgress,
        onAction: onAction,
      ),
    );
  }

  Widget _buildNavRow() {
    final createOpen = isCreateMenuOpen;
    return SizedBox(
      height: barHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            unselectedAsset: BottomNavAssets.homeUnselected,
            selectedAsset: BottomNavAssets.homeSelected,
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
            buildTap: _buildNavTap,
            iconWidth: currentIndex == 0 ? 28 : 24,
            iconHeight: currentIndex == 0 ? 28 : 24,
          ),
          _NavItem(
            unselectedAsset: BottomNavAssets.broadcastUnselected,
            selectedAsset: BottomNavAssets.broadcastSelected,
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
            buildTap: _buildNavTap,
            iconWidth: 32,
            iconHeight: 27,
            iconOffsetY: BottomNavFigmaTokens.broadcastIconOpticalOffsetY,
          ),
          _NavItem(
            unselectedAsset: BottomNavAssets.addUnselected,
            selectedAsset: BottomNavAssets.addSelected,
            isSelected: createOpen,
            onTap: onCreateMenuToggle ?? () => onTap(2),
            buildTap: _buildNavTap,
            iconWidth: createOpen ? 30 : 20,
            iconHeight: createOpen ? 30 : 20,
          ),
          _NavItem(
            isSelected: currentIndex == 3,
            onTap: () => onTap(3),
            buildTap: _buildNavTap,
            customChild: _buildChatIcon(currentIndex == 3),
          ),
          _buildNavTap(
            onPressed: () => onTap(4),
            tapTargetSize: AppSizes.bottomNavProfileIcon,
            child: _buildProfileIcon(currentIndex == 4),
          ),
        ],
      ),
    );
  }

  Widget _buildNavChromeBody({
    required double bottomInset,
    required bool includeTopPadding,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _buildCreateMenuStack()),
        Padding(
          padding: EdgeInsets.fromLTRB(
            _horizontalMargin,
            includeTopPadding ? _chromeTopPadding : 0,
            _horizontalMargin,
            bottomInset,
          ),
          child: DecoratedBox(
            decoration: _pillDecoration,
            child: _buildNavRow(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingPill(double bottomInset) {
    return _buildNavChromeBody(
      bottomInset: bottomInset,
      includeTopPadding: false,
    );
  }

  Widget _buildChromeProgressBar({
    required double progress,
    required bool isLive,
    bool showLiveScrubThumb = false,
  }) {
    if (isLive) {
      return LiveFeedStreamProgressBar(
        progress: progress,
        showScrubThumb: showLiveScrubThumb,
      );
    }
    return FeedReelProgressBar(progress: progress);
  }

  Widget _buildProgressScrubBand({
    required Widget progressBar,
    ValueChanged<double>? onSeekUpdate,
    VoidCallback? onSeekStart,
    VoidCallback? onSeekEnd,
    bool isLive = false,
    double progress = 0,
    bool showLivePreview = false,
    Uint8List? previewBytes,
    String? previewTimeLabel,
    String? previewFallbackUrl,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final clamped = progress.clamp(0.0, 1.0);
        final previewWidth = AppSizes.liveFeedScaleW(
          context,
          AppSizes.liveFeedSeekPreviewWidth,
        );
        final previewGap = AppSizes.liveFeedScaleH(
          context,
          AppSizes.liveFeedSeekPreviewToBarGap,
        );
        final thumbCenterX = width > 0
            ? (width * clamped).clamp(previewWidth / 2, width - previewWidth / 2)
            : previewWidth / 2;
        final previewLeft = thumbCenterX - previewWidth / 2;

        void handleSeek(double localX) {
          if (width <= 0) return;
          onSeekUpdate?.call((localX / width).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => onSeekStart?.call(),
          onHorizontalDragUpdate: (details) {
            handleSeek(details.localPosition.dx);
          },
          onHorizontalDragEnd: (_) => onSeekEnd?.call(),
          onHorizontalDragCancel: () => onSeekEnd?.call(),
          onTapDown: (details) {
            onSeekStart?.call();
            handleSeek(details.localPosition.dx);
            onSeekEnd?.call();
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (isLive && showLivePreview && previewTimeLabel != null)
                Positioned(
                  left: previewLeft,
                  bottom: AppSpacing.feedReelProgressTopGap +
                      AppSizes.liveFeedStreamProgressHeight +
                      AppSizes.liveFeedProgressToBottomNavGap +
                      previewGap,
                  child: LiveFeedScrubPreview(
                    timeLabel: previewTimeLabel,
                    imageBytes: previewBytes,
                    fallbackImageUrl: previewFallbackUrl,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.feedReelProgressTopGap),
                  progressBar,
                  const SizedBox(height: AppSizes.liveFeedProgressToBottomNavGap),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedChromePill(double bottomInset) {
    final reelProgressListenable = feedReelProgress;
    final liveProgressListenable = feedLiveProgress;
    final hasChromeProgress =
        reelProgressListenable != null || liveProgressListenable != null;
    final chromeBottomRadius = squareChromeBottomCorners
        ? BorderRadius.zero
        : AppRadius.feedBottomChromeRadius;

    return ClipRRect(
      borderRadius: chromeBottomRadius,
      clipBehavior: Clip.none,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.feedBottomNavChrome,
          borderRadius: chromeBottomRadius,
          border: const Border(
            top: BorderSide(
              color: Color(0x1AFFFFFF),
              width: 0.5,
            ),
          ),
        ),
        child: !hasChromeProgress
            ? _buildNavChromeBody(
                bottomInset: bottomInset,
                includeTopPadding: true,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _buildCreateMenuStack()),
                  if (reelProgressListenable != null)
                    ValueListenableBuilder<double?>(
                      valueListenable: reelProgressListenable,
                      builder: (context, progress, _) {
                        return _buildProgressScrubBand(
                          onSeekUpdate: onFeedReelSeekUpdate,
                          progressBar: _buildChromeProgressBar(
                            progress: progress ?? 0,
                            isLive: false,
                          ),
                        );
                      },
                    )
                  else if (liveProgressListenable != null)
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        liveProgressListenable,
                        ?feedLiveScrubbing,
                        ?feedLiveSeekPreviewBytes,
                        ?feedLiveSeekPreviewTimeLabel,
                        ?feedLiveSeekPreviewFallbackUrl,
                      ]),
                      builder: (context, _) {
                        final progress = liveProgressListenable.value ?? 1;
                        final isScrubbing = feedLiveScrubbing?.value ?? false;
                        return _buildProgressScrubBand(
                          isLive: true,
                          progress: progress,
                          showLivePreview: isScrubbing,
                          previewBytes: feedLiveSeekPreviewBytes?.value,
                          previewTimeLabel:
                              feedLiveSeekPreviewTimeLabel?.value,
                          previewFallbackUrl:
                              feedLiveSeekPreviewFallbackUrl?.value,
                          onSeekStart: onFeedLiveSeekStart,
                          onSeekEnd: onFeedLiveSeekEnd,
                          onSeekUpdate: onFeedLiveSeekUpdate,
                          progressBar: _buildChromeProgressBar(
                            progress: progress,
                            isLive: true,
                            showLiveScrubThumb: isScrubbing,
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _horizontalMargin,
                      0,
                      _horizontalMargin,
                      bottomInset,
                    ),
                    child: DecoratedBox(
                      decoration: _pillDecoration,
                      child: _buildNavRow(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppSystemUi.bottomChromeInset(
      context,
      iosInsetFactor: _iosSafeAreaBottomFactor,
    );

    // Home/broadcast dark chrome wraps the menu in a black strip — use the light
    // floating pill while the create hub is open (matches profile/chat).
    final createMenuVisible = isCreateMenuOpen || createMenuProgress > 0;
    if (useFeedChrome && !createMenuVisible) {
      return _buildFeedChromePill(bottomInset);
    }
    return _buildFloatingPill(bottomInset);
  }
}

typedef _NavTapBuilder = Widget Function({
  required VoidCallback onPressed,
  required Widget child,
  double? tapTargetSize,
});

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.unselectedAsset,
    this.selectedAsset,
    required this.isSelected,
    required this.onTap,
    required this.buildTap,
    this.customChild,
    this.iconWidth = AppSizes.bottomNavIconSlot,
    this.iconHeight = AppSizes.bottomNavIconSlot,
    this.iconOffsetY = 0,
  });

  final String? unselectedAsset;
  final String? selectedAsset;
  final bool isSelected;
  final VoidCallback onTap;
  final _NavTapBuilder buildTap;
  final Widget? customChild;
  final double iconWidth;
  final double iconHeight;
  final double iconOffsetY;

  @override
  Widget build(BuildContext context) {
    final icon = customChild ??
        _NavSvgIcon(
          assetPath: isSelected ? selectedAsset! : unselectedAsset!,
          width: iconWidth,
          height: iconHeight,
          offsetY: iconOffsetY,
        );

    return buildTap(
      onPressed: onTap,
      child: icon,
    );
  }
}

class _NavIconImage extends StatelessWidget {
  const _NavIconImage({
    required this.assetPath,
    this.size = AppSizes.bottomNavIconSlot,
  });

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _NavSvgIcon extends StatelessWidget {
  const _NavSvgIcon({
    required this.assetPath,
    this.width = AppSizes.bottomNavIconSlot,
    this.height = AppSizes.bottomNavIconSlot,
    this.offsetY = 0,
  });

  final String assetPath;
  final double width;
  final double height;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    final slot = AppSizes.bottomNavIconSlot;
    return SizedBox(
      width: slot,
      height: slot,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, offsetY),
          child: SizedBox(
            width: width,
            height: height,
            child: SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }
}
