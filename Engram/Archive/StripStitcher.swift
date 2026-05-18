import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

final class StripStitcher: StripStitcherProtocol {
    private let outputURL: URL
    private var rows: [CGImage] = []

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    /// Append a row and immediately rewrite full-strip.png so the file is always current.
    func appendRow(_ image: CGImage) {
        rows.append(image)
        finalize()
    }

    /// Write all accumulated rows as a vertically-stacked PNG.
    func finalize() {
        guard !rows.isEmpty else { return }
        let totalHeight = rows.reduce(0) { $0 + $1.height }
        let width = rows[0].width

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let ctx = CGContext(
            data: nil, width: width, height: totalHeight,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else { return }

        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

        // CGContext origin is bottom-left; draw rows top-to-bottom
        var y = totalHeight
        for row in rows {
            y -= row.height
            ctx.draw(row, in: CGRect(x: 0, y: y, width: row.width, height: row.height))
        }

        guard let image = ctx.makeImage() else { return }
        writePNG(image, to: outputURL)
    }

    private func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
