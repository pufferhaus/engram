import CoreGraphics
import SwiftUI

@MainActor
final class GlyphState: ObservableObject {
    @Published private(set) var currentRowGlyphs: [CGImage] = []
    @Published private(set) var rows: [CGImage] = []

    /// Mutable context for SigilRenderer — AnalysisCycle reads and writes this each tick.
    /// NOT private(set) so AnalysisCycle can write back the advanced context after render.
    var context = GlyphContext()

    private var frameBuffer: [FeatureFrame] = []

    /// Append one glyph. Returns a composited 384×32 row CGImage when the 12th glyph arrives, else nil.
    /// NOTE: context.advance() is called by SigilRenderer.render — do NOT call it here.
    func append(glyph: CGImage, frame: FeatureFrame) -> CGImage? {
        currentRowGlyphs.append(glyph)
        frameBuffer.append(frame)

        if currentRowGlyphs.count == 12 {
            let row = compositeRow(currentRowGlyphs)
            rows.append(row)
            currentRowGlyphs = []
            frameBuffer = []
            return row
        }
        return nil
    }

    func reset() {
        currentRowGlyphs = []
        frameBuffer = []
        rows = []
        context = GlyphContext()
    }

    // MARK: - Row Composite

    private func compositeRow(_ glyphs: [CGImage]) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let ctx = CGContext(
            data: nil, width: 384, height: 32,
            bitsPerComponent: 8, bytesPerRow: 384,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        )!
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 384, height: 32))
        for (i, glyph) in glyphs.enumerated() {
            ctx.draw(glyph, in: CGRect(x: i * 32, y: 0, width: 32, height: 32))
        }
        return ctx.makeImage()!
    }
}
