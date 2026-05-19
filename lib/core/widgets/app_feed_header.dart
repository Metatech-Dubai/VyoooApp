import 'package:flutter/material.dart';

import '../theme/app_padding.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'vyooo_brand_logo.dart';

/// Common header for feed screens: VyooO logo + tab selector.
/// Selected tab: pill + border (15% fill). Unselected: text only, no background.
/// Typography: unselected DM Sans Regular 14 @ 60% white; selected Bold 16 white.
class AppFeedHeader extends StatelessWidget {
  const AppFeedHeader({
    super.key,
    required this.selectedIndex,
    this.labels = _defaultLabels,
    this.onTabSelected,
    this.trailing,
  });

  final int selectedIndex;
  final List<String> labels;
  final void Function(int index)? onTabSelected;
  final Widget? trailing;

  static const List<String> _defaultLabels = [
    'Trending',
    'VR',
    'Following',
    'For You',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.screenHorizontal.copyWith(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: [
          _buildLogo(context),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppFeedTabSelector(
              labels: labels,
              selectedIndex: selectedIndex,
              onTabSelected: onTabSelected,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return const VyoooBrandLogo(
      size: AppSizes.feedLogoHeight,
      center: false,
    );
  }
}

/// Tab selector for Trending / VR / Following / For You.
class AppFeedTabSelector extends StatelessWidget {
  const AppFeedTabSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.onTabSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final void Function(int)? onTabSelected;

  static EdgeInsets _tabPadding(bool isSelected) {
    if (isSelected) return AppPadding.feedTabChip;
    return const EdgeInsets.symmetric(vertical: 6);
  }

  static double _estimateTabsWidth(
    List<String> labels,
    int selectedIndex, {
    required double gap,
  }) {
    var total = 0.0;
    for (var i = 0; i < labels.length; i++) {
      final isSelected = selectedIndex == i;
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: isSelected
              ? AppTypography.feedTabLabelSelected
              : AppTypography.feedTabLabel,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final pad = _tabPadding(isSelected);
      total += painter.width + pad.horizontal;
      if (i < labels.length - 1) {
        total += gap;
      }
    }
    return total;
  }

  Widget _buildTab(int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected?.call(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: _tabPadding(isSelected),
        decoration: isSelected
            ? BoxDecoration(
                color: White15.value,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: AppTheme.primary, width: 1),
              )
            : null,
        child: Text(
          labels[index],
          style: isSelected
              ? AppTypography.feedTabLabelSelected
              : AppTypography.feedTabLabel,
        ),
      ),
    );
  }

  Widget _groupedTabs({required double gap}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tabChildren(gap: gap),
      ),
    );
  }

  List<Widget> _tabChildren({required double gap}) {
    return List.generate(labels.length, (index) {
      final tab = _buildTab(index);
      if (index == 0) return tab;
      return Padding(
        padding: EdgeInsets.only(left: gap),
        child: tab,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const wideGap = AppSpacing.feedTabGap;
        const narrowGap = AppSpacing.xs;
        final wideWidth =
            _estimateTabsWidth(labels, selectedIndex, gap: wideGap);
        final narrowWidth =
            _estimateTabsWidth(labels, selectedIndex, gap: narrowGap);

        if (wideWidth <= maxWidth) {
          return _groupedTabs(gap: wideGap);
        }
        if (narrowWidth <= maxWidth) {
          return _groupedTabs(gap: narrowGap);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _tabChildren(gap: narrowGap),
          ),
        );
      },
    );
  }
}
