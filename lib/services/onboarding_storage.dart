import 'package:shared_preferences/shared_preferences.dart';

const String _keyOnboardingComplete = 'onboarding_complete';

/// Persists onboarding completion. Prevents user from returning to onboarding.
class OnboardingStorage {
  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  static Future<void> setComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, value);
  }
}
