import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'membership_tier.dart';

/// Wraps RevenueCat SDK: configure, offerings, purchase, restore, entitlement → tier.
class SubscriptionService {
  Future<void> init(String publicKey) async {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(publicKey),
    );
  }

  /// Safe fetch: never throws. Returns null if offerings unavailable.
  Future<Offerings?> fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat offerings unavailable: $e');
      }
      return null;
    }
  }

  @Deprecated('Use fetchOfferings() for safe null return')
  Future<Offerings> getOfferings() async {
    return await Purchases.getOfferings();
  }

  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  Future<void> purchase(Package package) async {
    await Purchases.purchasePackage(package);
  }

  Future<void> restore() async {
    await Purchases.restorePurchases();
  }

  MembershipTier getTier(CustomerInfo info) {
    if (info.entitlements.active.containsKey('creator_access')) {
      return MembershipTier.creator;
    }
    if (info.entitlements.active.containsKey('subscriber_access')) {
      return MembershipTier.subscriber;
    }
    if (info.entitlements.active.containsKey('standard_access')) {
      return MembershipTier.standard;
    }
    return MembershipTier.none;
  }
}
