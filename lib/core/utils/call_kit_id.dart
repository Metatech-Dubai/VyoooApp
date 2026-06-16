import 'package:uuid/uuid.dart';

/// Fixed namespace for deterministic CallKit UUIDs (must match iOS `CallKitUuid.swift`).
const _callKitNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

/// iOS CallKit requires a RFC-4122 UUID string. Firestore document IDs are not UUIDs.
String callKitUuidFor(String firestoreCallId) {
  final trimmed = firestoreCallId.trim();
  if (trimmed.isEmpty) return trimmed;
  if (_looksLikeUuid(trimmed)) return trimmed.toLowerCase();
  return const Uuid().v5(_callKitNamespace, 'vyooo:$trimmed');
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
