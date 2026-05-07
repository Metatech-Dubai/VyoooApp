import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utils/hashtag_utils.dart';

/// Switches the main shell to Search and applies a query (registered by [MainNavWrapper]).
typedef SearchTabLaunchCallback =
    void Function(String query, int categoryTabIndex);

class SearchTabLauncher {
  SearchTabLauncher._();
  static final SearchTabLauncher instance = SearchTabLauncher._();

  SearchTabLaunchCallback? _launch;

  void register(SearchTabLaunchCallback launch) {
    _launch = launch;
  }

  void unregister(SearchTabLaunchCallback launch) {
    if (_launch == launch) {
      _launch = null;
    }
  }

  void openWithQuery(String fullQuery, {int categoryTabIndex = 1}) {
    _launch?.call(fullQuery, categoryTabIndex);
  }

  /// Pops to the first route in the current navigator, then opens Search with [rawHashtag].
  /// [categoryTabIndex]: 0 Live, 1 Posts, 2 VR, 3 Users.
  void openHashtagFromContext(
    BuildContext context,
    String rawHashtag, {
    int categoryTabIndex = 1,
  }) {
    final normalized = HashtagUtils.normalizeForQuery(rawHashtag);
    if (normalized.isEmpty) return;
    final query = '#$normalized';

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      openWithQuery(query, categoryTabIndex: categoryTabIndex);
    });
  }
}
