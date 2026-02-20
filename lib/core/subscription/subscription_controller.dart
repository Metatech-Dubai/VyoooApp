import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import 'membership_tier.dart';
import 'subscription_service.dart';

class SubscriptionController extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();

  MembershipTier currentTier = MembershipTier.none;
  bool isLoading = false;

  Future<void> init(String publicKey) async {
    await _service.init(publicKey);
    await refreshStatus();
  }

  /// Safe fetch for paywall; never throws.
  Future<Offerings?> fetchOfferings() async {
    return await _service.fetchOfferings();
  }

  Future<void> refreshStatus() async {
    final info = await _service.getCustomerInfo();
    currentTier = _service.getTier(info);
    notifyListeners();
  }

  Future<void> purchaseStandard(Package package) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.purchase(package);
      await refreshStatus();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> purchaseSubscriber(Package package) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.purchase(package);
      await refreshStatus();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> purchaseCreator(Package package) async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.purchase(package);
      await refreshStatus();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    await _service.restore();
    await refreshStatus();
  }

  bool get hasAccess => currentTier != MembershipTier.none;
  bool get isStandard => currentTier == MembershipTier.standard;
  bool get isSubscriber => currentTier == MembershipTier.subscriber;
  bool get isCreator => currentTier == MembershipTier.creator;

  /// Standard → locked; Subscriber & Creator → unlocked.
  /// When [AppConfig.devBypassVRAccess] is true, always unlocked for testing.
  bool get hasVRAccess =>
      AppConfig.devBypassVRAccess || isSubscriber || isCreator;
}
