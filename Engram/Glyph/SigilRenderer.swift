import CoreGraphics
import Foundation

struct SigilRenderer {

    // MARK: - Public API

    /// Render one 32×32 glyph. Advances `context` after drawing.
    func render(frame: FeatureFrame, context: inout GlyphContext) -> CGImage {
        let size = 32
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        )!

        // Black background
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

        let baselineY = context.baselineY
        let strokeWidth: CGFloat = frame.rms > 0.5 ? 2.0 : 1.0
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setLineWidth(strokeWidth)

        drawBaseline(ctx, y: baselineY, width: CGFloat(size))
        drawAnchorSeal(ctx, pitchClass: frame.dominantPitchClass, x: 16, y: baselineY)
        drawOnsets(ctx, frame: frame, baselineY: baselineY)
        drawRisers(ctx, frame: frame, baselineY: baselineY)
        if context.glyphIndex % 12 == 0 {
            drawMinuteMark(ctx, baselineY: baselineY)
        }

        let image = ctx.makeImage()!
        context.advance(with: frame)
        return image
    }

    /// Convert a CGImage to 1-bit packed data (MSB first) for thermal printing.
    static func toBitmap(image: CGImage, threshold: UInt8 = 128) -> Data {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let bytesPerRow = (width + 7) / 8
        var packed = Data(count: height * bytesPerRow)
        for y in 0..<height {
            for x in 0..<width {
                if pixels[y * width + x] >= threshold {
                    packed[y * bytesPerRow + x / 8] |= UInt8(0x80 >> (x % 8))
                }
            }
        }
        return packed
    }

    // MARK: - Drawing Primitives

    private func drawBaseline(_ ctx: CGContext, y: CGFloat, width: CGFloat) {
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: width, y: y))
        ctx.strokePath()
    }

    private func drawAnchorSeal(_ ctx: CGContext, pitchClass: Int, x: CGFloat, y: CGFloat) {
        ctx.setLineWidth(1)
        let r: CGFloat = 3
        switch pitchClass {
        case 0:  // C — circle
            ctx.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        case 1:  // C# — circle + vertical
            ctx.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            ctx.move(to: CGPoint(x: x, y: y - r)); ctx.addLine(to: CGPoint(x: x, y: y + r))
            ctx.strokePath()
        case 2:  // D — triangle up
            ctx.move(to: CGPoint(x: x, y: y - r))
            ctx.addLine(to: CGPoint(x: x + r, y: y + r))
            ctx.addLine(to: CGPoint(x: x - r, y: y + r))
            ctx.closePath(); ctx.strokePath()
        case 3:  // Eb — triangle down
            ctx.move(to: CGPoint(x: x, y: y + r))
            ctx.addLine(to: CGPoint(x: x + r, y: y - r))
            ctx.addLine(to: CGPoint(x: x - r, y: y - r))
            ctx.closePath(); ctx.strokePath()
        case 4:  // E — diamond
            ctx.move(to: CGPoint(x: x, y: y - r))
            ctx.addLine(to: CGPoint(x: x + r, y: y))
            ctx.addLine(to: CGPoint(x: x, y: y + r))
            ctx.addLine(to: CGPoint(x: x - r, y: y))
            ctx.closePath(); ctx.strokePath()
        case 5:  // F — square
            ctx.stroke(CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        case 6:  // F# — X
            ctx.move(to: CGPoint(x: x - r, y: y - r)); ctx.addLine(to: CGPoint(x: x + r, y: y + r))
            ctx.move(to: CGPoint(x: x + r, y: y - r)); ctx.addLine(to: CGPoint(x: x - r, y: y + r))
            ctx.strokePath()
        case 7:  // G — plus
            ctx.move(to: CGPoint(x: x, y: y - r)); ctx.addLine(to: CGPoint(x: x, y: y + r))
            ctx.move(to: CGPoint(x: x - r, y: y)); ctx.addLine(to: CGPoint(x: x + r, y: y))
            ctx.strokePath()
        case 8:  // Ab — dot in circle
            ctx.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            ctx.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        case 9:  // A — two horizontal bars
            ctx.move(to: CGPoint(x: x - r, y: y - 1)); ctx.addLine(to: CGPoint(x: x + r, y: y - 1))
            ctx.move(to: CGPoint(x: x - r, y: y + 1)); ctx.addLine(to: CGPoint(x: x + r, y: y + 1))
            ctx.strokePath()
        case 10: // Bb — two dots
            ctx.fillEllipse(in: CGRect(x: x - r - 1, y: y - 1, width: 2, height: 2))
            ctx.fillEllipse(in: CGRect(x: x + r - 1, y: y - 1, width: 2, height: 2))
        default: // B — vertical bar with serifs
            ctx.move(to: CGPoint(x: x, y: y - r)); ctx.addLine(to: CGPoint(x: x, y: y + r))
            ctx.move(to: CGPoint(x: x - 1.5, y: y - r)); ctx.addLine(to: CGPoint(x: x + 1.5, y: y - r))
            ctx.move(to: CGPoint(x: x - 1.5, y: y + r)); ctx.addLine(to: CGPoint(x: x + 1.5, y: y + r))
            ctx.strokePath()
        }
    }

    private func drawOnsets(_ ctx: CGContext, frame: FeatureFrame, baselineY: CGFloat) {
        let onsets = Array(frame.onsetTimes.prefix(6))
        for t in onsets {
            let x = CGFloat(t) * 32.0
            let isPercussive = frame.hpssRatio < 0.5

            // Onset tick (vertical stroke crossing baseline)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: x, y: baselineY - 5))
            ctx.addLine(to: CGPoint(x: x, y: baselineY + 5))
            ctx.strokePath()

            if isPercussive {
                // ╳ mark
                ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: x - 2.5, y: baselineY - 2.5))
                ctx.addLine(to: CGPoint(x: x + 2.5, y: baselineY + 2.5))
                ctx.move(to: CGPoint(x: x + 2.5, y: baselineY - 2.5))
                ctx.addLine(to: CGPoint(x: x - 2.5, y: baselineY + 2.5))
                ctx.strokePath()
            } else {
                // Dot above baseline
                ctx.fillEllipse(in: CGRect(x: x - 1.5, y: baselineY - 4, width: 3, height: 3))
            }
        }
    }

    private func drawRisers(_ ctx: CGContext, frame: FeatureFrame, baselineY: CGFloat) {
        let riserCount = max(1, Int(frame.spectralCentroid * 3.0))
        let maxHeight = CGFloat(frame.spectralRolloff * 12.0)
        let step: CGFloat = 32.0 / CGFloat(riserCount + 1)

        ctx.setLineWidth(1)
        for i in 0..<riserCount {
            let x = step * CGFloat(i + 1)
            let height = maxHeight * CGFloat.random(in: 0.6...1.0)
            ctx.move(to: CGPoint(x: x, y: baselineY))
            ctx.addLine(to: CGPoint(x: x, y: max(baselineY - height, 2)))
            ctx.strokePath()
        }
    }

    private func drawMinuteMark(_ ctx: CGContext, baselineY: CGFloat) {
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 0, y: baselineY + 3))
        ctx.addLine(to: CGPoint(x: 3, y: baselineY + 3))
        ctx.strokePath()
    }
}
