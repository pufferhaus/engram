import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import os.log

final class MockPrinter: PrinterProtocol {
    private let outputDir: URL
    private var rowCount = 0
    private let logger = Logger(subsystem: "art.engram", category: "printer")

    init() {
        outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("engram-preview")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func printRow(_ image: CGImage) async throws {
        rowCount += 1
        let name = String(format: "row_%03d.png", rowCount)
        let url = outputDir.appendingPathComponent(name)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        logger.info("MockPrinter: saved \(name) to Desktop/engram-preview/")
    }
}
