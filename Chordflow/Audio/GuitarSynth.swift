import AVFoundation
import os

/// Small polyphonic synth that recreates the prototype's Web Audio patch:
/// detuned saw + triangle through a sweeping low-pass with an exponential pluck envelope,
/// a feedback echo, and a separate dry bus for the metronome click.
final class GuitarSynth {
    static let shared = GuitarSynth()

    private let engine = AVAudioEngine()
    private let echo = AVAudioUnitDelay()
    private var strings: VoiceBus!
    private var clicks: VoiceBus!
    private var configured = false

    private init() {}

    /// Starts the engine on demand. Returns false if audio is unavailable.
    @discardableResult
    func ensureRunning() -> Bool {
        if !configured {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)

            let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let rate = sr > 0 ? sr : 44_100
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return false }
            strings = VoiceBus(sampleRate: rate, gain: 0.55)
            clicks = VoiceBus(sampleRate: rate, gain: 1)

            let stringsNode = strings.makeNode()
            let clickNode = clicks.makeNode()
            echo.delayTime = 0.24
            echo.feedback = 28
            echo.lowPassCutoff = 15_000
            echo.wetDryMix = 14

            engine.attach(stringsNode)
            engine.attach(clickNode)
            engine.attach(echo)
            engine.connect(stringsNode, to: echo, format: format)
            engine.connect(echo, to: engine.mainMixerNode, format: format)
            engine.connect(clickNode, to: engine.mainMixerNode, format: format)
            engine.prepare()
            configured = true
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return true
    }

    /// Plucks a single note. `delay` is seconds from now.
    func pluck(midi: Int, delay: Double = 0.01, duration: Double = 1.8, velocity: Double = 0.2) {
        guard ensureRunning() else { return }
        let f = 440 * pow(2, Double(midi - 69) / 12)
        strings.schedule(Voice(kind: .pluck, freq: f, delay: delay, duration: duration, velocity: velocity))
    }

    /// Strums a voicing low to high, 24 ms apart.
    func strum(_ chord: (root: Int, q: Quality), duration: Double = 1.9) {
        var k = 0
        for (i, fret) in Theory.voicing(chord.root, chord.q).enumerated() where fret >= 0 {
            pluck(midi: Theory.tuning[i] + fret, delay: 0.01 + Double(k) * 0.024, duration: duration)
            k += 1
        }
    }

    func note(midi: Int) {
        pluck(midi: midi, duration: 1.4, velocity: 0.24)
    }

    func click(accent: Bool) {
        guard ensureRunning() else { return }
        clicks.schedule(Voice(kind: .click, freq: accent ? 1900 : 1300, delay: 0.005, duration: 0.05,
                              velocity: accent ? 0.08 : 0.045))
    }
}

// MARK: - Voices

struct Voice {
    enum Kind { case pluck, click }
    var kind: Kind
    var freq: Double
    var delay: Double
    var duration: Double
    var velocity: Double

    // Render state
    var start: Int64 = 0
    var phase1 = 0.0
    var phase2 = 0.0
    var ic1 = 0.0
    var ic2 = 0.0
    var g = 0.0
    var done = false
}

/// A set of voices rendered by one AVAudioSourceNode. Scheduling happens on the main thread and is
/// handed to the render thread through a lock-protected pending list.
private final class VoiceBus: @unchecked Sendable {
    private let sampleRate: Double
    private let gain: Float
    private let pending = OSAllocatedUnfairLock<[Voice]>(initialState: [])
    private var voices: [Voice] = []
    private var clock: Int64 = 0

    init(sampleRate: Double, gain: Float) {
        self.sampleRate = sampleRate
        self.gain = gain
        pending.withLock { $0.reserveCapacity(64) }
        voices.reserveCapacity(128)
    }

    func schedule(_ v: Voice) {
        pending.withLock { $0.append(v) }
    }

    func makeNode() -> AVAudioSourceNode {
        AVAudioSourceNode { [unowned self] _, _, frameCount, abl in
            self.render(frameCount: Int(frameCount), abl: abl)
            return noErr
        }
    }

    private func render(frameCount: Int, abl: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return }
        for i in 0..<frameCount { out[i] = 0 }

        // Never block the render thread: if the main thread holds the lock, pick up new voices next buffer.
        _ = pending.withLockIfAvailable { queued in
            for var v in queued {
                v.start = clock + Int64(v.delay * sampleRate)
                voices.append(v)
            }
            queued.removeAll(keepingCapacity: true)
        }

        let sr = sampleRate
        let bufferStart = clock
        for vi in voices.indices {
            var v = voices[vi]
            let end = v.start + Int64((v.duration + 0.05) * sr)
            if end <= bufferStart { voices[vi].done = true; continue }
            let from = max(0, Int(v.start - bufferStart))
            if from >= frameCount { continue }
            let to = min(frameCount, Int(end - bufferStart))
            switch v.kind {
            case .pluck: renderPluck(&v, out, from, to, bufferStart)
            case .click: renderClick(&v, out, from, to, bufferStart)
            }
            if to < frameCount { v.done = true }
            voices[vi] = v
        }
        voices.removeAll { $0.done }
        clock += Int64(frameCount)

        for i in 0..<frameCount { out[i] = tanhf(out[i] * gain) }
        for b in buffers.dropFirst() {
            guard let dst = b.mData?.assumingMemoryBound(to: Float.self) else { continue }
            dst.update(from: out, count: frameCount)
        }
    }

    private func renderPluck(_ v: inout Voice, _ out: UnsafeMutablePointer<Float>, _ from: Int, _ to: Int, _ bufferStart: Int64) {
        let sr = sampleRate
        let f = v.freq
        let dt1 = f / sr, dt2 = f * 1.003 / sr
        let cutStart = min(9000, f * 9), cutEnd = max(220, f * 1.4)
        let k = 1 / 0.8 // 1/Q
        let vel = v.velocity
        var a1 = 0.0, a2 = 0.0, a3 = 0.0
        for i in from..<to {
            let t = Double(bufferStart + Int64(i) - v.start) / sr
            if (i - from) % 16 == 0 {
                // Low-pass cutoff glides exponentially over 0.7 s (TPT state-variable filter).
                let cut = t >= 0.7 ? cutEnd : cutStart * pow(cutEnd / cutStart, t / 0.7)
                let g = tan(.pi * min(cut, sr * 0.45) / sr)
                a1 = 1 / (1 + g * (g + k)); a2 = g * a1; a3 = g * a2
                v.g = g
            }
            // Band-limited saw (polyBLEP) + triangle
            var saw = 2 * v.phase1 - 1
            saw -= polyBlep(v.phase1, dt1)
            let tri = 4 * abs(v.phase2 - 0.5) - 1
            v.phase1 += dt1; if v.phase1 >= 1 { v.phase1 -= 1 }
            v.phase2 += dt2; if v.phase2 >= 1 { v.phase2 -= 1 }
            let x = saw * 0.32 + tri

            let v3 = x - v.ic2
            let v1 = a1 * v.ic1 + a2 * v3
            let v2 = v.ic2 + a2 * v.ic1 + a3 * v3
            v.ic1 = 2 * v1 - v.ic1
            v.ic2 = 2 * v2 - v.ic2

            let env: Double
            if t < 0.005 {
                env = 0.0001 * pow(vel / 0.0001, t / 0.005)
            } else if t < v.duration {
                env = vel * pow(0.0001 / vel, (t - 0.005) / (v.duration - 0.005))
            } else {
                env = 0.0001
            }
            out[i] += Float(v2 * env)
        }
    }

    private func renderClick(_ v: inout Voice, _ out: UnsafeMutablePointer<Float>, _ from: Int, _ to: Int, _ bufferStart: Int64) {
        let sr = sampleRate
        let dt = v.freq / sr
        for i in from..<to {
            let t = Double(bufferStart + Int64(i) - v.start) / sr
            let env = t < v.duration ? v.velocity * pow(0.0001 / v.velocity, t / v.duration) : 0
            out[i] += Float(sin(2 * .pi * v.phase1) * env)
            v.phase1 += dt; if v.phase1 >= 1 { v.phase1 -= 1 }
        }
    }

    @inline(__always) private func polyBlep(_ t: Double, _ dt: Double) -> Double {
        if t < dt { let x = t / dt; return x + x - x * x - 1 }
        if t > 1 - dt { let x = (t - 1) / dt; return x * x + x + x + 1 }
        return 0
    }
}
