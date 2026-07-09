import 'package:flutter/material.dart';

import '../core/services/insta360_live_service.dart';

/// Displays the capture-side pipeline's processed output (downscaled + forward-masked) for the host,
/// via a Flutter [Texture] fed natively.
///
/// The SDK preview ([Insta360PreviewView]) must remain mounted as the frame source; this widget is
/// what the host actually sees. Mounting allocates the native texture; unmounting releases it.
class Insta360ProcessedView extends StatefulWidget {
  const Insta360ProcessedView({super.key, required this.service});

  final Insta360LiveService service;

  @override
  State<Insta360ProcessedView> createState() => _Insta360ProcessedViewState();
}

class _Insta360ProcessedViewState extends State<Insta360ProcessedView> {
  int? _textureId;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      final id = await widget.service.createProcessedTexture();
      if (mounted) setState(() => _textureId = id);
    } catch (_) {
      // Leave _textureId null → shows the placeholder.
    }
  }

  @override
  void dispose() {
    widget.service.disposeProcessedTexture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _textureId;
    if (id == null || id < 0) {
      return const ColoredBox(color: Color(0xFF0A000F));
    }
    // ERP is 2:1; preserve aspect and letterbox within the background area.
    return ColoredBox(
      color: const Color(0xFF0A000F),
      child: Center(
        child: AspectRatio(
          aspectRatio: 2,
          child: Texture(textureId: id),
        ),
      ),
    );
  }
}
