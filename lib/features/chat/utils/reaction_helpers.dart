/// Groups message reactions (uid -> emoji) by emoji for display.
Map<String, List<String>> groupReactionsByEmoji(Map<String, dynamic> reactions) {
  final grouped = <String, List<String>>{};
  for (final entry in reactions.entries) {
    final uid = entry.key;
    final emoji = entry.value;
    if (uid.isEmpty || emoji is! String || emoji.isEmpty) continue;
    grouped.putIfAbsent(emoji, () => []).add(uid);
  }
  return grouped;
}

bool hasReactions(Map<String, dynamic> reactions) =>
    groupReactionsByEmoji(reactions).isNotEmpty;

const Set<String> heartReactionEmojis = {'❤️', '❤', '♥️', '♥'};

bool hasHeartReaction(Map<String, dynamic> reactions) {
  final grouped = groupReactionsByEmoji(reactions);
  return grouped.keys.any(heartReactionEmojis.contains);
}

Map<String, List<String>> nonHeartReactions(Map<String, dynamic> reactions) {
  final grouped = groupReactionsByEmoji(reactions);
  return Map.fromEntries(
    grouped.entries.where((entry) => !heartReactionEmojis.contains(entry.key)),
  );
}
