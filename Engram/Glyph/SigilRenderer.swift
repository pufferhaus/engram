import CoreGraphics
import Foundation

struct SigilRenderer {

    // MARK: - Public API

    /// Render one 32×32 glyph. Advances `context` after drawing.
    func render(frame: FeatureFrame, context: inout GlyphContext) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: 32 * 32)
        let field = buildField(frame: frame, glyphIndex: context.glyphIndex)
        let seeds = buildSeeds(frame: frame, glyphIndex: context.glyphIndex)
        let fiberLen = Int((4.0 + frame.hpssRatio * 20.0).rounded())

        for seed in seeds {
            var fx = seed.x, fy = seed.y
            for _ in 0..<fiberLen {
                let ix = max(0, min(31, Int(fx.rounded())))
                let iy = max(0, min(31, Int(fy.rounded())))
                pixels[iy * 32 + ix] = 255
                let angle = field[iy * 32 + ix]
                fx += cos(angle) * 0.65
                fy += sin(angle) * 0.65
                if fx < 0 || fx >= 32 || fy < 0 || fy >= 32 { break }
            }
        }

        let image = makeImage(pixels: pixels)
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

    // MARK: - Field

    private func buildField(frame: FeatureFrame, glyphIndex: Int) -> [Float] {
        var field = [Float](repeating: 0, count: 32 * 32)
        let freq: Float = 2.0 + frame.spectralBandwidth * 3.5
        let indexOffset = Float(glyphIndex) * 0.13

        for y in 0..<32 {
            for x in 0..<32 {
                let nx = Float(x) / 32.0
                let ny = Float(y) / 32.0

                // chroma → field shape: each pitch class contributes a wave in its angular direction
                var wx: Float = 0, wy: Float = 0
                for i in 0..<12 {
                    let strength = frame.chroma[i]
                    guard strength > 0.02 else { continue }
                    let theta = Float(i) / 12.0 * .pi * 2.0
                    let phase = (nx * cos(theta) + ny * sin(theta)) * freq * .pi
                    wx += strength * cos(theta + phase)
                    wy += strength * sin(theta + phase)
                }

                var angle = atan2(wy, wx)

                // spectralFlatness → turbulence (0 = smooth curves, 1 = chaotic tangles)
                let n1 = hash(Float(x) + 0.1 + indexOffset, Float(y) + 0.3) * 2 - 1
                angle += n1 * frame.spectralFlatness * .pi * 0.9

                // deltaRms + deltaSpectralCentroid → burst of extra turbulence at transitions
                let delta = abs(frame.deltaRms) + abs(frame.deltaSpectralCentroid)
                if delta > 0.05 {
                    let n2 = hash(Float(x) + 7.3, Float(y) + 2.1 + indexOffset) * 2 - 1
                    angle += n2 * delta * .pi * 0.6
                }

                field[y * 32 + x] = angle
            }
        }
        return field
    }

    // MARK: - Seeds

    private func buildSeeds(frame: FeatureFrame, glyphIndex: Int) -> [(x: Float, y: Float)] {
        // rms → count · spectralCentroid → vertical band · spectralBandwidth → spread
        // onsetTimes → additional seeds at event positions
        let centroidY: Float = (1.0 - frame.spectralCentroid) * 26.0 + 3.0
        let spread: Float = 3.0 + frame.spectralBandwidth * 9.0
        let count = Int((6.0 + frame.rms * 34.0).rounded())
        let gi = Float(glyphIndex)

        var seeds: [(x: Float, y: Float)] = []
        seeds.reserveCapacity(count + frame.onsetTimes.count)

        for i in 0..<count {
            let fi = Float(i)
            let x = hash(fi * 7.31 + gi * 0.37, 42.1) * 31.0
            let yOff = (hash(fi * 13.7, 88.3 + gi * 0.19) * 2 - 1) * spread
            seeds.append((x: x, y: max(1, min(30, centroidY + yOff))))
        }

        for t in frame.onsetTimes {
            let yOff = (hash(t * 99.7, 3.14) * 2 - 1) * spread * 0.6
            seeds.append((x: t * 31.0, y: max(1, min(30, centroidY + yOff))))
        }

        return seeds
    }

    // MARK: - Utilities

    private func hash(_ x: Float, _ y: Float) -> Float {
        let v = sin(x * 127.1 + y * 311.7) * 43758.5453
        return v - floor(v)
    }

    private func makeImage(pixels: [UInt8]) -> CGImage {
        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        return CGImage(
            width: 32, height: 32,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
