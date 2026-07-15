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

  // TEST: inverted bottom nav — revert before release.
  static const Color _iconColor = Colors.white;
  static const Color _navBarFill = Colors.black;
  static const Color _splashColor = Color(0x33750047);

  /// Scaled bar height for the current screen (Figma 64px @ 375pt).
  static double barHeightFor(BuildContext context) =>
      BottomNavLayout.of(context).barHeight;

  /// Design-time bar height — prefer [barHeightFor] when [BuildContext] is available.
  static const double barHeight = BottomNavFigmaTokens.barHeight;

  Widget _buildProfileIcon(BottomNavLayout layout) {
    return _BottomNavProfileAvatar(
      size: layout.profileAvatarSize,
      borderWidth: layout.profileAvatarBorderWidth,
      imageUrl: profileImageUrl,
      fallbackIconColor: _iconColor,
      isSelected: currentIndex == 4,
    );
  }

  Widget _buildNavTap({
    required BottomNavLayout layout,
    required VoidCallback onPressed,
    required Widget child,
    double? tapTargetWidth,
    double? tapTargetHeight,
  }) {
    final targetWidth = tapTargetWidth ?? layout.tabSlotWidth;
    final targetHeight = tapTargetHeight ?? layout.tabSlotHeight;
    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          radius: targetWidth / 2,
          splashColor: _splashColor,
          highlightColor: _splashColor.withValues(alpha: 0.5),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildChatIcon(BottomNavLayout layout, bool isSelected) {
    final count = unreadChatCount < 0 ? 0 : unreadChatCount;
    final showBadge = count > 0;
    final label = count > 99 ? '99+' : '$count';
    final iconSize = layout.s(isSelected ? 24 : 20);
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _NavSvgIcon(
            assetPath: isSelected
                ? BottomNavAssets.chatSelected
                : BottomNavAssets.chatUnselected,
            width: iconSize,
            height: iconSize,
          ),
          if (showBadge)
            Positioned(
              right: layout.s(-6),
              top: layout.s(-4),
              child: Container(
              constraints: BoxConstraints(
                minWidth: layout.s(18),
                minHeight: layout.s(18),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: layout.s(5),
                vertical: layout.s(2),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55),
                borderRadius: BorderRadius.circular(layout.s(10)),
                border: Border.all(color: _navBarFill, width: layout.s(1)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  color: Colors.white,
                  fontSize: layout.s(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal margin for the floating pill bar inside the chrome.
  double _horizontalMargin(BottomNavLayout layout) => layout.horizontalMargin;

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
    final layout = BottomNavLayout.of(context);
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
    return progressBand + chromeTop + layout.barHeight + bottomInset;
  }

  BoxDecoration _pillDecoration(BottomNavLayout layout) => BoxDecoration(
        color: _navBarFill,
        borderRadius: BorderRadius.circular(layout.pillRadius),
        boxShadow: layout.pillShadow,
      );

  BoxDecoration _pillInsetStrokeDecoration(BottomNavLayout layout) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(layout.pillInnerRadius),
        border: Border.all(
          color: BottomNavFigmaTokens.pillStrokeColor.withValues(
            alpha: BottomNavFigmaTokens.pillStrokeOpacity,
          ),
          width: layout.s(1),
        ),
      );

  Widget _buildPill({
    required BottomNavLayout layout,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: _pillDecoration(layout),
      child: DecoratedBox(
        decoration: _pillInsetStrokeDecoration(layout),
        child: child,
      ),
    );
  }

  Widget _buildCreateMenuStack(BottomNavLayout layout) {
    final onAction = onCreateAction;
    if (onAction == null || createMenuProgress <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: layout.createMenuToNavGap),
      child: BottomNavCreateMenu(
        progress: createMenuProgress,
        onAction: onAction,
        layout: layout,
      ),
    );
  }

  Widget _buildIconGroup({
    required BottomNavLayout layout,
    required bool createOpen,
  }) {
    return SizedBox(
      width: layout.iconGroupWidth,
      height: layout.iconGroupHeight,
      child: Row(
        children: [
          _NavItem(
            unselectedAsset: BottomNavAssets.homeUnselected,
            selectedAsset: BottomNavAssets.homeSelected,
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
            buildTap: ({required onPressed, required child, tapTargetWidth, tapTargetHeight}) =>
                _buildNavTap(
              layout: layout,
              onPressed: onPressed,
              child: child,
              tapTargetWidth: tapTargetWidth,
              tapTargetHeight: tapTargetHeight,
            ),
            iconWidth: layout.s(currentIndex == 0 ? 28 : 24),
            iconHeight: layout.s(currentIndex == 0 ? 28 : 24),
          ),
          SizedBox(width: layout.tabGap),
          _NavItem(
            unselectedAsset: BottomNavAssets.broadcastUnselected,
            selectedAsset: BottomNavAssets.broadcastSelected,
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
            buildTap: ({required onPressed, required child, tapTargetWidth, tapTargetHeight}) =>
                _buildNavTap(
              layout: layout,
              onPressed: onPressed,
              child: child,
              tapTargetWidth: tapTargetWidth,
              tapTargetHeight: tapTargetHeight,
            ),
            iconWidth: layout.s(27),
            iconHeight: layout.s(27),
            iconOffsetX: layout.s(BottomNavFigmaTokens.broadcastIconOpticalOffsetX),
            iconOffsetY: layout.s(BottomNavFigmaTokens.broadcastIconOpticalOffsetY),
          ),
          SizedBox(width: layout.tabGap),
          _NavItem(
            unselectedAsset: BottomNavAssets.addUnselected,
            selectedAsset: BottomNavAssets.addSelected,
            isSelected: createOpen,
            onTap: onCreateMenuToggle ?? () => onTap(2),
            buildTap: ({required onPressed, required child, tapTargetWidth, tapTargetHeight}) =>
                _buildNavTap(
              layout: layout,
              onPressed: onPressed,
              child: child,
              tapTargetWidth: tapTargetWidth,
              tapTargetHeight: tapTargetHeight,
            ),
            iconWidth: layout.s(createOpen ? 30 : 20),
            iconHeight: layout.s(createOpen ? 30 : 20),
          ),
          SizedBox(width: layout.tabGap),
          _NavItem(
            isSelected: currentIndex == 3,
            onTap: () => onTap(3),
            buildTap: ({required onPressed, required child, tapTargetWidth, tapTargetHeight}) =>
                _buildNavTap(
              layout: layout,
              onPressed: onPressed,
              child: child,
              tapTargetWidth: tapTargetWidth,
              tapTargetHeight: tapTargetHeight,
            ),
            customChild: _buildChatIcon(layout, currentIndex == 3),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(BottomNavLayout layout) {
    final createOpen = isCreateMenuOpen;
    return SizedBox(
      height: layout.barHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: layout.pillContentVerticalInset,
        ),
        child: SizedBox(
          height: layout.navRowContentHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: layout.pillContentLeftInset),
              _buildIconGroup(layout: layout, createOpen: createOpen),
              SizedBox(width: layout.profileToIconGroupGap),
              _buildNavTap(
                layout: layout,
                onPressed: () => onTap(4),
                tapTargetWidth: layout.profileAvatarSize,
                tapTargetHeight: layout.profileAvatarSize,
                child: _buildProfileIcon(layout),
              ),
              SizedBox(width: layout.pillContentRightInset),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavChromeBody({
    required BottomNavLayout layout,
    required double bottomInset,
    required bool includeTopPadding,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _buildCreateMenuStack(layout)),
        Padding(
          padding: EdgeInsets.fromLTRB(
            _horizontalMargin(layout),
            includeTopPadding ? _chromeTopPadding : 0,
            _horizontalMargin(layout),
            bottomInset,
          ),
          child: _buildPill(layout: layout, child: _buildNavRow(layout)),
        ),
      ],
    );
  }

  Widget _buildFloatingPill(BottomNavLayout layout, double bottomInset) {
    return _buildNavChromeBody(
      layout: layout,
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

  Widget _buildFeedChromePill(BottomNavLayout layout, double bottomInset) {
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
                layout: layout,
                bottomInset: bottomInset,
                includeTopPadding: true,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _buildCreateMenuStack(layout)),
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
                      _horizontalMargin(layout),
                      0,
                      _horizontalMargin(layout),
                      bottomInset,
                    ),
                    child: _buildPill(
                      layout: layout,
                      child: _buildNavRow(layout),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = BottomNavLayout.of(context);
    final bottomInset = AppSystemUi.bottomChromeInset(
      context,
      iosInsetFactor: _iosSafeAreaBottomFactor,
    );

    // Home/broadcast dark chrome wraps the menu in a black strip — use the light
    // floating pill while the create hub is open (matches profile/chat).
    final createMenuVisible = isCreateMenuOpen || createMenuProgress > 0;
    if (useFeedChrome && !createMenuVisible) {
      return _buildFeedChromePill(layout, bottomInset);
    }
    return _buildFloatingPill(layout, bottomInset);
  }
}

typedef _NavTapBuilder = Widget Function({
  required VoidCallback onPressed,
  required Widget child,
  double? tapTargetWidth,
  double? tapTargetHeight,
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
    this.iconOffsetX = 0,
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
  final double iconOffsetX;
  final double iconOffsetY;

  @override
  Widget build(BuildContext context) {
    final icon = customChild ??
        _NavSvgIcon(
          assetPath: isSelected ? selectedAsset! : unselectedAsset!,
          width: iconWidth,
          height: iconHeight,
          offsetX: iconOffsetX,
          offsetY: iconOffsetY,
        );

    return buildTap(
      onPressed: onTap,
      child: icon,
    );
  }
}

class _NavSvgIcon extends StatelessWidget {
  const _NavSvgIcon({
    required this.assetPath,
    this.width = AppSizes.bottomNavIconSlot,
    this.height = AppSizes.bottomNavIconSlot,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final String assetPath;
  final double width;
  final double height;
  final double offsetX;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: SizedBox(
        width: width,
        height: height,
        child: SvgPicture.asset(
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// Figma profile tab — 56×56 circle; layout size never changes when photo loads.
class _BottomNavProfileAvatar extends StatelessWidget {
  const _BottomNavProfileAvatar({
    required this.size,
    required this.borderWidth,
    required this.imageUrl,
    required this.fallbackIconColor,
    required this.isSelected,
  });

  final double size;
  final double borderWidth;
  final String? imageUrl;
  final Color fallbackIconColor;
  final bool isSelected;

  String? get _resolvedImageUrl {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Widget _buildFallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: BottomNavFigmaTokens.createMenuIconCircleFill,
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: size * 0.45,
          color: fallbackIconColor,
        ),
      ),
    );
  }

  Widget _buildBorderRing() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: BottomNavFigmaTokens.profileAvatarBorderColor,
            width: borderWidth,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolvedImageUrl;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * devicePixelRatio).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildFallback(),
          if (resolvedUrl != null)
            ClipOval(
              child: Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                alignment: Alignment(
                  0,
                  BottomNavFigmaTokens.profilePhotoVerticalBias,
                ),
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, error, stackTrace) =>
                    const SizedBox.shrink(),
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null) {
                    return const SizedBox.shrink();
                  }
                  return child;
                },
              ),
            ),
          if (isSelected) _buildBorderRing(),
        ],
      ),
    );
  }
}
