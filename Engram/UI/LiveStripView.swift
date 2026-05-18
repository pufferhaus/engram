import SwiftUI
import CoreGraphics

struct LiveStripView: View {
    @ObservedObject var glyphState: GlyphState

    private var stripImage: CGImage? {
        let completedRows = glyphState.rows
        let partialGlyphs = glyphState.currentRowGlyphs
        guard !completedRows.isEmpty || !partialGlyphs.isEmpty else { return nil }

        var allRows = completedRows
        if !partialGlyphs.isEmpty {
            if let partial = compositePartialRow(partialGlyphs) {
                allRows.append(partial)
            }
        }
        return stitchRows(allRows)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = stripImage {
                StripScrollView(image: image)
            } else {
                Text("Waiting for first glyph...")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private func compositePartialRow(_ glyphs: [CGImage]) -> CGImage? {
        guard !glyphs.isEmpty else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: nil, width: 384, height: 32,
            bitsPerComponent: 8, bytesPerRow: 384,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 384, height: 32))
        for (i, glyph) in glyphs.enumerated() {
            ctx.draw(glyph, in: CGRect(x: i * 32, y: 0, width: 32, height: 32))
        }
        return ctx.makeImage()
    }

    private func stitchRows(_ rows: [CGImage]) -> CGImage? {
        let totalHeight = rows.reduce(0) { $0 + $1.height }
        guard totalHeight > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: nil, width: 384, height: totalHeight,
            bitsPerComponent: 8, bytesPerRow: 384,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 384, height: totalHeight))
        var y = totalHeight
        for row in rows {
            y -= row.height
            ctx.draw(row, in: CGRect(x: 0, y: y, width: row.width, height: row.height))
        }
        return ctx.makeImage()
    }
}
