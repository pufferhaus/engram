import XCTest
import CoreGraphics
@testable import Engram

final class PrintQueueTests: XCTestCase {

    func testJobsAreProcessedInOrder() async throws {
        let recorder = RecordingPrinter()
        let queue = PrintQueue(printer: recorder)
        let rows = (0..<3).map { makeRow(gray: Float($0) * 0.3) }

        for row in rows { queue.enqueue(row) }

        // Give the queue time to drain
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(recorder.printCount, 3)
    }

    func testQueueToleratesPrinterError() async throws {
        let failing = FailingPrinter()
        let queue = PrintQueue(printer: failing)
        queue.enqueue(makeRow(gray: 0.5))
        try await Task.sleep(nanoseconds: 500_000_000)
        // Should not crash — error logged but queue continues
        XCTAssertEqual(failing.attemptCount, 1)
    }

    // MARK: - Helpers

    private func makeRow(gray: Float) -> CGImage {
        let ctx = CGContext(
            data: nil, width: 384, height: 32,
            bitsPerComponent: 8, bytesPerRow: 384,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        )!
        ctx.setFillColor(gray: CGFloat(gray), alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 384, height: 32))
        return ctx.makeImage()!
    }
}

private final class RecordingPrinter: PrinterProtocol {
    var printCount = 0
    func printRow(_ image: CGImage) async throws { printCount += 1 }
}

private final class FailingPrinter: PrinterProtocol {
    var attemptCount = 0
    func printRow(_ image: CGImage) async throws {
        attemptCount += 1
        throw NSError(domain: "test", code: 1)
    }
}
