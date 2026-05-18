import AVFoundation

final class MicCapture {
    private let engine = AVAudioEngine()
    private var ringBuffer: [Float]
    private let capacity: Int
    private let lock = NSLock()

    /// `windowSeconds` should be slightly more than 5.0 to ensure snapshot always has enough data.
    init(sampleRate: Double = 44100, windowSeconds: Double = 5.5) {
        self.capacity = Int(sampleRate * windowSeconds)
        self.ringBuffer = [Float](repeating: 0, count: Int(sampleRate * windowSeconds))
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
        try session.setActive(true)

        let inputNode = engine.inputNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] audioBuffer, _ in
            guard let self,
                  let channelData = audioBuffer.floatChannelData?[0] else { return }
            let frameCount = Int(audioBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            self.write(samples)
        }

        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Returns the last `sampleCount` samples. Zero-pads at the front if fewer samples are available.
    func snapshot(sampleCount: Int = 44100 * 5) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        let available = ringBuffer.count
        if available >= sampleCount {
            return Array(ringBuffer[(available - sampleCount)...])
        }
        return [Float](repeating: 0, count: sampleCount - available) + ringBuffer
    }

    // MARK: - Private

    private func write(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        ringBuffer.append(contentsOf: samples)
        if ringBuffer.count > capacity {
            ringBuffer.removeFirst(ringBuffer.count - capacity)
        }
    }
}
