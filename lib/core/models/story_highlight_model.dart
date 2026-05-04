import 'package:cloud_firestore/cloud_firestore.dart';

/// One saved item inside a user highlight (persists after the 24h story expires).
class StoryHighlightItem {
  const StoryHighlightItem({
    required this.id,
    required this.mediaUrl,
    required this.isVideo,
    required this.caption,
    required this.order,
    this.sourceStoryId = '',
  });

  final String id;
  final String mediaUrl;
  final bool isVideo;
  final String caption;
  final int order;
  final String sourceStoryId;

  factory StoryHighlightItem.fromMap(String id, Map<String, dynamic> data) {
    return StoryHighlightItem(
      id: id,
      mediaUrl: data['mediaUrl'] as String? ?? '',
      isVideo: data['isVideo'] as bool? ?? false,
      caption: data['caption'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      sourceStoryId: data['sourceStoryId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'caption': caption,
        'order': order,
        'sourceStoryId': sourceStoryId,
      };
}

/// A named highlight album on a profile.
class StoryHighlightModel {
  const StoryHighlightModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    this.coverMediaUrl = '',
  });

  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final String coverMediaUrl;

  factory StoryHighlightModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StoryHighlightModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Highlights',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      coverMediaUrl: data['coverMediaUrl'] as String? ?? '',
    );
  }
}
