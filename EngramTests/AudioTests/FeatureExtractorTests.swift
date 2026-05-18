import XCTest
import Accelerate
@testable import Engram

final class FeatureExtractorTests: XCTestCase {
    let extractor = FeatureExtractor()
    let sampleCount = 44100 * 5

    func testSilenceRmsIsZero() {
        let samples = [Float](repeating: 0, count: sampleCount)
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertEqual(frame.rms, 0.0, accuracy: 0.001)
    }

    func testSineRmsIsHalfRoot2() {
        // Pure 440Hz sine at amplitude 1.0 → RMS ≈ 0.707
        let sr = 44100
        let samples = (0..<sampleCount).map { Float(sin(2 * Double.pi * 440 * Double($0) / Double(sr))) }
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertEqual(frame.rms, 0.707, accuracy: 0.01)
    }

    func testWhiteNoiseHasHighSpectralFlatness() {
        var samples = [Float](repeating: 0, count: sampleCount)
        for i in 0..<samples.count { samples[i] = Float.random(in: -1...1) }
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertGreaterThan(frame.spectralFlatness, 0.4,
            "White noise should have high spectral flatness (>0.4)")
    }

    func testSineHasLowSpectralFlatness() {
        let sr = 44100
        let samples = (0..<sampleCount).map { Float(sin(2 * Double.pi * 440 * Double($0) / Double(sr))) }
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertLessThan(frame.spectralFlatness, 0.3,
            "Pure sine should have low spectral flatness (<0.3)")
    }

    func testChromaHas12Bins() {
        let samples = [Float](repeating: 0, count: sampleCount)
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertEqual(frame.chroma.count, 12)
    }

    func testMfccHas4Coefficients() {
        let samples = [Float](repeating: 0, count: sampleCount)
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertEqual(frame.mfcc.count, 4)
    }

    func testDeltaRmsIsZeroForFirstFrame() {
        let samples = [Float](repeating: 0.5, count: sampleCount)
        let frame = extractor.extract(samples: samples, windowIndex: 0, timestamp: 0, previousFrame: nil)
        XCTAssertEqual(frame.deltaRms, 0, accuracy: 0.001)
    }

    func testDeltaRmsReflectsChangeFromPreviousFrame() {
        let sr = 44100
        let loud = (0..<sampleCount).map { Float(sin(2 * Double.pi * 440 * Double($0) / Double(sr))) }
        let quiet = [Float](repeating: 0, count: sampleCount)

        let prevFrame = extractor.extract(samples: loud, windowIndex: 0, timestamp: 0, previousFrame: nil)
        let nextFrame = extractor.extract(samples: quiet, windowIndex: 1, timestamp: 5, previousFrame: prevFrame)
        XCTAssertLessThan(nextFrame.deltaRms, -0.1, "Transition loud→quiet should have negative deltaRms")
    }

    func testWindowIndexAndTimestampPassThrough() {
        let samples = [Float](repeating: 0, count: sampleCount)
        let frame = extractor.extract(samples: samples, windowIndex: 7, timestamp: 35.0, previousFrame: nil)
        XCTAssertEqual(frame.windowIndex, 7)
        XCTAssertEqual(frame.timestamp, 35.0, accuracy: 0.001)
    }
}
