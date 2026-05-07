import 'package:flutter/material.dart';

import 'search_tab_launcher.dart';

/// Opens the Search tab with [rawTag] prefilled and shows matching reels (Posts).
void openHashtagInSearch(BuildContext context, String rawTag) {
  SearchTabLauncher.instance.openHashtagFromContext(
    context,
    rawTag,
    categoryTabIndex: 1,
  );
}

@Deprecated('Use openHashtagInSearch — navigates to Search with hashtag')
void openHashtagFeed(BuildContext context, String rawTag) {
  openHashtagInSearch(context, rawTag);
}
