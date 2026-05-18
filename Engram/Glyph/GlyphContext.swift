import CoreGraphics

struct GlyphContext {
    /// Current Y position of the baseline within the 32px glyph (0 = top, 31 = bottom).
    /// Starts at 16 (center) and drifts ±6px based on smoothed RMS.
    var baselineY: CGFloat = 16.0

    /// Total glyphs rendered since song start (incremented after each render).
    var glyphIndex: Int = 0

    /// Exponential moving average of RMS across the last ~30s (alpha=0.1 per 5s tick ≈ 30 ticks to decay).
    var smoothedRms: Float = 0.5

    /// Previous frame, for delta feature computation.
    var previousFrame: FeatureFrame? = nil

    /// Call after rendering each glyph to advance state.
    mutating func advance(with frame: FeatureFrame) {
        let alpha: Float = 0.1
        smoothedRms = alpha * frame.rms + (1.0 - alpha) * smoothedRms
        // Map smoothedRms (0–1) to baselineY: loud (1.0) → top (10), quiet (0.0) → bottom (22)
        baselineY = CGFloat(22.0 - smoothedRms * 12.0).clamped(to: 10.0...22.0)
        glyphIndex += 1
        previousFrame = frame
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
