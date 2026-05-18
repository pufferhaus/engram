import CoreGraphics
import Foundation
import os.log

final class ConsolePrinter: PrinterProtocol {
    private var rowCount = 0
    private let logger = Logger(subsystem: "art.engram", category: "printer")

    func printRow(_ image: CGImage) async throws {
        rowCount += 1
        logger.info("ConsolePrinter: row \(self.rowCount) (\(image.width)×\(image.height)px)")
    }
}
