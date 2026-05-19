import 'app_user_model.dart';
import '../utils/establishment_date_validation.dart';

extension AppUserModelOnboarding on AppUserModel {
  String get accountTypeNormalized => accountType.trim().toLowerCase();

  bool get isGovernmentAccount => accountTypeNormalized == 'government';

  bool get isBusinessOrGovernment =>
      accountTypeNormalized == 'business' ||
      accountTypeNormalized == 'government';

  String get establishmentDateIso {
    final raw = organizationDetails['establishmentDate'];
    if (raw == null) return '';
    return raw.toString().trim();
  }

  bool get hasValidEstablishmentDate =>
      EstablishmentDateValidation.isValidEstablishmentDateString(
        establishmentDateIso,
      );

  bool get hasProfileLocation =>
      (profileLocation?.name ?? '').trim().isNotEmpty;

  bool get isLocationOnboardingDone => locationSetupComplete || hasProfileLocation;
}
