import '../models/comment.dart';

/// Mock comments for a reel. Replace with API/controller later.
List<Comment> getMockCommentsForReel(String reelId) {
  return [
    Comment(
      id: 'c1',
      username: 'Adam123.33',
      avatarUrl: 'https://i.pravatar.cc/80?img=11',
      timeAgo: '1h',
      text: 'This is amazing!',
      likeCount: 3,
      replyCount: 0,
    ),
    Comment(
      id: 'c2',
      username: 'Srishtichauhan',
      avatarUrl: 'https://i.pravatar.cc/80?img=5',
      timeAgo: '3h',
      text: 'You look Majestic!!',
      likeCount: 15,
      isLiked: true,
      replyCount: 31,
      isOwnComment: true,
      replies: [
        Comment(
          id: 'c2r1',
          username: 'sofwells3',
          avatarUrl: 'https://i.pravatar.cc/64?img=1',
          timeAgo: '2h',
          text: 'Thank you!',
          likeCount: 2,
          replyCount: 0,
        ),
      ],
    ),
    Comment(
      id: 'c3',
      username: 'Louisa Mole',
      avatarUrl: 'https://i.pravatar.cc/80?img=9',
      timeAgo: 'Just Now',
      text: 'So beautiful',
      likeCount: 0,
      replyCount: 0,
    ),
    Comment(
      id: 'c4',
      username: 'Vanessa Hudgens',
      avatarUrl: 'https://i.pravatar.cc/80?img=20',
      isVerified: true,
      timeAgo: '1w',
      text: 'Love this place',
      likeCount: 2,
      isLiked: true,
      replyCount: 2,
    ),
    Comment(
      id: 'c5',
      username: 'John Mark',
      avatarUrl: 'https://i.pravatar.cc/80?img=12',
      timeAgo: '2w',
      text: 'Where is this?',
      likeCount: 1,
      replyCount: 0,
    ),
    Comment(
      id: 'c6',
      username: 'Alex',
      avatarUrl: 'https://i.pravatar.cc/80?img=33',
      timeAgo: '5w',
      text: 'Need to visit someday',
      likeCount: 0,
      replyCount: 0,
    ),
  ];
}
