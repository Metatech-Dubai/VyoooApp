import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/services/story_service.dart';
import '../../screens/upload/creator_live_route.dart';

enum _Tab { story, gallery, live }

/// Story upload screen matching the Figma design:
///  1. Camera view  – live CameraPreview, shutter + flip + gallery, Story/Gallery/Live tabs
///  2. Gallery view – photo grid (photo_manager) with multi-select up to 10
///  3. Preview      – full-screen image, caption bar, thumbnail strip, Post button
class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen>
    with WidgetsBindingObserver {
  // ── Camera ─────────────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _isFront = false;
  bool _camPermDenied = false; // true when camera permission denied
  String? _camError;           // non-null when init failed for other reason

  // ── Tabs / gallery ─────────────────────────────────────────────────────────
  _Tab _tab = _Tab.story;
  List<AssetEntity> _assets = [];
  final List<String> _selectedIds = []; // ordered for badge numbers
  bool _galleryLoading = false;
  String? _galleryError;

  // ── Preview ────────────────────────────────────────────────────────────────
  List<File> _images = [];
  int _previewIdx = 0;
  final _captionCtrl = TextEditingController();
  bool _uploading = false;

  final _picker = ImagePicker();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _camCtrl?.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _camCtrl?.dispose();
      setState(() => _camReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Camera helpers ─────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    // Request camera permission explicitly before touching the camera API.
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _camPermDenied = true);
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _camError = 'No cameras found on this device.');
        return;
      }
      await _setupCamera(_isFront && _cameras.length > 1 ? 1 : 0);
    } catch (e) {
      if (mounted) setState(() => _camError = e.toString());
    }
  }

  Future<void> _setupCamera(int index) async {
    final prev = _camCtrl;
    _camCtrl = null;
    if (mounted) setState(() { _camReady = false; _camError = null; });
    await prev?.dispose();

    final cam = _cameras[index.clamp(0, _cameras.length - 1)];
    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _camCtrl = ctrl;
    try {
      await ctrl.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _isFront = !_isFront;
    await _setupCamera(_isFront ? 1 : 0);
  }

  Future<void> _capturePhoto() async {
    if (!_camReady || _camCtrl == null) return;
    try {
      final xFile = await _camCtrl!.takePicture();
      if (mounted) {
        setState(() {
          _images.add(File(xFile.path));
          _previewIdx = _images.length - 1;
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Capture failed: $e');
    }
  }

  // ── Gallery helpers ────────────────────────────────────────────────────────

  Future<void> _loadGallery() async {
    setState(() {
      _galleryLoading = true;
      _galleryError = null;
    });
    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        if (mounted) setState(() { _galleryLoading = false; _galleryError = 'Photo library access is required.'; });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
      if (paths.isEmpty) { if (mounted) setState(() => _galleryLoading = false); return; }
      final assets = await paths.first.getAssetListPaged(page: 0, size: 80);
      if (mounted) setState(() { _assets = assets; _galleryLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _galleryLoading = false; _galleryError = e.toString(); });
    }
  }

  Future<void> _pickFromGallery() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xf != null && mounted) {
      setState(() {
        _images.add(File(xf.path));
        _previewIdx = _images.length - 1;
      });
    }
  }

  Future<void> _confirmGallery() async {
    if (_selectedIds.isEmpty) return;
    final ordered = _selectedIds.map((id) => _assets.firstWhere((a) => a.id == id)).toList();
    final files = await Future.wait(ordered.map((a) => a.originFile));
    final nonNull = files.whereType<File>().toList();
    if (nonNull.isEmpty) return;
    if (mounted) setState(() { _images = nonNull; _previewIdx = 0; _selectedIds.clear(); });
  }

  void _toggleAsset(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 10) {
        _selectedIds.add(id);
      }
    });
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _post() async {
    if (_images.isEmpty || _uploading) return;
    setState(() => _uploading = true);
    try {
      await StoryService().uploadMultipleStories(
        images: _images,
        caption: _captionCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) { _showSnack('Upload failed: $e'); setState(() => _uploading = false); }
    }
  }

  void _onTabChanged(_Tab tab) {
    if (tab == _Tab.live) { openCreatorLiveScreen(context); return; }
    setState(() => _tab = tab);
    if (tab == _Tab.gallery && _assets.isEmpty) _loadGallery();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_images.isNotEmpty) return _buildPreview();
    if (_tab == _Tab.gallery) return _buildGalleryView();
    return _buildCameraView();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. CAMERA VIEW
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview / permission denied / error / loading
          if (_camPermDenied)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera access is required to take photos for your story.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: openAppSettings,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text('Open Settings',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_camError != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 56),
                      const SizedBox(height: 14),
                      Text(
                        'Could not start camera.',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text('Pick from Gallery',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_camReady && _camCtrl != null)
            CameraPreview(_camCtrl!)
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
              ),
            ),

          // Top gradient scrim (for readability of back button)
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom gradient scrim (for readability of controls)
          Positioned(
            bottom: 0, left: 0, right: 0, height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Capture row: gallery | shutter | flip
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SmallCircleBtn(
                        icon: Icons.photo_library_rounded,
                        onTap: _pickFromGallery,
                      ),
                      // Shutter button
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      _SmallCircleBtn(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: _flipCamera,
                      ),
                    ],
                  ),
                ),

                // Story / Gallery / Live tab bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 56, 20),
                  child: _buildTabBar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. GALLERY VIEW
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildGalleryView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Select Photos',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedIds.isEmpty ? null : _confirmGallery,
                    child: Text(
                      _selectedIds.isEmpty ? 'Next' : 'Next (${_selectedIds.length})',
                      style: TextStyle(
                        color: _selectedIds.isEmpty ? Colors.white38 : const Color(0xFFDE106B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildGalleryGrid()),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 56, 20),
              child: _buildTabBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    if (_galleryLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDE106B), strokeWidth: 2));
    }
    if (_galleryError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(_galleryError!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ));
    }
    if (_assets.isEmpty) {
      return const Center(child: Text('No photos found', style: TextStyle(color: Colors.white38, fontSize: 14)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (_, i) {
        final asset = _assets[i];
        final selIdx = _selectedIds.indexOf(asset.id);
        return _GalleryTile(
          asset: asset,
          isSelected: selIdx != -1,
          selectionNumber: selIdx != -1 ? selIdx + 1 : null,
          onTap: () => _toggleAsset(asset.id),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. PREVIEW VIEW
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen image
          Image.file(_images[_previewIdx], fit: BoxFit.cover),

          // Bottom gradient scrim
          Positioned(
            bottom: 0, left: 0, right: 0, height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.92), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => setState(() { _images.clear(); _previewIdx = 0; }),
                    ),
                  ],
                ),

                const Spacer(),

                // Thumbnail strip when multiple images
                if (_images.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == _images.length) {
                            return GestureDetector(
                              onTap: _pickFromGallery,
                              child: Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white.withValues(alpha: 0.12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 28),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: () => setState(() => _previewIdx = i),
                            child: Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _previewIdx == i ? const Color(0xFFDE106B) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(_images[i], fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Caption + icons + Post
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            controller: _captionCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Add a caption +',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(icon: Icons.photo_library_rounded, onTap: _pickFromGallery),
                      const SizedBox(width: 8),
                      _iconBtn(
                        icon: Icons.camera_alt_rounded,
                        onTap: () => setState(() { _images.clear(); _previewIdx = 0; }),
                      ),
                      const SizedBox(width: 8),
                      _uploading
                          ? const SizedBox(
                              width: 56, height: 36,
                              child: Center(child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                            )
                          : GestureDetector(
                              onTap: _post,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Post',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _tabItem('Story', _Tab.story),
          _tabItem('Gallery', _Tab.gallery),
          _tabItem('Live', _Tab.live),
        ],
      ),
    );
  }

  Widget _tabItem(String label, _Tab tab) {
    final isSelected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDE106B) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Small circle button (capture row) ─────────────────────────────────────

class _SmallCircleBtn extends StatelessWidget {
  const _SmallCircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ── Gallery tile ────────────────────────────────────────────────────────────

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.isSelected,
    required this.selectionNumber,
    required this.onTap,
  });
  final AssetEntity asset;
  final bool isSelected;
  final int? selectionNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(const ThumbnailSize.square(200)),
            builder: (_, snap) {
              if (snap.data == null) return Container(color: const Color(0xFF1A0015));
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
          if (isSelected)
            Container(color: const Color(0xFFDE106B).withValues(alpha: 0.30)),
          Positioned(
            top: 6, right: 6,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFFDE106B) : Colors.black.withValues(alpha: 0.50),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: isSelected && selectionNumber != null
                  ? Text('$selectionNumber',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
