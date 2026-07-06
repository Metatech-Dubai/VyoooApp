import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Embeds the native Insta360 interactive 360 preview (a PlatformView hosting
/// `InstaCapturePlayerView`). Look-around (rotation) is driven from the live screen via the SDK's
/// `setYaw`/`setPitch` — touch on an embedded platform view doesn't reach Flutter reliably, so the
/// gesture/slider controls live in a top UI layer there, not on this view.
///
/// Mounting this widget starts the preview stream + frame extraction; unmounting stops them.
/// The camera must already be connected via `Insta360LiveService.connect`. Android-only.
///
/// Uses **Hybrid Composition** (`initExpensiveAndroidView`): `InstaCapturePlayerView` is a
/// GL `SurfaceView`, which does not render under the default virtual-display/texture-layer
/// PlatformView modes — it shows as black and the GL pipeline never produces frames. Hybrid
/// composition places the real native view in the hierarchy so it renders (and extraction works).
class Insta360PreviewView extends StatelessWidget {
  const Insta360PreviewView({
    super.key,
    this.extractWidth = 1920,
    this.extractHeight = 960,
  });

  /// Render/extraction resolution (2:1 ERP). Lower it for bandwidth-sensitive use.
  final int extractWidth;
  final int extractHeight;

  static const String _viewType = 'vyooo/insta360_preview';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Insta360 preview is Android-only',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final creationParams = <String, dynamic>{
      'width': extractWidth,
      'height': extractHeight,
    };

    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          // Drag is handled by a top-layer GestureDetector in the live screen (the background layer,
          // where this view lives, receives no touches), so the platform view claims no gestures.
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
        return controller;
      },
    );
  }
}
