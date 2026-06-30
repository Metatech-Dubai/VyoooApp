import 'package:flutter/material.dart';

import '../../core/platform/deferred_agora_ios.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import 'creator_live_screen.dart' deferred as creator;

/// Main-shell broadcast tab: loads Agora lazily and embeds [CreatorLiveScreen]
/// with the standard bottom nav (no Story / Gallery / Live create hub bar).
///
/// [CreatorLiveScreen] is only mounted while this tab is active so the iOS
/// Agora UiKitView is fully disposed before it can be created again — except
/// while stream settings (or similar) is open above it.
class BroadcastTabHost extends StatefulWidget {
  const BroadcastTabHost({
    super.key,
    required this.isActive,
    required this.onRequestHome,
  });

  final bool isActive;
  final VoidCallback onRequestHome;

  @override
  State<BroadcastTabHost> createState() => _BroadcastTabHostState();
}

class _BroadcastTabHostState extends State<BroadcastTabHost> {
  bool _libraryLoaded = false;
  Object? _loadError;
  int _liveSession = 0;
  bool _keepLiveMounted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _ensureLibrary();
    }
  }

  @override
  void didUpdateWidget(BroadcastTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive &&
        !widget.isActive &&
        !_keepLiveMounted) {
      setState(() => _liveSession++);
    }
    if (widget.isActive && !_libraryLoaded && _loadError == null) {
      _ensureLibrary();
    }
  }

  void _onOverlayRouteChanged(bool open) {
    if (_keepLiveMounted == open) return;
    setState(() {
      _keepLiveMounted = open;
      if (!open && !widget.isActive) {
        _liveSession++;
      }
    });
  }

  Future<void> _ensureLibrary() async {
    if (_libraryLoaded || _loadError != null) return;
    try {
      await registerDeferredAgoraPluginsIfNeeded();
      await creator.loadLibrary();
      if (!mounted) return;
      setState(() => _libraryLoaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Widget _buildLiveContent(double shellBottomInset) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Live streaming is unavailable right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    if (!_libraryLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return creator.CreatorLiveScreen(
      key: ValueKey('broadcast_live_$_liveSession'),
      isActive: true,
      embeddedInMainShell: true,
      shellBottomInset: shellBottomInset,
      onShellExit: widget.onRequestHome,
      onOverlayRouteChanged: _onOverlayRouteChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && !_keepLiveMounted) {
      return const ColoredBox(color: Color(0xFF0A000F));
    }

    final shellBottomInset = AppBottomNavigation.totalHeightFor(context);
    final liveContent = _buildLiveContent(shellBottomInset);

    if (!widget.isActive && _keepLiveMounted) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0A000F)),
          Offstage(offstage: true, child: liveContent),
        ],
      );
    }

    return liveContent;
  }
}
