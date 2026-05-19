import AVFoundation
import CoreGraphics
import Foundation

// MARK: - Forward declarations
// Protocols defined here so AnalysisCycle compiles now.
// Tasks 10-12 create conforming types; Task 14 wires everything together.

protocol PrintQueueProtocol: AnyObject {
    func enqueue(_ image: CGImage)
}

protocol SessionStoreProtocol: AnyObject {
    func saveGlyph(_ image: CGImage, frame: FeatureFrame)
    func saveRow(_ image: CGImage, rowIndex: Int)
    func finalize(glyphCount: Int, duration: TimeInterval)
}

protocol StripStitcherProtocol: AnyObject {
    func appendRow(_ image: CGImage)
    func finalize()
}

// MARK: -

@MainActor
final class AnalysisCycle: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var latestGlyph: CGImage?
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    let glyphState: GlyphState
    private let micCapture: MicCapture
    private let featureExtractor: FeatureExtractor
    private let renderer: SigilRenderer

    // Set via configure() after Tasks 10-12 are implemented
    private var printQueue: (any PrintQueueProtocol)?
    private var sessionStore: (any SessionStoreProtocol)?
    private var stripStitcher: (any StripStitcherProtocol)?

    private var timer: Timer?
    private var startDate: Date?

    init(
        micCapture: MicCapture = MicCapture(),
        featureExtractor: FeatureExtractor = FeatureExtractor(),
        glyphState: GlyphState? = nil
    ) {
        self.micCapture = micCapture
        self.featureExtractor = featureExtractor
        self.renderer = SigilRenderer()
        self.glyphState = glyphState ?? GlyphState()
    }

    func configure(
        printQueue: any PrintQueueProtocol,
        sessionStore: any SessionStoreProtocol,
        stripStitcher: any StripStitcherProtocol
    ) {
        self.printQueue = printQueue
        self.sessionStore = sessionStore
        self.stripStitcher = stripStitcher
    }

    func start() throws {
        guard !isRunning else { return }
        try micCapture.start()
        featureExtractor.sampleRate = Float(micCapture.sampleRate)
        startDate = Date()
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.tick() }
        }
        // Fire immediately for first glyph
        Task { @MainActor [weak self] in await self?.tick() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        micCapture.stop()
        isRunning = false
        stripStitcher?.finalize()
        sessionStore?.finalize(
            glyphCount: glyphState.context.glyphIndex,
            duration: elapsedSeconds
        )
    }

    // MARK: - Tick

    private func tick() async {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        elapsedSeconds = elapsed

        let samples = micCapture.snapshot()
        let windowIndex = glyphState.context.glyphIndex
        let previousFrame = glyphState.context.previousFrame

        let frame = await Task.detached(priority: .userInitiated) { [featureExtractor] in
            featureExtractor.extract(
                samples: samples,
                windowIndex: windowIndex,
                timestamp: elapsed,
                previousFrame: previousFrame
            )
        }.value

        // Render: SigilRenderer advances context internally
        var ctx = glyphState.context
        let glyph = renderer.render(frame: frame, context: &ctx)
        glyphState.context = ctx
        latestGlyph = glyph

        // Persist glyph
        sessionStore?.saveGlyph(glyph, frame: frame)

        // Accumulate into row
        if let row = glyphState.append(glyph: glyph, frame: frame) {
            let rowIndex = glyphState.rows.count - 1
            printQueue?.enqueue(row)
            sessionStore?.saveRow(row, rowIndex: rowIndex)
            stripStitcher?.appendRow(row)
        }
    }
}
