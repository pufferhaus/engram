import CoreGraphics
import Foundation
import os.log

final class PrintQueue: PrintQueueProtocol {
    private let printer: any PrinterProtocol
    private let logger = Logger(subsystem: "art.engram", category: "printQueue")
    private var workerTask: Task<Void, Never>?
    private var pendingRows: [CGImage] = []
    private let lock = NSLock()

    init(printer: any PrinterProtocol) {
        self.printer = printer
        startWorker()
    }

    func enqueue(_ image: CGImage) {
        lock.lock()
        pendingRows.append(image)
        lock.unlock()
    }

    private func startWorker() {
        workerTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.lock.lock()
                let row = self.pendingRows.isEmpty ? nil : self.pendingRows.removeFirst()
                self.lock.unlock()

                if let row {
                    do {
                        try await self.printer.printRow(row)
                    } catch {
                        self.logger.error("PrintQueue: print failed — \(error.localizedDescription)")
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms poll
                }
            }
        }
    }

    deinit { workerTask?.cancel() }
}
