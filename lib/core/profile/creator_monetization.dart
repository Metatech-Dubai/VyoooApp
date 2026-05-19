import '../models/app_user_model.dart';

/// Interim product rule: [business] accounts are treated like Vyooo Creator plan holders
/// for enabling profile subscriptions (no paid Creator tier required for now).
bool isBusinessAccountAsCreator(String? accountType) {
  return (accountType ?? '').trim().toLowerCase() == 'business';
}

/// May open Settings → Creator subscriptions and toggle [monetizationEnabled].
bool canManageProfileMonetization({
  required String? accountType,
  required bool hasVyoooCreatorPlan,
}) =>
    hasVyoooCreatorPlan || isBusinessAccountAsCreator(accountType);

/// Account types that may offer creator subscriptions when monetization is on.
bool isSubscribeEligibleAccountType(String? accountType) {
  switch ((accountType ?? '').trim().toLowerCase()) {
    case 'business':
    case 'government':
    case 'public':
    case 'content_creator':
    case 'entrepreneur':
    case 'celebrity':
    case 'sports_celebrity':
    case 'musician':
      return true;
    default:
      return false;
  }
}

/// True when profile should show Subscribe + gold creator badge.
bool showProfileSubscribeFeatures({
  required String? accountType,
  required bool monetizationEnabled,
}) =>
    monetizationEnabled && isSubscribeEligibleAccountType(accountType);

bool showProfileSubscribeFeaturesForUser(AppUserModel user) =>
    showProfileSubscribeFeatures(
      accountType: user.accountType,
      monetizationEnabled: user.monetizationEnabled,
    );
