/// DOB validation and constraints. Kept separate from UI.
class DobValidation {
  DobValidation._();

  static const int minAge = 13;
  static const int maxAgeYears = 100;

  /// Latest valid birth date (user must be at least [minAge] years old).
  static DateTime get latestValidBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - minAge, now.month, now.day);
  }

  /// Earliest valid birth date ([maxAgeYears] years ago from today).
  static DateTime get earliestValidBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - maxAgeYears, now.month, now.day);
  }

  /// Year range for picker: [currentYear - 100, currentYear - 13].
  static List<int> get allowedYears {
    final now = DateTime.now();
    final end = now.year - minAge;
    final start = now.year - maxAgeYears;
    return List.generate(end - start + 1, (i) => start + i);
  }

  /// Number of days in [month] for [year].
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  /// Clamp [day] to valid range for [year] and [month].
  static int clampDay(int year, int month, int day) {
    final max = daysInMonth(year, month);
    if (day < 1) return 1;
    if (day > max) return max;
    return day;
  }

  /// True if [date] is a valid birth date (at least [minAge], not future).
  static bool isValidBirthDate(DateTime date) {
    final now = DateTime.now();
    if (date.isAfter(DateTime(now.year, now.month, now.day))) return false;
    final at13 = DateTime(date.year + minAge, date.month, date.day);
    return !now.isBefore(at13);
  }
}
