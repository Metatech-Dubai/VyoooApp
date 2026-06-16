import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/giphy_gif_service.dart';

class GifPickerSheet extends StatefulWidget {
  const GifPickerSheet({super.key, required this.onGifSelected});

  final void Function(ChatGif gif) onGifSelected;

  static Future<void> show(
    BuildContext context, {
    required void Function(ChatGif gif) onGifSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GifPickerSheet(onGifSelected: onGifSelected),
    );
  }

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  final GiphyGifService _gifService = GiphyGifService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<ChatGif> _gifs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _loadTrending();
      } else {
        _search(query);
      }
    });
  }

  Future<void> _loadTrending() async {
    if (!AppConfig.isGiphyGifSearchAvailable) {
      setState(() {
        _loading = false;
        _error = 'GIF search is not configured yet.';
        _gifs = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await _gifService.trending();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _gifs = results;
      if (results.isEmpty) _error = 'No GIFs found. Try again.';
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await _gifService.search(query);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _gifs = results;
      if (results.isEmpty) _error = 'No GIFs found for "$query".';
    });
  }

  void _select(ChatGif gif) {
    Navigator.of(context).pop();
    widget.onGifSelected(gif);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.55;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0A2E), Color(0xFF0D0518)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search GIFs...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A1540),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Powered by GIPHY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandMagenta),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final gif = _gifs[index];
        return GestureDetector(
          onTap: () => _select(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: gif.previewUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: const Color(0xFF2A1540)),
              errorWidget: (_, _, _) => Container(
                color: const Color(0xFF2A1540),
                child: const Icon(Icons.gif, color: Colors.white38),
              ),
            ),
          ),
        );
      },
    );
  }
}
