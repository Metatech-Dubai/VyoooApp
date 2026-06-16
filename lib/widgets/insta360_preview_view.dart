import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Embeds the native Insta360 interactive 360 preview (a PlatformView hosting
/// `InstaCapturePlayerView`). The host can touch-drag to look around and pinch to zoom — the
/// gestures are handled natively by the player; an [EagerGestureRecognizer] hands the touch
/// stream to the platform view so Flutter doesn't intercept it.
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
          // Hand all touch to the native player so its pan/zoom gestures work.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
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
