/// Normalizes engagement counters read from Firestore or shown in the UI.
abstract final class EngagementCounts {
  EngagementCounts._();

  /// Engagement metrics must never be negative in product surfaces.
  static int sanitize(int value) => value < 0 ? 0 : value;
}
