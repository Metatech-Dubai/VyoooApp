import Foundation
import CoreVideo

/// Builds BGRA `CVPixelBuffer`s from processed RGBA pipeline output for the Flutter host texture.
///
/// The pipeline works in RGBA8888; Flutter's `FlutterTexture` wants BGRA. The processed frame's
/// dimensions change when `DownscaleStage` switches tiers, so a pooled buffer is kept per size and
/// rebuilt when the size changes.
final class PixelBufferFactory {

    private var pool: CVPixelBufferPool?
    private var poolWidth = 0
    private var poolHeight = 0

    /// Convert tightly-packed RGBA (`width*height*4`) into a fresh BGRA `CVPixelBuffer`, or `nil` on
    /// failure. `rgba` may be larger than needed (Downscale can hand back an oversized backing array);
    /// only the first `width*height*4` bytes are read.
    func makeBGRA(fromRGBA rgba: [UInt8], width: Int, height: Int) -> CVPixelBuffer? {
        guard width > 0, height > 0, rgba.count >= width * height * 4 else { return nil }
        guard let pool = ensurePool(width: width, height: height) else { return nil }

        var pbOut: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut) == kCVReturnSuccess,
              let pb = pbOut else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
        let dstStride = CVPixelBufferGetBytesPerRow(pb)
        let srcStride = width * 4

        rgba.withUnsafeBufferPointer { sbuf in
            guard let src = sbuf.baseAddress else { return }
            let dst = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                let srcRow = src + y * srcStride
                let dstRow = dst + y * dstStride
                var x = 0
                while x < width {
                    let i = x * 4
                    // RGBA -> BGRA: swap R and B, keep G and A.
                    dstRow[i + 0] = srcRow[i + 2]
                    dstRow[i + 1] = srcRow[i + 1]
                    dstRow[i + 2] = srcRow[i + 0]
                    dstRow[i + 3] = srcRow[i + 3]
                    x += 1
                }
            }
        }
        return pb
    }

    private func ensurePool(width: Int, height: Int) -> CVPixelBufferPool? {
        if let pool = pool, poolWidth == width, poolHeight == height { return pool }
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        var newPool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &newPool) == kCVReturnSuccess else {
            return nil
        }
        pool = newPool
        poolWidth = width
        poolHeight = height
        return newPool
    }
}
