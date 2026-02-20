import 'package:flutter/material.dart';

import '../../../../core/widgets/app_feed_header.dart';

/// Feed tab enum for type-safe tab selection.
enum FeedTab { trending, vr, following, forYou }

/// Thin wrapper around [AppFeedHeader] using [FeedTab]. Prefer [AppFeedHeader] for common use.
class FeedHeader extends StatelessWidget {
  const FeedHeader({
    super.key,
    required this.activeTab,
    this.onTabChanged,
  });

  final FeedTab activeTab;
  final void Function(FeedTab tab)? onTabChanged;

  @override
  Widget build(BuildContext context) {
    return AppFeedHeader(
      selectedIndex: activeTab.index,
      onTabSelected: onTabChanged != null
          ? (i) => onTabChanged!(FeedTab.values[i])
          : null,
    );
  }
}
