/// Model for a track in the music library. Shared by Music library screen and Music picker.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.albumArtUrl,
    this.audioUrl = '',
    this.isSaved = false,
  });

  final String id;
  final String title;
  final String artist;
  final String duration;
  final String albumArtUrl;

  /// Direct MP3 stream URL. Empty for mock tracks.
  final String audioUrl;
  final bool isSaved;

  /// Display string for profile (e.g. "Zulfein • Mehul Mahesh, DJ A...").
  String get profileDisplay => '$title • $artist';
}

/// Shared mock music list. Same data for Music library and Edit Profile music picker.
/// [audioUrl] uses stable HTTPS samples so preview works when Jamendo is unreachable.
const List<MusicTrack> mockMusicTracks = [
  MusicTrack(
    id: '1',
    title: 'Zulfein',
    artist: 'Mehul Mahesh, DJ Aynik',
    duration: '3:05',
    albumArtUrl: 'https://picsum.photos/80/80?random=zulfein',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    isSaved: true,
  ),
  MusicTrack(
    id: '2',
    title: 'Dive',
    artist: 'Artist Two',
    duration: '2:45',
    albumArtUrl: 'https://picsum.photos/80/80?random=dive',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    isSaved: false,
  ),
  MusicTrack(
    id: '3',
    title: 'Sunhera',
    artist: 'Lost Stories, JAI DHIR',
    duration: '2:25',
    albumArtUrl: 'https://picsum.photos/80/80?random=sunhera',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    isSaved: true,
  ),
  MusicTrack(
    id: '4',
    title: 'Next Track',
    artist: 'Another Artist',
    duration: '3:30',
    albumArtUrl: 'https://picsum.photos/80/80?random=next',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    isSaved: false,
  ),
  MusicTrack(
    id: '5',
    title: 'More Music',
    artist: 'DJ Someone',
    duration: '4:00',
    albumArtUrl: 'https://picsum.photos/80/80?random=more',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    isSaved: false,
  ),
];
