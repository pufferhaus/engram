import Foundation

struct FeatureFrame: Codable {
    // Identity
    let timestamp: TimeInterval   // seconds since song start
    let windowIndex: Int          // 0-based, increments each 5s tick

    // Loudness
    let rms: Float                // 0.0–1.0 (normalized)

    // Time domain
    let zeroCrossingRate: Float   // crossings per sample, 0–1

    // Spectral (all normalized 0–1 relative to Nyquist or max)
    let spectralCentroid: Float
    let spectralRolloff: Float
    let spectralBandwidth: Float
    let spectralFlatness: Float   // 0 = tonal, 1 = noisy

    // Rhythm
    let onsetDensity: Float       // onsets per second, normalized 0–1 (max assumed 10/s)
    let onsetTimes: [Float]       // onset positions within window, each 0.0–1.0
    let tempo: Float              // BPM normalized: 0=(60 BPM), 1=(240 BPM)

    // Pitch
    let chroma: [Float]           // 12 values, each 0–1, sums to 1
    let dominantPitchClass: Int   // 0–11 (C=0, C#=1, … B=11)

    // Timbre
    let mfcc: [Float]             // 4 coefficients, each normalized -1–1

    // HPSS approximation
    let hpssRatio: Float          // 0.0 = fully percussive, 1.0 = fully harmonic

    // Deltas (0.0 for the first frame)
    let deltaRms: Float
    let deltaSpectralCentroid: Float
    let deltaSpectralFlatness: Float
}

extension FeatureFrame {
    static func silence(timestamp: TimeInterval, windowIndex: Int) -> FeatureFrame {
        FeatureFrame(
            timestamp: timestamp, windowIndex: windowIndex,
            rms: 0, zeroCrossingRate: 0,
            spectralCentroid: 0.5, spectralRolloff: 0.5,
            spectralBandwidth: 0.3, spectralFlatness: 0.5,
            onsetDensity: 0, onsetTimes: [], tempo: 0.5,
            chroma: [Float](repeating: 1.0 / 12.0, count: 12),
            dominantPitchClass: 0,
            mfcc: [0, 0, 0, 0],
            hpssRatio: 0.5,
            deltaRms: 0, deltaSpectralCentroid: 0, deltaSpectralFlatness: 0
        )
    }

    static func synthetic(
        rms: Float = 0.5,
        spectralCentroid: Float = 0.5,
        spectralFlatness: Float = 0.3,
        onsetTimes: [Float] = [0.2, 0.5, 0.8],
        hpssRatio: Float = 0.5,
        dominantPitchClass: Int = 0,
        timestamp: TimeInterval = 0,
        windowIndex: Int = 0
    ) -> FeatureFrame {
        var chroma = [Float](repeating: 0, count: 12)
        chroma[dominantPitchClass] = 1.0
        return FeatureFrame(
            timestamp: timestamp, windowIndex: windowIndex,
            rms: rms, zeroCrossingRate: spectralFlatness * 0.5,
            spectralCentroid: spectralCentroid,
            spectralRolloff: min(spectralCentroid * 1.3, 1.0),
            spectralBandwidth: 0.3, spectralFlatness: spectralFlatness,
            onsetDensity: Float(onsetTimes.count) / 5.0,
            onsetTimes: onsetTimes, tempo: 0.5,
            chroma: chroma, dominantPitchClass: dominantPitchClass,
            mfcc: [0.1, -0.05, 0.02, -0.01],
            hpssRatio: hpssRatio,
            deltaRms: 0, deltaSpectralCentroid: 0, deltaSpectralFlatness: 0
        )
    }
}
