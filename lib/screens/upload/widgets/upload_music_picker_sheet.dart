import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/mock/mock_music_data.dart';
import '../../../core/services/jamendo_service.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../music/add_audio_trim_screen.dart';

abstract final class UploadMusicPickerAssets {
  static const String grabHandle =
      'assets/vyooO_icons/Upload_Story_Live/music_picker_grab_handle.svg';
  static const String searchField =
      'assets/vyooO_icons/Upload_Story_Live/music_picker_search_field.svg';
  static const String tabsBar =
      'assets/vyooO_icons/Upload_Story_Live/music_picker_tabs_bar.svg';
}

/// Figma music picker bottom sheet for upload edit — search, tabs, list, mini player.
Future<MusicTrack?> showUploadMusicPickerSheet(
  BuildContext context, {
  AssetEntity? videoAsset,
}) {
  return showModalBottomSheet<MusicTrack?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => UploadMusicPickerSheet(videoAsset: videoAsset),
  );
}

class UploadMusicPickerSheet extends StatefulWidget {
  const UploadMusicPickerSheet({super.key, this.videoAsset});

  /// When set, forward opens video+audio trim. When null (e.g. photo edit), forward confirms selection.
  final AssetEntity? videoAsset;

  @override
  State<UploadMusicPickerSheet> createState() => _UploadMusicPickerSheetState();
}

class _UploadMusicPickerSheetState extends State<UploadMusicPickerSheet> {
  static const List<String> _tabs = ['For you', 'Trending', 'Saved'];
  static const Color _sheetBackground = Color(0xFF1C1C1E);

  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _savedIds = {};

  int _activeTab = 0;
  bool _loading = true;
  bool _isPlaying = false;
  bool _navigatingTrim = false;

  List<MusicTrack> _forYouTracks = [];
  List<MusicTrack> _trendingTracks = [];
  MusicTrack? _selectedTrack;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing &&
            state.processingState != ProcessingState.completed;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      JamendoService.instance.fetchForYou(),
      JamendoService.instance.fetchTrending(),
    ]);
    if (!mounted) return;
    setState(() {
      _forYouTracks = results[0];
      _trendingTracks = results[1];
      _loading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      await _loadTracks();
      return;
    }
    setState(() => _loading = true);
    final results = await JamendoService.instance.search(query);
    if (!mounted) return;
    setState(() {
      _forYouTracks = results;
      _trendingTracks = results;
      _loading = false;
    });
  }

  List<MusicTrack> get _currentTracks {
    if (_activeTab == 2) {
      final all = [..._forYouTracks, ..._trendingTracks];
      final seen = <String>{};
      return all.where((t) => _savedIds.contains(t.id) && seen.add(t.id)).toList();
    }
    return _activeTab == 0 ? _forYouTracks : _trendingTracks;
  }

  Future<void> _selectTrack(MusicTrack track) async {
    if (_selectedTrack?.id == track.id) {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    setState(() => _selectedTrack = track);
    if (track.audioUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview is unavailable for this track.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      await _player.setUrl(track.audioUrl);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not play this track. Check your connection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openTrim() async {
    final track = _selectedTrack;
    if (track == null || _navigatingTrim) return;

    final videoAsset = widget.videoAsset;
    if (videoAsset == null) {
      Navigator.of(context).pop(track);
      return;
    }

    _navigatingTrim = true;
    await _player.pause();
    if (!mounted) return;
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddAudioTrimScreen(
          track: track,
          videoAsset: videoAsset,
        ),
      ),
    );
    _navigatingTrim = false;
    if (!mounted) return;
    if (confirmed == true) {
      Navigator.of(context).pop(track);
    }
  }

  void _toggleSaved(String id) {
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _sheetBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              SvgPicture.asset(
                UploadMusicPickerAssets.grabHandle,
                width: AppSizes.musicPickerGrabHandleWidth,
                height: AppSizes.musicPickerGrabHandleHeight,
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _MusicPickerSearchField(
                  controller: _searchController,
                  onChanged: _search,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _MusicPickerTabs(
                  tabs: _tabs,
                  activeIndex: _activeTab,
                  onChanged: (index) => setState(() => _activeTab = index),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(child: _buildTrackList(bottomInset)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList(double bottomInset) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    final tracks = _currentTracks;
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          _activeTab == 2 ? 'No saved tracks yet' : 'No tracks found',
          style: AppTypography.musicPickerTrackMeta,
        ),
      );
    }

    final miniPlayerHeight = _selectedTrack == null ? 0.0 : 88.0;

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            miniPlayerHeight + bottomInset + AppSpacing.md,
          ),
          itemCount: tracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = _selectedTrack?.id == track.id;
            return _MusicPickerTrackRow(
              track: track,
              isSelected: isSelected,
              isPlaying: isSelected && _isPlaying,
              isSaved: _savedIds.contains(track.id),
              onTap: () => _selectTrack(track),
              onBookmarkTap: () => _toggleSaved(track.id),
            );
          },
        ),
        if (_selectedTrack != null)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: bottomInset + AppSpacing.sm,
            child: _MusicPickerMiniPlayer(
              track: _selectedTrack!,
              isPlaying: _isPlaying,
              onPauseToggle: () {
                if (_isPlaying) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
              onForward: _openTrim,
            ),
          ),
      ],
    );
  }
}

class _MusicPickerSearchField extends StatelessWidget {
  const _MusicPickerSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = AppSizes.musicPickerSearchFieldHeight *
            (width / AppSizes.musicPickerSearchFieldWidth);

        return SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              SvgPicture.asset(
                UploadMusicPickerAssets.searchField,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Positioned.fill(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: AppTypography.musicPickerSearchInput,
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search Music',
                    hintStyle: AppTypography.musicPickerSearchHint,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: const Color(0x99EBEBF5),
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicPickerTabs extends StatelessWidget {
  const _MusicPickerTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const List<double> _tabPillLefts = [1.86914, 113.121, 224.371];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = AppSizes.musicPickerTabsBarHeight *
            (width / AppSizes.musicPickerTabsBarWidth);
        final scale = width / AppSizes.musicPickerTabsBarWidth;
        final pillWidth = AppSizes.musicPickerTabPillWidth * scale;
        final pillLeft = _tabPillLefts[activeIndex] * scale;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              SvgPicture.asset(
                UploadMusicPickerAssets.tabsBar,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: pillLeft,
                top: 1.86987 * scale,
                width: pillWidth,
                height: 22.4372 * scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(6.54419 * scale),
                  ),
                ),
              ),
              Row(
                children: List.generate(tabs.length, (index) {
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Text(
                            tabs[index],
                            style: AppTypography.musicPickerTabLabel(
                              active: index == activeIndex,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicPickerTrackRow extends StatelessWidget {
  const _MusicPickerTrackRow({
    required this.track,
    required this.isSelected,
    required this.isPlaying,
    required this.isSaved,
    required this.onTap,
    required this.onBookmarkTap,
  });

  final MusicTrack track;
  final bool isSelected;
  final bool isPlaying;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF3A3A3C) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _albumArt(track.albumArtUrl),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isSelected) ...[
                          _EqualizerBars(playing: isPlaying),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            track.title,
                            style: AppTypography.musicPickerTrackTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.north_east_rounded,
                          size: 12,
                          color: Color(0xFFB3B3B3),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${track.artist} • ${track.duration}',
                            style: AppTypography.musicPickerTrackMeta,
                            maxLines: 1,
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
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _albumArt(String url) {
    final size = AppSizes.musicPickerAlbumArt;
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.white24,
        child: const Icon(Icons.music_note, color: Colors.white, size: 24),
      );
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: Colors.white24,
        child: const Icon(Icons.music_note, color: Colors.white, size: 24),
      ),
    );
  }
}

class _EqualizerBars extends StatelessWidget {
  const _EqualizerBars({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(playing ? 10 : 6),
        const SizedBox(width: 1.5),
        _bar(playing ? 14 : 9),
        const SizedBox(width: 1.5),
        _bar(playing ? 7 : 5),
      ],
    );
  }

  Widget _bar(double height) => Container(
        width: 2,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(1),
        ),
      );
}

class _MusicPickerMiniPlayer extends StatelessWidget {
  const _MusicPickerMiniPlayer({
    required this.track,
    required this.isPlaying,
    required this.onPauseToggle,
    required this.onForward,
  });

  final MusicTrack track;
  final bool isPlaying;
  final VoidCallback onPauseToggle;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                track.albumArtUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: Colors.white24,
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    style: AppTypography.musicPickerTrackTitle.copyWith(
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: AppTypography.musicPickerTrackMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _MiniPlayerControlButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onTap: onPauseToggle,
            ),
            const SizedBox(width: AppSpacing.xs),
            _MiniPlayerControlButton(
              icon: Icons.arrow_forward_rounded,
              onTap: onForward,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayerControlButton extends StatelessWidget {
  const _MiniPlayerControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
    );
  }
}
