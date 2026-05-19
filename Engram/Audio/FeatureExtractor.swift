import Accelerate
import Foundation

final class FeatureExtractor: @unchecked Sendable {
    var sampleRate: Float = 44100
    let fftSize: Int = 2048

    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    private var hannWindow: [Float]

    init() {
        self.log2n = vDSP_Length(log2(Float(2048)))
        self.fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(2048))), FFTRadix(kFFTRadix2))!
        self.hannWindow = [Float](repeating: 0, count: 2048)
        vDSP_hann_window(&hannWindow, vDSP_Length(2048), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func extract(
        samples: [Float],
        windowIndex: Int,
        timestamp: TimeInterval,
        previousFrame: FeatureFrame?
    ) -> FeatureFrame {
        let rms = computeRms(samples)
        let zcr = zeroCrossingRate(samples)
        let mags = spectrum(of: samples)
        let centroid = spectralCentroid(mags)
        let rolloff = spectralRolloff(mags)
        let bandwidth = spectralBandwidth(mags, centroid: centroid)
        let flatness = spectralFlatness(mags)
        let chroma = computeChroma(mags)
        let dominantPC = chroma.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let mfcc = computeMFCC(mags)
        let (onsetTimes, onsetDensity) = detectOnsets(samples)
        let hpssRatio = 1.0 - flatness  // high flatness = noisy = percussive
        let tempo = estimateTempo(onsetTimes: onsetTimes)

        let nyquist = sampleRate / 2
        let centroidNorm = min(centroid / nyquist, 1.0)
        let rolloffNorm = min(rolloff / nyquist, 1.0)
        let bandwidthNorm = min(bandwidth / nyquist, 1.0)

        let deltaRms = previousFrame.map { rms - $0.rms } ?? 0
        let deltaCentroid = previousFrame.map { centroidNorm - $0.spectralCentroid } ?? 0
        let deltaFlatness = previousFrame.map { flatness - $0.spectralFlatness } ?? 0

        return FeatureFrame(
            timestamp: timestamp, windowIndex: windowIndex,
            rms: rms, zeroCrossingRate: zcr,
            spectralCentroid: centroidNorm, spectralRolloff: rolloffNorm,
            spectralBandwidth: bandwidthNorm, spectralFlatness: flatness,
            onsetDensity: min(onsetDensity / 10.0, 1.0),
            onsetTimes: onsetTimes, tempo: tempo,
            chroma: chroma, dominantPitchClass: dominantPC,
            mfcc: mfcc, hpssRatio: hpssRatio,
            deltaRms: deltaRms, deltaSpectralCentroid: deltaCentroid,
            deltaSpectralFlatness: deltaFlatness
        )
    }

    // MARK: - RMS

    private func computeRms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_rmsqv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }

    // MARK: - Zero-Crossing Rate

    private func zeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var count: Float = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i - 1] >= 0) { count += 1 }
        }
        return count / Float(samples.count)
    }

    // MARK: - FFT

    private func spectrum(of samples: [Float]) -> [Float] {
        let n = fftSize
        let input = Array(samples.suffix(n).prefix(n))
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(input, 1, hannWindow, 1, &windowed, 1, vDSP_Length(n))

        var real = windowed
        var imaginary = [Float](repeating: 0, count: n)
        var magnitudes = [Float](repeating: 0, count: n / 2)
        real.withUnsafeMutableBufferPointer { realBuf in
            imaginary.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }

        // Sqrt for linear magnitude
        var result = [Float](repeating: 0, count: n / 2)
        vvsqrtf(&result, magnitudes, [Int32(n / 2)])

        // Scale
        var scale = 1.0 / Float(n)
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(n / 2))
        return result
    }

    // MARK: - Spectral Features

    private func spectralCentroid(_ mags: [Float]) -> Float {
        let freqBin = sampleRate / Float(fftSize)
        var weighted: Float = 0, total: Float = 0
        for (i, m) in mags.enumerated() {
            weighted += Float(i) * freqBin * m
            total += m
        }
        return total > 0 ? weighted / total : 0
    }

    private func spectralRolloff(_ mags: [Float], threshold: Float = 0.85) -> Float {
        let total = mags.reduce(0, +)
        guard total > 0 else { return 0 }
        let freqBin = sampleRate / Float(fftSize)
        var cumSum: Float = 0
        for (i, m) in mags.enumerated() {
            cumSum += m
            if cumSum >= total * threshold {
                return Float(i) * freqBin
            }
        }
        return sampleRate / 2
    }

    private func spectralBandwidth(_ mags: [Float], centroid: Float) -> Float {
        let freqBin = sampleRate / Float(fftSize)
        var weighted: Float = 0, total: Float = 0
        for (i, m) in mags.enumerated() {
            let freq = Float(i) * freqBin
            weighted += (freq - centroid) * (freq - centroid) * m
            total += m
        }
        return total > 0 ? sqrt(weighted / total) : 0
    }

    private func spectralFlatness(_ mags: [Float]) -> Float {
        let valid = mags.filter { $0 > 1e-10 }
        guard !valid.isEmpty else { return 0 }
        let logMean = valid.map { log($0) }.reduce(0, +) / Float(valid.count)
        let geoMean = exp(logMean)
        let arithMean = valid.reduce(0, +) / Float(valid.count)
        return arithMean > 0 ? min(geoMean / arithMean, 1.0) : 0
    }

    // MARK: - Chroma

    private func computeChroma(_ mags: [Float]) -> [Float] {
        var chroma = [Float](repeating: 0, count: 12)
        let freqBin = sampleRate / Float(fftSize)
        for (i, m) in mags.enumerated() {
            let freq = Float(i) * freqBin
            guard freq >= 27.5, freq <= 4186 else { continue }
            let midi = 12.0 * log2(freq / 440.0) + 69.0
            let pc = Int(midi.rounded()) % 12
            chroma[pc < 0 ? pc + 12 : pc] += m
        }
        let sum = chroma.reduce(0, +)
        return sum > 0 ? chroma.map { $0 / sum } : chroma
    }

    // MARK: - MFCC (simplified)

    private func computeMFCC(_ mags: [Float], count: Int = 4) -> [Float] {
        let n = mags.count
        let logMags = mags.map { log(max($0, 1e-10)) }
        return (0..<count).map { k in
            var sum: Float = 0
            for (i, lm) in logMags.enumerated() {
                sum += lm * cos(Float.pi * Float(k) * (Float(i) + 0.5) / Float(n))
            }
            return sum / Float(n)
        }
    }

    // MARK: - Onset Detection

    private func detectOnsets(_ samples: [Float]) -> ([Float], Float) {
        // Divide 5s buffer into overlapping 0.5s windows (hop = 0.25s)
        let windowSamples = Int(sampleRate * 0.5)
        let hopSamples = Int(sampleRate * 0.25)
        let totalSamples = samples.count
        var fluxValues: [(time: Float, flux: Float)] = []
        var prevMags = [Float](repeating: 0, count: fftSize / 2)

        var offset = 0
        while offset + windowSamples <= totalSamples {
            let chunk = Array(samples[offset..<offset + windowSamples])
            let padded = chunk + [Float](repeating: 0, count: max(0, fftSize - chunk.count))
            let mags = spectrum(of: padded)
            var flux: Float = 0
            for (i, m) in mags.enumerated() {
                flux += max(m - prevMags[i], 0)
            }
            let time = Float(offset + windowSamples / 2) / (sampleRate * 5.0)
            fluxValues.append((time: time, flux: flux))
            prevMags = mags
            offset += hopSamples
        }

        guard !fluxValues.isEmpty else { return ([], 0) }
        let fluxOnly = fluxValues.map { $0.flux }
        var mean: Float = 0
        vDSP_meanv(fluxOnly, 1, &mean, vDSP_Length(fluxOnly.count))
        var sqMean: Float = 0
        vDSP_measqv(fluxOnly, 1, &sqMean, vDSP_Length(fluxOnly.count))
        let stdDev = sqrt(max(sqMean - mean * mean, 0))
        let threshold = mean + 1.5 * stdDev

        var onsetTimes: [Float] = []
        for i in 1..<(fluxValues.count - 1) {
            let f = fluxValues[i]
            if f.flux > threshold,
               f.flux >= fluxValues[i - 1].flux,
               f.flux >= fluxValues[i + 1].flux {
                onsetTimes.append(f.time)
            }
        }

        let density = Float(onsetTimes.count) / 5.0
        return (onsetTimes, density)
    }

    // MARK: - Tempo

    private func estimateTempo(onsetTimes: [Float]) -> Float {
        guard onsetTimes.count >= 2 else { return 0.5 }
        let intervals = zip(onsetTimes, onsetTimes.dropFirst()).map { $1 - $0 }
        let avgInterval = intervals.reduce(0, +) / Float(intervals.count)
        guard avgInterval > 0 else { return 0.5 }
        let bpm = 60.0 / (avgInterval * 5.0)
        return ((bpm - 60) / 180).clamped(to: 0...1)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
