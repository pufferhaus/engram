import SwiftUI

struct SongRecord: Identifiable {
    let id = UUID()
    let sessionName: String
    let songDir: URL
    let stripURL: URL
    let metadata: SessionMetadata?
}

struct ArchiveBrowser: View {
    @State private var songs: [SongRecord] = []

    private var setsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sets")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if songs.isEmpty {
                    Text("No recordings yet.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    List(songs) { song in
                        NavigationLink {
                            StripDetailView(songRecord: song)
                        } label: {
                            songRow(song)
                        }
                        .listRowBackground(Color(white: 0.05))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("ARCHIVE")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadSongs() }
        }
        .preferredColorScheme(.dark)
    }

    private func songRow(_ song: SongRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.sessionName)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
            if let meta = song.metadata {
                Text("\(meta.glyphCount) glyphs · \(formatDuration(meta.duration))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadSongs() {
        var records: [SongRecord] = []
        let fm = FileManager.default
        guard let sessions = try? fm.contentsOfDirectory(
            at: setsDir, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        for session in sessions {
            guard let songDirs = try? fm.contentsOfDirectory(
                at: session, includingPropertiesForKeys: nil
            ) else { continue }
            for songDir in songDirs where songDir.lastPathComponent.hasPrefix("song-") {
                let stripURL = songDir.appendingPathComponent("full-strip.png")
                let metaURL = songDir.appendingPathComponent("metadata.json")
                let meta = (try? Data(contentsOf: metaURL))
                    .flatMap { try? JSONDecoder().decode(SessionMetadata.self, from: $0) }
                records.append(SongRecord(
                    sessionName: session.lastPathComponent,
                    songDir: songDir,
                    stripURL: stripURL,
                    metadata: meta
                ))
            }
        }
        songs = records.sorted { $0.sessionName > $1.sessionName }
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        let m = Int(d) / 60; let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }
}
