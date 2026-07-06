import '../models/app_user_model.dart';
import '../models/parent_consent_constants.dart';
import '../models/user_profile_extensions.dart';
import '../utils/dob_validation.dart';

/// String route ids for [OnboardingGate] (and tests). No Flutter imports.
abstract class OnboardingRouteId {
  static const createUsername = 'createUsername';
  static const organization = 'organization';
  static const selectDob = 'selectDob';
  static const selectEstablishmentDate = 'selectEstablishmentDate';
  static const parentContact = 'parentContact';
  static const parentalPending = 'parentalPending';
  static const selectLocation = 'selectLocation';
  static const selectInterests = 'selectInterests';
  static const onboardingComplete = 'onboardingComplete';
}

class OnboardingRouteResolver {
  OnboardingRouteResolver._();

  static String resolve(AppUserModel user) {
    final hasUsername = (user.username ?? '').trim().isNotEmpty;
    if (!hasUsername) {
      return OnboardingRouteId.createUsername;
    }

    if (user.isBusinessOrGovernment) {
      if (!user.orgProfileCompleted) {
        return OnboardingRouteId.organization;
      }
    }

    if (user.isGovernmentAccount) {
      if (!user.hasValidEstablishmentDate) {
        return OnboardingRouteId.selectEstablishmentDate;
      }
      return _postIdentityRoute(user);
    }

    final dobRaw = (user.dob ?? '').trim();
    if (dobRaw.isEmpty || !DobValidation.isValidDobString(dobRaw)) {
      return OnboardingRouteId.selectDob;
    }

    final birth = DobValidation.tryParseIsoDob(dobRaw)!;
    final isMinor = DobValidation.requiresParentalConsent(birth);
    if (!isMinor) {
      return _postIdentityRoute(user);
    }

    final status = user.parentConsentStatus.trim().toLowerCase();
    if (status == ParentConsentStatusValue.approved) {
      return _postIdentityRoute(user);
    }
    if (status == ParentConsentStatusValue.pendingContact) {
      return OnboardingRouteId.parentContact;
    }
    if (status == ParentConsentStatusValue.pending) {
      final id = user.parentConsentId.trim();
      if (id.isNotEmpty) {
        return OnboardingRouteId.parentalPending;
      }
      return OnboardingRouteId.parentContact;
    }
    if (status == ParentConsentStatusValue.denied) {
      return OnboardingRouteId.parentContact;
    }
    return OnboardingRouteId.parentContact;
  }

  static String _postIdentityRoute(AppUserModel user) {
    if (user.interests.isEmpty) {
      return OnboardingRouteId.selectInterests;
    }
    return OnboardingRouteId.onboardingComplete;
  }
}
