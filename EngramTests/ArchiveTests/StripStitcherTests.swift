import XCTest
import CoreGraphics
@testable import Engram

final class StripStitcherTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testEmptyStitcherProducesNoFile() {
        let stitcher = StripStitcher(outputURL: tempDir.appendingPathComponent("strip.png"))
        stitcher.finalize()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("strip.png").path))
    }

    func testOneRowProducesFile() {
        let stitcher = StripStitcher(outputURL: tempDir.appendingPathComponent("strip.png"))
        stitcher.appendRow(makeRow())
        stitcher.finalize()
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("strip.png").path))
    }

    func testAppendRowWritesFileImmediately() {
        let url = tempDir.appendingPathComponent("strip.png")
        let stitcher = StripStitcher(outputURL: url)
        stitcher.appendRow(makeRow())
        // appendRow should write immediately (not just on finalize)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testTwoRowsDoubleHeight() throws {
        let url = tempDir.appendingPathComponent("strip.png")
        let stitcher = StripStitcher(outputURL: url)
        stitcher.appendRow(makeRow())
        stitcher.appendRow(makeRow())
        stitcher.finalize()

        let data = try Data(contentsOf: url)
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(src, 0, nil)!
        XCTAssertEqual(image.width, 384)
        XCTAssertEqual(image.height, 64)  // 2 × 32
    }

    // MARK: - Helper

    private func makeRow() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: nil, width: 384, height: 32,
            bitsPerComponent: 8, bytesPerRow: 384,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.setFillColor(gray: 0.5, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 384, height: 32))
        return ctx.makeImage()!
    }
}
