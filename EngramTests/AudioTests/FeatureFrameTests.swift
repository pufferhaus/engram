import XCTest
@testable import Engram

final class FeatureFrameTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let frame = FeatureFrame.synthetic()
        let data = try JSONEncoder().encode(frame)
        let decoded = try JSONDecoder().decode(FeatureFrame.self, from: data)
        XCTAssertEqual(decoded.rms, frame.rms, accuracy: 0.0001)
        XCTAssertEqual(decoded.dominantPitchClass, frame.dominantPitchClass)
        XCTAssertEqual(decoded.chroma.count, 12)
        XCTAssertEqual(decoded.mfcc.count, 4)
        XCTAssertEqual(decoded.onsetTimes.count, frame.onsetTimes.count)
    }

    func testSilenceFactory() {
        let frame = FeatureFrame.silence(timestamp: 10.0, windowIndex: 2)
        XCTAssertEqual(frame.rms, 0.0)
        XCTAssertEqual(frame.timestamp, 10.0)
        XCTAssertEqual(frame.windowIndex, 2)
        XCTAssertTrue(frame.onsetTimes.isEmpty)
    }

    func testSyntheticFactory() {
        let frame = FeatureFrame.synthetic(rms: 0.8, dominantPitchClass: 7)
        XCTAssertEqual(frame.rms, 0.8, accuracy: 0.0001)
        XCTAssertEqual(frame.dominantPitchClass, 7)
        XCTAssertEqual(frame.chroma[7], 1.0, accuracy: 0.0001)
    }
}
