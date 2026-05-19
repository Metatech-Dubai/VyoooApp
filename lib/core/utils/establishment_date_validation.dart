/// Establishment / founding date for government (and org) accounts.
class EstablishmentDateValidation {
  EstablishmentDateValidation._();

  static const int minYear = 1800;

  static List<int> get allowedYears {
    final end = DateTime.now().year;
    return List.generate(end - minYear + 1, (i) => minYear + i);
  }

  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  static bool isValidEstablishmentDate(
    DateTime date, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(date.year, date.month, date.day);
    if (picked.isAfter(today)) return false;
    if (date.year < minYear) return false;
    return true;
  }

  static DateTime? tryParseIsoDate(String raw) {
    final value = raw.trim();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo)) return null;
    return DateTime(y, mo, d);
  }

  static bool isValidEstablishmentDateString(
    String raw, {
    DateTime? referenceDate,
  }) {
    final parsed = tryParseIsoDate(raw);
    return parsed != null &&
        isValidEstablishmentDate(parsed, referenceDate: referenceDate);
  }
}
