import SwiftUI
import CoreGraphics

struct RendererPreviewView: View {
    @State private var rms: Double = 0.5
    @State private var spectralCentroid: Double = 0.5
    @State private var spectralFlatness: Double = 0.3
    @State private var hpssRatio: Double = 0.5
    @State private var dominantPitchClass: Double = 0
    @State private var onsetCount: Double = 3

    private let renderer = SigilRenderer()

    private var frame: FeatureFrame {
        let pitchClass = Int(dominantPitchClass)
        let onsets = (0..<Int(onsetCount)).map { Float($0 + 1) / Float(Int(onsetCount) + 1) }
        return FeatureFrame.synthetic(
            rms: Float(rms),
            spectralCentroid: Float(spectralCentroid),
            spectralFlatness: Float(spectralFlatness),
            onsetTimes: onsets,
            hpssRatio: Float(hpssRatio),
            dominantPitchClass: pitchClass
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("RENDERER PREVIEW")
                    .font(.caption).fontWeight(.black).foregroundStyle(.secondary)

                // Live glyph row (12 cells, same frame repeated)
                glyphRow

                // Sliders
                Group {
                    slider("RMS (loudness)", value: $rms)
                    slider("Spectral Centroid (brightness)", value: $spectralCentroid)
                    slider("Spectral Flatness (noise)", value: $spectralFlatness)
                    slider("HPSS Ratio (0=perc, 1=harm)", value: $hpssRatio)
                    slider("Dominant Pitch Class (0–11)", value: $dominantPitchClass, range: 0...11, step: 1)
                    slider("Onset Count (0–6)", value: $onsetCount, range: 0...6, step: 1)
                }
            }
            .padding()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var glyphRow: some View {
        HStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { i in
                glyphCell(index: i)
            }
        }
        .background(Color.black)
    }

    private func glyphCell(index: Int) -> some View {
        var ctx = GlyphContext()
        ctx.glyphIndex = index
        let image = renderer.render(frame: frame, context: &ctx)
        return Image(uiImage: UIImage(cgImage: image))
            .resizable()
            .frame(width: 32, height: 32)
            .background(Color.black)
    }

    private func slider(
        _ label: String, value: Binding<Double>,
        range: ClosedRange<Double> = 0...1, step: Double = 0.01
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Slider(value: value, in: range, step: step)
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospaced())
                    .frame(width: 44)
            }
        }
    }
}

#Preview {
    RendererPreviewView()
}
