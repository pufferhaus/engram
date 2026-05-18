import XCTest
import CoreGraphics
@testable import Engram

@MainActor
final class GlyphStateTests: XCTestCase {
    let renderer = SigilRenderer()

    func testElevenGlyphsProduceNoRow() {
        let state = GlyphState()
        for i in 0..<11 {
            var ctx = GlyphContext()
            ctx.glyphIndex = i
            let glyph = renderer.render(frame: .synthetic(windowIndex: i), context: &ctx)
            let row = state.append(glyph: glyph, frame: .synthetic(windowIndex: i))
            XCTAssertNil(row)
        }
        XCTAssertEqual(state.currentRowGlyphs.count, 11)
    }

    func testTwelfthGlyphProducesRow() {
        let state = GlyphState()
        var lastRow: CGImage? = nil
        for i in 0..<12 {
            var ctx = GlyphContext()
            ctx.glyphIndex = i
            let glyph = renderer.render(frame: .synthetic(windowIndex: i), context: &ctx)
            lastRow = state.append(glyph: glyph, frame: .synthetic(windowIndex: i))
        }
        XCTAssertNotNil(lastRow)
        XCTAssertEqual(lastRow?.width, 384)
        XCTAssertEqual(lastRow?.height, 32)
    }

    func testRowBufferResetAfterCompletion() {
        let state = GlyphState()
        for i in 0..<12 {
            var ctx = GlyphContext()
            ctx.glyphIndex = i
            let glyph = renderer.render(frame: .synthetic(windowIndex: i), context: &ctx)
            _ = state.append(glyph: glyph, frame: .synthetic(windowIndex: i))
        }
        XCTAssertEqual(state.currentRowGlyphs.count, 0)
        XCTAssertEqual(state.rows.count, 1)
    }

    func testGlyphIndexTrackedViaContext() {
        let state = GlyphState()
        for i in 0..<13 {
            var ctx = GlyphContext()
            ctx.glyphIndex = i
            let glyph = renderer.render(frame: .synthetic(windowIndex: i), context: &ctx)
            _ = state.append(glyph: glyph, frame: .synthetic(windowIndex: i))
        }
        // After 13 glyphs, one full row (12) completed + 1 in progress
        XCTAssertEqual(state.rows.count, 1)
        XCTAssertEqual(state.currentRowGlyphs.count, 1)
    }

    func testResetClearsAll() {
        let state = GlyphState()
        for i in 0..<12 {
            var ctx = GlyphContext()
            ctx.glyphIndex = i
            let glyph = renderer.render(frame: .synthetic(windowIndex: i), context: &ctx)
            _ = state.append(glyph: glyph, frame: .synthetic(windowIndex: i))
        }
        state.reset()
        XCTAssertEqual(state.currentRowGlyphs.count, 0)
        XCTAssertEqual(state.rows.count, 0)
    }
}
