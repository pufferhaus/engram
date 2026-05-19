import AVFoundation

final class MicCapture {
    private let engine = AVAudioEngine()
    private var ringBuffer: [Float] = []
    private var capacity: Int = 0
    private let windowSeconds: Double
    private let lock = NSLock()
    private(set) var sampleRate: Double = 44100

    init(windowSeconds: Double = 5.5) {
        self.windowSeconds = windowSeconds
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [AVAudioSession.CategoryOptions.allowBluetoothHFP])
        try session.setActive(true)

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        capacity = Int(sampleRate * windowSeconds)

        lock.lock()
        ringBuffer = [Float](repeating: 0, count: capacity)
        lock.unlock()

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

    /// Returns the last 5s of samples at the detected hardware sample rate.
    func snapshot() -> [Float] {
        let sampleCount = Int(sampleRate * 5.0)
        lock.lock()
        defer { lock.unlock() }
        let available = ringBuffer.count
        if available >= sampleCount {
            return Array(ringBuffer[(available - sampleCount)...])
        }
        return [Float](repeating: 0, count: sampleCount - available) + ringBuffer
    }

    private func write(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        ringBuffer.append(contentsOf: samples)
        if ringBuffer.count > capacity {
            ringBuffer.removeFirst(ringBuffer.count - capacity)
        }
    }
}
