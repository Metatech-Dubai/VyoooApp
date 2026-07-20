import 'package:flutter/material.dart';

import 'profile_more_drawer.dart';

/// Profile overflow menu (three lines) — opens the right-side [ProfileMoreDrawer].
@Deprecated('Use showProfileMoreDrawer directly.')
Future<void> showProfileMenuBottomSheet(
  BuildContext context, {
  required VoidCallback onVr,
  required VoidCallback onVyoooCoin,
  required VoidCallback onRevenue,
  required VoidCallback onSettings,
  required VoidCallback onSwitchAccounts,
  required VoidCallback onLogout,
}) {
  return showProfileMoreDrawer(
    context,
    onVyrooAi: onVr,
    onMarketplace: onVyoooCoin,
    onWallet: onVyoooCoin,
    onVyoooCoin: onVyoooCoin,
    onRevenue: onRevenue,
    onOrders: onVyoooCoin,
    onSettings: onSettings,
    onSwitchAccounts: onSwitchAccounts,
    onPrivacy: onSettings,
    onLogout: onLogout,
  );
}
