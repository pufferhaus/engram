import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SessionMetadata: Codable {
    let sessionName: String
    let songIndex: Int
    let startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var glyphCount: Int
}

final class SessionStore: SessionStoreProtocol {
    let songDir: URL
    private let glyphDir: URL
    private let rowsDir: URL
    private let csvURL: URL
    private let metaURL: URL
    private var csvHeaderWritten = false
    private var metadata: SessionMetadata
    private var saveIndex = 0

    init(rootURL: URL, sessionName: String, songIndex: Int) {
        let songName = String(format: "song-%02d", songIndex + 1)
        songDir = rootURL.appendingPathComponent(sessionName).appendingPathComponent(songName)
        glyphDir = songDir.appendingPathComponent("glyphs")
        rowsDir = songDir.appendingPathComponent("rows")
        csvURL = songDir.appendingPathComponent("features.csv")
        metaURL = songDir.appendingPathComponent("metadata.json")

        try? FileManager.default.createDirectory(at: glyphDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: rowsDir, withIntermediateDirectories: true)

        metadata = SessionMetadata(
            sessionName: sessionName, songIndex: songIndex,
            startDate: Date(), duration: 0, glyphCount: 0
        )
    }

    func saveGlyph(_ image: CGImage, frame: FeatureFrame) {
        let index = saveIndex
        saveIndex += 1
        let t = Int(frame.timestamp)
        let baseName = String(format: "%04d_t%03d", index, t)

        writePNG(image, to: glyphDir.appendingPathComponent("\(baseName).png"))

        if let data = try? JSONEncoder().encode(frame) {
            try? data.write(to: glyphDir.appendingPathComponent("\(baseName).json"))
        }

        appendCSVRow(frame, index: index)
    }

    func saveRow(_ image: CGImage, rowIndex: Int) {
        let name = String(format: "row_%03d.png", rowIndex)
        writePNG(image, to: rowsDir.appendingPathComponent(name))
    }

    func finalize(glyphCount: Int, duration: TimeInterval) {
        metadata.endDate = Date()
        metadata.duration = duration
        metadata.glyphCount = glyphCount
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metaURL)
        }
    }

    // MARK: - Private

    private func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func appendCSVRow(_ frame: FeatureFrame, index: Int) {
        if !csvHeaderWritten {
            let header = "index,timestamp,rms,zcr,centroid,rolloff,bandwidth,flatness,onsetDensity,tempo,dominantPitchClass,hpssRatio,deltaRms,deltaCentroid,deltaFlatness\n"
            try? header.write(to: csvURL, atomically: false, encoding: .utf8)
            csvHeaderWritten = true
        }
        let row = "\(index),\(frame.timestamp),\(frame.rms),\(frame.zeroCrossingRate)," +
            "\(frame.spectralCentroid),\(frame.spectralRolloff),\(frame.spectralBandwidth)," +
            "\(frame.spectralFlatness),\(frame.onsetDensity),\(frame.tempo)," +
            "\(frame.dominantPitchClass),\(frame.hpssRatio)," +
            "\(frame.deltaRms),\(frame.deltaSpectralCentroid),\(frame.deltaSpectralFlatness)\n"
        if let handle = try? FileHandle(forWritingTo: csvURL) {
            handle.seekToEndOfFile()
            handle.write(row.data(using: .utf8)!)
            handle.closeFile()
        }
    }
}
