import 'package:flutter/foundation.dart';

/// Holds onboarding flow data until completion.
/// Replace with your preferred state solution (e.g. Provider, Riverpod) if needed.
class OnboardingState extends ChangeNotifier {
  DateTime? _dateOfBirth;
  String? _profileImagePath;
  List<String> _selectedInterests = [];

  DateTime? get dateOfBirth => _dateOfBirth;
  String? get profileImagePath => _profileImagePath;
  List<String> get selectedInterests => List.unmodifiable(_selectedInterests);

  set dateOfBirth(DateTime? value) {
    _dateOfBirth = value;
    notifyListeners();
  }

  set profileImagePath(String? value) {
    _profileImagePath = value;
    notifyListeners();
  }

  void setSelectedInterests(List<String> value) {
    _selectedInterests = List.from(value);
    notifyListeners();
  }

  void toggleInterest(String id) {
    if (_selectedInterests.contains(id)) {
      _selectedInterests.remove(id);
    } else {
      _selectedInterests.add(id);
    }
    notifyListeners();
  }

  void clear() {
    _dateOfBirth = null;
    _profileImagePath = null;
    _selectedInterests = [];
    notifyListeners();
  }
}
