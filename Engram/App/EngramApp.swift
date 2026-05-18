import SwiftUI

@main
struct EngramApp: App {
    @StateObject private var glyphState: GlyphState
    @StateObject private var cycle: AnalysisCycle

    init() {
        let state = GlyphState()
        _glyphState = StateObject(wrappedValue: state)
        _cycle = StateObject(wrappedValue: AnalysisCycle(glyphState: state))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Record", systemImage: "circle.fill") }
                    .environmentObject(glyphState)
                    .environmentObject(cycle)

                ArchiveBrowser()
                    .tabItem { Label("Archive", systemImage: "scroll") }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
        }
    }
}

// Temporary stub — replaced by real implementation in Task 15
struct ArchiveBrowser: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("ARCHIVE").foregroundStyle(.secondary)
        }
    }
}
