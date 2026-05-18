import XCTest
import CoreGraphics
@testable import Engram

final class SessionStoreTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveGlyphWritesPNGAndJSON() throws {
        let store = SessionStore(rootURL: tempDir, sessionName: "test-session", songIndex: 0)
        let glyph = makeGlyph()
        let frame = FeatureFrame.synthetic(windowIndex: 0)
        store.saveGlyph(glyph, frame: frame)

        let glyphDir = tempDir
            .appendingPathComponent("test-session")
            .appendingPathComponent("song-01")
            .appendingPathComponent("glyphs")

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: glyphDir.appendingPathComponent("0000_t000.png").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: glyphDir.appendingPathComponent("0000_t000.json").path))
    }

    func testSaveRowWritesPNG() throws {
        let store = SessionStore(rootURL: tempDir, sessionName: "test-session", songIndex: 0)
        let row = makeRow()
        store.saveRow(row, rowIndex: 0)

        let rowDir = tempDir
            .appendingPathComponent("test-session")
            .appendingPathComponent("song-01")
            .appendingPathComponent("rows")

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: rowDir.appendingPathComponent("row_000.png").path))
    }

    func testFinalizeWritesMetadata() throws {
        let store = SessionStore(rootURL: tempDir, sessionName: "test-session", songIndex: 0)
        store.finalize(glyphCount: 12, duration: 60.0)

        let metaURL = tempDir
            .appendingPathComponent("test-session")
            .appendingPathComponent("song-01")
            .appendingPathComponent("metadata.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: metaURL.path))
        let data = try Data(contentsOf: metaURL)
        let meta = try JSONDecoder().decode(SessionMetadata.self, from: data)
        XCTAssertEqual(meta.glyphCount, 12)
        XCTAssertEqual(meta.duration, 60.0, accuracy: 0.1)
    }

    // MARK: - Helpers

    private func makeGlyph() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 32, height: 32,
            bitsPerComponent: 8, bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return ctx.makeImage()!
    }

    private func makeRow() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 384, height: 32,
            bitsPerComponent: 8, bytesPerRow: 384,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 384, height: 32))
        return ctx.makeImage()!
    }
}
