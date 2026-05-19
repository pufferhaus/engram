# engram

iOS app that listens to live audio and generates a continuous thermal print strip — a procedural visual record of a performance.

Every 5 seconds, the mic captures a window of audio. A spectral analysis pipeline extracts features from it. Those features drive a flow fiber renderer that draws a unique 32×32 pixel glyph. Twelve glyphs composite into a 384×32 row. Rows accumulate into a strip meant to scroll out of a thermal printer in real time.

No two performances produce the same strip.

---

## How it works

```
mic → ring buffer → FeatureExtractor → SigilRenderer → GlyphState → PrintQueue
                         (5s tick)           (32×32)     (384×32 rows)
```

**Audio pipeline** (`Audio/`)
- `MicCapture` — ring buffer at hardware sample rate (48 kHz on device)
- `FeatureExtractor` — vDSP FFT → spectral centroid, rolloff, bandwidth, flatness, chroma, MFCC, onset detection, HPSS ratio, tempo

**Glyph renderer** (`Glyph/`)
- `SigilRenderer` — flow fiber algorithm. Builds a 32×32 vector field from chroma interference waves, traces streamlines through it. Each pixel is computed, not drawn.
  - `chroma[12]` → field shape (each pitch class bends the field in its angular direction)
  - `hpssRatio` → fiber length (harmonic = long smooth curves, percussive = short tangles)
  - `rms` → seed density (loud = dense, quiet = sparse)
  - `spectralFlatness` → turbulence (tonal = smooth, noise = chaotic)
  - `onsetTimes` → seed positions (rhythmic events leave their mark)
  - `deltaRms / deltaSpectralCentroid` → burst turbulence at transitions
- `GlyphContext` — smoothed RMS, glyph index, previous frame (persists across renders)
- `GlyphState` — accumulates 12 glyphs into a 384×32 composited row

**Pipeline** (`Pipeline/`)
- `AnalysisCycle` — 5s `Timer` drives the full mic → features → glyph → row cycle

**Archive** (`Archive/`)
- `SessionStore` — saves glyphs and rows as PNGs to `Documents/sets/<session>/`
- `StripStitcher` — composites all rows into a single full-strip PNG on stop

**Printer** (`Printer/`)
- `PrintQueue` — actor-backed async queue; dequeues rows and sends to printer
- `PrinterProtocol` — `printRow(_ image: CGImage) async throws`
- `ConsolePrinter` — logs row dimensions (placeholder for ESC/POS)
- `MockPrinter` — no-op, used in DEBUG builds

---

## UI

Two tabs:
- **Record** — START/STOP, live 12-cell row preview, elapsed time, glyph count
- **Archive** — browse past sessions, view strips, inspect individual glyphs

---

## Requirements

- iOS 16+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
xcodegen generate
open Engram.xcodeproj
```

---

## Project layout

```
Engram/
  App/          EngramApp.swift
  Audio/        MicCapture, FeatureExtractor, FeatureFrame
  Glyph/        SigilRenderer, GlyphState, GlyphContext
  Pipeline/     AnalysisCycle
  Archive/      SessionStore, StripStitcher
  Printer/      PrintQueue, PrinterProtocol, ConsolePrinter, MockPrinter
  UI/           ContentView, LiveStripView, StripScrollView,
                ArchiveBrowser, StripDetailView, RendererPreviewView
```
