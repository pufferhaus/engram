import XCTest
import CoreGraphics
@testable import Engram

final class SigilRendererTests: XCTestCase {
    let renderer = SigilRenderer()

    func testOutputSize() {
        var ctx = GlyphContext()
        let image = renderer.render(frame: .synthetic(), context: &ctx)
        XCTAssertEqual(image.width, 32)
        XCTAssertEqual(image.height, 32)
    }

    func testContextAdvancesAfterRender() {
        var ctx = GlyphContext()
        XCTAssertEqual(ctx.glyphIndex, 0)
        _ = renderer.render(frame: .synthetic(), context: &ctx)
        XCTAssertEqual(ctx.glyphIndex, 1)
    }

    func testHighRmsProducesNonBlackImage() {
        var ctx = GlyphContext()
        let frame = FeatureFrame.synthetic(rms: 1.0)
        let image = renderer.render(frame: frame, context: &ctx)
        XCTAssertTrue(hasNonBlackPixels(image), "Loud frame should produce visible marks")
    }

    func testSilenceProducesBaselineOnly() {
        var ctx = GlyphContext()
        let frame = FeatureFrame.silence(timestamp: 0, windowIndex: 0)
        let image = renderer.render(frame: frame, context: &ctx)
        XCTAssertTrue(hasNonBlackPixels(image), "Baseline should always be visible")
    }

    func testToBitmapProducesCorrectByteCount() {
        var ctx = GlyphContext()
        let image = renderer.render(frame: .synthetic(), context: &ctx)
        let bitmap = SigilRenderer.toBitmap(image: image)
        // 32px wide = 4 bytes per row × 32 rows = 128 bytes
        XCTAssertEqual(bitmap.count, 128)
    }

    // MARK: - Helpers

    private func hasNonBlackPixels(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        ) else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels.contains { $0 > 10 }
    }
}
