import SwiftUI
import CoreGraphics
import ImageIO

struct StripDetailView: View {
    let songRecord: SongRecord
    @State private var stripImage: CGImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = stripImage {
                StripScrollView(image: image)
            } else if FileManager.default.fileExists(atPath: songRecord.stripURL.path) {
                ProgressView().tint(.white)
            } else {
                Text("No strip recorded yet.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .navigationTitle(songRecord.sessionName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStrip() }
        .preferredColorScheme(.dark)
    }

    private func loadStrip() {
        Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: songRecord.stripURL),
                  let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(src, 0, nil)
            else { return }
            await MainActor.run { stripImage = image }
        }
    }
}
