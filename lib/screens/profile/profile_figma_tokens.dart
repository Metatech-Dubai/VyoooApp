import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Profile screen measurements and light-theme tokens (redesign).
abstract final class ProfileFigmaTokens {
  /// Username/handle for profile UI (no leading `@`).
  static String displayUsername(String? raw) =>
      (raw ?? '').replaceAll('@', '').trim();

  // — Light profile palette —
  static const Color screenBackground = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF0C0C0C);
  static const Color secondaryText = Color(0xFF5A5A5A);
  static const Color cardBackground = Color(0xFFF2F2F2);

  /// Story ring around profile avatar (Figma #E51147).
  static const Color storyRing = AppColors.storyRing;

  /// Selected tab accent / profile side rail.
  static const Color accentMagenta = Color(0xFF750047);

  /// Legacy alias used by verification-adjacent accents.
  static const Color accentMagentaAlt = accentMagenta;

  /// Tab track fill — white pill behind Posts / VR / Clips / Tags labels.
  static const Color tabTrack = screenBackground;

  /// Bookmark / star accessory buttons beside the tab pill (Figma 40×40).
  static const double tabAccessoryWidth = 40;
  static const double tabAccessoryHeight = 40;
  static const double tabAccessoryRadius = 12;
  static const Color tabAccessoryIconColor = AppColors.profileTabAccessoryIcon;
  /// Bookmark / heart tile fill (Figma white — not grey).
  static const Color tabAccessoryFill = screenBackground;
  static const double tabAccessorySize = tabAccessoryWidth;
  static const double tabBookmarkIconSize = 16;
  static const double tabHeartIconWidth = 15;
  static const double tabHeartIconHeight = 14;

  /// White tab track (Figma 291×40, rx=12).
  static const double tabBarTrackHeight = 40;
  static const double tabBarTrackRadius = 12;
  static const double tabBarInnerPadding = 4;
  static const double tabSelectedPillWidth = 68;
  static const double tabSelectedPillHeight = 32;
  static const double tabSelectedPillRadius = 8;
  /// Selected tab chip fill (Figma #1A1A1A).
  static const Color tabSelectedPillFill = Color(0xFF1A1A1A);
  /// Gap between tab track and bookmark / star (Figma 4px).
  static const double tabBarAccessoryGap = 4;
  /// Full tab row width incl. accessories (Figma 387).
  static const double profileTabBarRowMaxWidth = 387;
  /// Drop shadow on tab track + accessories (Figma 12% black, σ=2).
  static const Color tabBarShadowColor = Color(0x1F000000);
  static const double tabBarShadowBlur = 4;
  static const List<BoxShadow> tabBarElementShadow = [
    BoxShadow(
      color: tabBarShadowColor,
      blurRadius: tabBarShadowBlur,
    ),
  ];

  /// Legacy aliases — prefer [tabBarTrackHeight] / [tabBarTrackRadius].
  static const double tabBarHeight = tabBarTrackHeight;
  static const double tabBarRadius = tabBarTrackRadius;
  static const double tabBarOuterPadding = tabBarInnerPadding;

  /// Magenta accent — highlights add tile, loading spinners (#660033).
  static const Color tabSelectedFill = AppColors.feedFollowButton;
  /// Unselected tab label (#5D5F5F).
  static const Color tabUnselectedLabelColor = AppColors.profileTabUnselectedLabel;

  static const double highlightTileWidth = 68;
  static const double highlightTileHeight = 68;
  static const double highlightTileRadius = 10;
  static const double highlightTileGap = 16.7;
  /// Space between 68px tile and label — 85 − 68 − 14 line height.
  static const double highlightLabelGap = 3;
  static const double highlightLabelFontSize = 12;
  static const FontWeight highlightLabelFontWeight = FontWeight.w400;
  static const double highlightLabelLineHeight = 14;
  /// Add-chip label — Figma #554247.
  static const Color highlightAddLabelColor = AppColors.profileStatLabel;
  /// Album title under cover — Figma #1B1C1C.
  static const Color highlightAlbumLabelColor = AppColors.profileDisplayName;
  /// Highlight album placeholder / empty cover (Figma #EFEDED).
  static const Color highlightTileBackground = AppColors.profileStatChipBackground;
  /// Story / highlight add "+" tile fill (Figma #1A1A1A).
  static const Color highlightAddFill = Color(0xFF1A1A1A);
  /// Chevron handle above highlights row (Figma #1A1A1A).
  static const Color highlightsToggleFill = highlightAddFill;
  /// Highlights opener — Figma 68×19.
  static const double highlightsToggleWidth = 68;
  static const double highlightsToggleHeight = 19;
  static const double highlightsToggleChevronWidth = 8;
  static const double highlightsToggleChevronHeight = 5;
  /// Album cover drop shadow — Figma dy=1, blur 2px @ 5% black.
  static const Color highlightTileShadowColor = Color(0x0D000000);
  static const double highlightTileShadowBlur = 2;
  static const Offset highlightTileShadowOffset = Offset(0, 1);

  /// Tile + gap + single-line label — Figma row 85px.
  static const double highlightRowHeight = 85;

  /// Remaining vertical space for the 12/14 label under each chip.
  static double get highlightLabelAreaHeight =>
      highlightRowHeight - highlightTileHeight - highlightLabelGap;

  /// Highlights opener inset from content column start (Figma ~14px).
  static const double highlightsOpenerLeftInset = 14;
  static const double highlightsToggleTopRadius = 12;
  static const double highlightsToggleTopGap = 8;
  static const double highlightsSectionTopGap = 12;
  static const Duration profileHighlightsAnimation =
      Duration(milliseconds: 260);

  /// Edit Profile pill fill — near-black per Figma (#1C1C1C).
  static const Color actionButtonFill = Color(0xFF1C1C1C);

  /// Total avatar frame (with story ring) — Figma 131×131 SVG.
  static const double avatarOuterSize = 131;
  /// Inner hole diameter of story ring SVG (viewBox 127.671).
  static const double avatarStoryRingInnerSize = 127.671;
  /// White gap between story ring and profile photo (Figma 4.66).
  static const double avatarStoryWhiteGap = avatarRingPadding;
  /// Profile photo diameter when story ring is shown.
  static const double avatarStoryPhotoSize =
      avatarStoryRingInnerSize - 2 * avatarStoryWhiteGap;
  /// White gap between story ring and photo (Figma padding 4.66).
  static const double avatarRingPadding = 4.66;

  /// Horizontal inset — header + content column (Figma 15px left / right).
  static const double profileContentHorizontalPad = 15;
  static const double profileHeaderHorizontalPad = profileContentHorizontalPad;

  /// Shared content column width below tabs (Figma 387).
  static const double profileContentColumnWidth = 387;

  /// Shared top inset — profile avatar row and side drawer start here.
  static const double profileHeaderTop = profileHeaderHorizontalPad;

  /// Hamburger menu sits slightly below the shared header top edge.
  static const double profileHeaderMenuTopInset = 8;

  /// Profile post grid — edge-to-edge in the grey card (Figma: no side inset).
  static const EdgeInsets profileGridPadding = EdgeInsets.zero;

  /// Highlights / opener align with selected Feed pill — tab track inner pad (4px).
  static const double profileHighlightsLeftInset = tabBarInnerPadding;

  static const double displayNameFontSize = 20;
  static const double displayNameHeight = 25 / 20;
  /// Display name + badge row height (Figma 32).
  static const double displayNameRowHeight = 32;
  /// Figma display-name fill (#1B1C1C).
  static const Color displayNameColor = AppColors.profileDisplayName;
  /// Gap between display name and verification badge (Figma ~8.82).
  static const double nameVerifiedGap = 8.82;
  /// Verification badge diameter (Figma 16.67).
  static const double verifiedBadgeSize = 16.667;
  /// Default verified badge fill — personal accounts (Figma #22C55E).
  static const Color verifiedBadgeGreen = Color(0xFF22C55E);

  static const double statChipRadius = 12;
  static const double statChipWidth = 85;
  static const double statChipHeight = 55;
  static const double statChipGap = 12;
  static const double statChipValueLabelGap = 4;
  static const double statValueFontSize = 18;
  static const double statValueLineHeight = 24;
  static const double statLabelFontSize = 12;
  static const double statLabelLineHeight = 16;
  /// Stat chip fill (#EFEDED).
  static const Color statChipBackground = AppColors.profileStatChipBackground;
  /// Stat counter value fill (#1B1C1C).
  static const Color statValueColor = AppColors.profileDisplayName;
  /// Stat chip label fill (Figma #808080).
  static const Color statChipLabelColor = Color(0xFF808080);

  static const double actionButtonWidth = 146;
  static const double actionButtonHeight = 40;
  static const double actionButtonRadius = 20;
  static const double actionButtonPaddingH = 26;
  static const double actionButtonPaddingV = 10;
  static const double actionButtonGap = 12;
  static const double actionButtonFontSize = 16;
  static const FontWeight actionButtonFontWeight = FontWeight.w500;
  static const double actionIconButtonSize = 40;
  static const double actionIconSize = 22;
  /// Story + share pair beside Edit Profile (Figma 92×40).
  static const double profileSecondaryActionPairWidth = 92;
  static const double profileSecondaryActionPairInnerGap = 12;
  /// Profile action row max width (Figma 338).
  static const double profileActionRowMaxWidth = 338;
  /// Circular share / story buttons (Figma #E9E8E7).
  static const Color secondaryActionFill = Color(0xFFE9E8E7);

  static const double bioFontSize = 16;
  static const double bioLineHeight = 20;
  static const double musicFontSize = 12;
  /// Bio + music block max width (Figma 338).
  static const double profileBioMusicMaxWidth = 338;
  /// Collapsed bio preview length before "See more".
  static const int profileBioCollapsedLength = 30;
  /// Max bio characters shown when expanded (matches edit profile limit).
  static const int profileBioMaxDisplayLength = 150;
  /// Bio and music line color (Figma #808080).
  static const Color profileBioMusicColor = Color(0xFF808080);
  /// Gap between bio line and profile music line.
  static const double profileBioMusicGap = 8;
  static const double profileBioMusicIconSize = 14;
  static const double profileBioMusicIconGap = 6;

  /// Posts / VR / Clips / Tags panel surface.
  static const Color contentSurface = cardBackground;

  /// White margin outside the grey content card (left + right). Figma: full bleed.
  static const double contentSideMargin = 0;

  static const double contentTopRadius = 32;

  /// Inset above Posts / VR / Clips / Tags inside the grey content card.
  static const double contentTopPadding = 12;

  /// Gap between action buttons and the grey content card.
  static const double contentSectionTopGap = 20;

  /// Gutter between profile post tiles (Figma 1.06px).
  static const double contentGridGap = 1.06;

  /// Portrait tile corners — flush grid in Figma (no visible radius).
  static const double contentGridRadius = 0;

  /// Profile feed grid — 3 columns, uniform portrait tiles (Figma).
  static const int contentGridCrossAxisCount = 3;
  /// Tile width / height from Figma row (~132.49 × 165.61).
  static const double contentGridTileAspectRatio = 132.49 / 165.61;
  /// Reference row width for design QA (399.59px @ 3 cols + 2 gaps).
  static const double contentGridReferenceRowWidth = 399.59;
  static const double tabSelectedFontSize = 16;
  static const double tabUnselectedFontSize = 16;
  static const double tabFontSize = tabUnselectedFontSize;

  static const double headerUsernameFontSize = 18;

  /// Profile side rail beside avatar — expanded (Figma 43×150).
  static const double profileSideRailWidth = 43;
  /// Collapsed peek tab width (Figma 12×150).
  static const double profileSideRailCollapsedWidth = 12;
  static const double profileSideRailHeight = 150;
  /// Own-profile avatar + display name band — matches [profileSideRailHeight].
  static const double profileAvatarNameBandHeight = profileSideRailHeight;
  /// Compact header avatar (110 + 8 gap + 32 name = 150).
  static const double profileHeaderAvatarSize = 110;
  static const double profileHeaderAvatarNameGap = 8;
  /// Right-edge corner radius on the drawer panel (Figma 10).
  static const double profileSideRailRadius = 10;
  /// Drawer fill (#1A1A1A).
  static const Color sideDrawerFill = Color(0xFF1A1A1A);
  /// Drawer icon tint (white glyphs in SVG).
  static const Color sideDrawerIconColor = Color(0xFFFFFFFF);
  /// Vertical offset — top-aligned with the profile avatar row.
  static const double profileSideRailTop = profileHeaderTop;
  /// Tap target height for each drawer icon row.
  static const double profileSideRailTapHeight = 42;
  /// Invisible touch strip when collapsed — wider than [profileSideRailCollapsedWidth].
  static const double profileSideRailMinGestureWidth = 28;
  static const Duration profileSideDrawerAnimation =
      Duration(milliseconds: 220);

  // — Profile “More” end drawer (Figma 341×704 artboard, slides from right) —
  static const double profileMoreDrawerWidth = 341;
  static const double profileMoreDrawerDesignHeight = 704;
  static const double profileMoreDrawerContentHorizontalInset = 15;
  static const double profileMoreDrawerContentWidth = 310;
  static const double profileMoreDrawerLogoutHorizontalInset = 16.5;
  static const double profileMoreDrawerLogoutWidth = 309;
  static const Color profileMoreDrawerSectionLabel = Color(0xFF838484);
  static const Color profileMoreDrawerCardFill = Color(0xFFF9F9F9);
  static const double profileMoreDrawerCardRadius = 7;
  static const double profileMoreDrawerRowHeight = 52;
  static const double profileMoreDrawerRowHorizontalInset = 16;
  static const Color profileMoreDrawerRowDivider = Color(0x0F000000);
  static const Color profileMoreDrawerChevron = Color(0xFFC4C7C7);
  static const Color profileMoreDrawerItemText = Color(0xFF1A1C1C);
  static const Color profileMoreDrawerLogoutText = Color(0xFFBA1A1A);
  static const Color profileMoreDrawerLogoutBorder = Color(0xFFC4C7C7);
  static const double profileMoreDrawerLogoutHeight = 57;
  static const Duration profileMoreDrawerAnimation =
      Duration(milliseconds: 260);

  /// Compact other-user profile top bar.
  static const double otherUserHeaderAvatarRadius = 18;
  static const double otherUserHeaderNameFontSize = 15;
  static const double otherUserHeaderHandleFontSize = 13;
  static const double otherUserHeaderFollowFontSize = 13;
  static const Color otherUserHeaderHandleColor = secondaryText;
  static const Color otherUserHeaderFollowBorder = Color(0xFFB0B0B0);

  /// Other-user profile action row — Following / Requested pill.
  static const double profileFollowButtonHeight = 45;
  static const double profileFollowLabelFontSize = 14;
  static const Color profileFollowingBorder = Color(0xFFB0B0B0);
}
