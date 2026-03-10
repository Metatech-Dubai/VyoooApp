import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'add_audio_trim_screen.dart';

/// Add audio screen for video edit: "add audio" title, search, For you/Trending/Saved tabs,
/// music list with selected row highlight and equalizer bars, bottom mini-player.
class AddAudioScreen extends StatefulWidget {
  const AddAudioScreen({super.key, this.videoAsset});

  /// Video being edited; passed to trim screen when a track is selected.
  final AssetEntity? videoAsset;

  @override
  State<AddAudioScreen> createState() => _AddAudioScreenState();
}

class _AddAudioScreenState extends State<AddAudioScreen> {
  static const List<String> _tabs = ['For you', 'Trending', 'Saved'];
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  MusicTrack? _playingTrack;
  bool _isPlaying = true;
  final Set<String> _savedIds = {'1', '3'}; // Toggle bookmark locally

  static const Color _pink = Color(0xFFDE106B);

  @override
  void initState() {
    super.initState();
    _playingTrack = mockMusicTracks[2]; // Sunhera
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MusicTrack> get _filteredTracks {
    final q = _searchController.text.trim().toLowerCase();
    var list = mockMusicTracks;
    if (_selectedTabIndex == 2) list = list.where((t) => _savedIds.contains(t.id)).toList();
    if (q.isEmpty) return list;
    return list
        .where((t) => t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search Music',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.6), size: 22),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTabs(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  itemCount: _filteredTracks.length,
                  itemBuilder: (context, index) {
                    final track = _filteredTracks[index];
                    final isSelected = _playingTrack?.id == track.id;
                    return _AddAudioListTile(
                      track: track,
                      isSelected: isSelected,
                      isSaved: _savedIds.contains(track.id),
                      onTap: () {
                        if (widget.videoAsset != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddAudioTrimScreen(
                                track: track,
                                videoAsset: widget.videoAsset!,
                              ),
                            ),
                          );
                        } else {
                          setState(() => _playingTrack = track);
                        }
                      },
                      onBookmarkTap: () => setState(() {
                        if (_savedIds.contains(track.id)) {
                          _savedIds.remove(track.id);
                        } else {
                          _savedIds.add(track.id);
                        }
                      }),
                    );
                  },
                ),
              ),
              if (_playingTrack != null) _buildMiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'add audio',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = index == _selectedTabIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < _tabs.length - 1 ? AppSpacing.xs : 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedTabIndex = index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? _pink : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _tabs[index],
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final t = _playingTrack!;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(t.albumArtUrl, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.artist,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => setState(() => _isPlaying = !_isPlaying),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _pink,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {},
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.skip_next_rounded, color: _pink, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAudioListTile extends StatelessWidget {
  const _AddAudioListTile({
    required this.track,
    required this.isSelected,
    required this.isSaved,
    required this.onTap,
    required this.onBookmarkTap,
  });

  final MusicTrack track;
  final bool isSelected;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;

  static const Color _pink = Color(0xFFDE106B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _pink.withValues(alpha: 0.35) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
          child: Row(
            children: [
              if (isSelected) _buildEqualizerBars(),
              if (isSelected) const SizedBox(width: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(track.albumArtUrl, width: 52, height: 52, fit: BoxFit.cover),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${track.artist} • ${track.duration}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onBookmarkTap,
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? _pink : Colors.white.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizerBars() {
    return SizedBox(
      width: 20,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(width: 4, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          Container(width: 4, height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }
}
