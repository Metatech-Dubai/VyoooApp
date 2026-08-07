import Foundation
import Flutter
import CoreVideo

/// A `FlutterTexture` fed the pipeline's processed (currently pass-through BGRA) ERP frames, so the
/// Dart host preview can render via a `Texture(textureId:)` widget.
///
/// iOS analogue of the Android `Insta360GlRenderer` + `createProcessedTexture` path. On iOS the
/// primary host preview is the native `Insta360PreviewView` (an interactive sphere), but the Dart
/// API also exposes `createProcessedTexture()` for a flat-ERP host preview; this backs it.
///
/// Flutter's engine copies BGRA `CVPixelBuffer`s, which is exactly the flat-pano output format we
/// request, so no per-frame conversion is needed here.
final class Insta360ProcessedTexture: NSObject, FlutterTexture {

    private let registry: FlutterTextureRegistry
    private(set) var textureId: Int64 = 0

    private let lock = NSLock()
    private var latest: CVPixelBuffer?

    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
        textureId = registry.register(self)
    }

    /// Push the newest BGRA frame and ask the engine to pull it.
    func push(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        latest = pixelBuffer
        lock.unlock()
        registry.textureFrameAvailable(textureId)
    }

    func dispose() {
        registry.unregisterTexture(textureId)
        lock.lock(); latest = nil; lock.unlock()
    }

    // MARK: FlutterTexture
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock(); defer { lock.unlock() }
        guard let buf = latest else { return nil }
        return Unmanaged.passRetained(buf)
    }
}
