import SwiftUI

struct ContentView: View {
    @EnvironmentObject var cycle: AnalysisCycle
    @EnvironmentObject var glyphState: GlyphState

    @State private var showingStrip = false
    @State private var errorMessage: String?
    @State private var sessionName = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 32) {
                    // Status
                    HStack(spacing: 12) {
                        statusBadge
                        Spacer()
                        counterLabel
                    }
                    .padding(.horizontal)

                    // Live row preview (12 cells)
                    liveRowPreview

                    Spacer()

                    // Session name field (only when stopped)
                    if !cycle.isRunning {
                        TextField("Session name", text: $sessionName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color(white: 0.08))
                            .overlay(Rectangle().stroke(Color(white: 0.15), lineWidth: 1))
                            .padding(.horizontal)
                    }

                    // Start / Stop
                    startStopButton

                    // View strip button
                    if !glyphState.rows.isEmpty || !glyphState.currentRowGlyphs.isEmpty {
                        NavigationLink("View Strip →") {
                            LiveStripView(glyphState: glyphState)
                                .navigationTitle("ENGRAM STRIP")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("ENGRAM")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: cycle.isRunning) { running in
                UIApplication.shared.isIdleTimerDisabled = running
                if running { UIScreen.main.brightness = 1.0 }
            }
        }
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(cycle.isRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(cycle.isRunning ? "RECORDING" : "STOPPED")
                .font(.caption.monospaced())
                .foregroundStyle(cycle.isRunning ? .green : .secondary)
        }
    }

    private var counterLabel: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(glyphState.context.glyphIndex) glyphs")
                .font(.caption.monospaced())
            Text(formatElapsed(cycle.elapsedSeconds))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var liveRowPreview: some View {
        HStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { i in
                if i < glyphState.currentRowGlyphs.count {
                    let glyph = glyphState.currentRowGlyphs[i]
                    Image(uiImage: UIImage(cgImage: glyph))
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Rectangle()
                        .fill(Color(white: 0.05))
                        .frame(width: 28, height: 28)
                        .overlay(Rectangle().stroke(Color(white: 0.1), lineWidth: 0.5))
                }
            }
        }
        .background(Color.black)
    }

    private var startStopButton: some View {
        Button {
            if cycle.isRunning {
                cycle.stop()
            } else {
                startRecording()
            }
        } label: {
            Text(cycle.isRunning ? "STOP" : "START")
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundStyle(cycle.isRunning ? .red : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color(white: cycle.isRunning ? 0.08 : 0.05))
                .overlay(
                    Rectangle()
                        .stroke(cycle.isRunning ? Color.red.opacity(0.5) : Color(white: 0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func startRecording() {
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let setsDir = docs.appendingPathComponent("sets")
            let store = SessionStore(rootURL: setsDir, sessionName: sessionName, songIndex: 0)
            let stitcher = StripStitcher(outputURL: store.songDir.appendingPathComponent("full-strip.png"))
            #if DEBUG
            let printer: any PrinterProtocol = MockPrinter()
            #else
            let printer: any PrinterProtocol = ConsolePrinter()
            #endif
            let queue = PrintQueue(printer: printer)
            cycle.configure(printQueue: queue, sessionStore: store, stripStitcher: stitcher)
            try cycle.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
