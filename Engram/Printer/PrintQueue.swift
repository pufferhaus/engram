import CoreGraphics
import Foundation
import os.log

final class PrintQueue: PrintQueueProtocol {
    private let printer: any PrinterProtocol
    private let logger = Logger(subsystem: "art.engram", category: "printQueue")
    private var workerTask: Task<Void, Never>?
    private let store = RowStore()

    init(printer: any PrinterProtocol) {
        self.printer = printer
        startWorker()
    }

    func enqueue(_ image: CGImage) {
        Task { await store.enqueue(image) }
    }

    private func startWorker() {
        workerTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let row = await self.store.dequeue() {
                    do {
                        try await self.printer.printRow(row)
                    } catch {
                        self.logger.error("PrintQueue: print failed — \(error.localizedDescription)")
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
    }

    deinit { workerTask?.cancel() }
}

private actor RowStore {
    var rows: [CGImage] = []
    func enqueue(_ image: CGImage) { rows.append(image) }
    func dequeue() -> CGImage? { rows.isEmpty ? nil : rows.removeFirst() }
}
