import SwiftUI

struct NeckPanel: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        ScrollView(.vertical) {
            PaperCard(radius: 28, padding: EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16)) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    tones
                    qualities
                    modeRow
                    Fretboard()
                        .frame(height: 524)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        let pal = store.palette
        let cur = store.current
        let sec = store.currentSection
        let lyric = cur.chord.lyric
        return HStack(alignment: .bottom, spacing: 12) {
            Text(store.chordName(cur))
                .font(.onest(56, .black))
                .em(-0.055, 56)
                .foregroundStyle(pal.col(cur.root, 0.58, 0.2))
                .lineLimit(1)
                .fixedSize()
                .scaleEffect(store.lit ? 1.04 : 1, anchor: .bottomLeading)
                .animation(.bounce, value: store.lit)
                .animation(.easeInOut(duration: 0.5), value: cur.root)
                .frame(height: 50, alignment: .bottom)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(store.numeral(cur.root, cur.q)) · \(store.keyName)")
                    .font(.mono(11, .bold))
                    .foregroundStyle(Color.mutedDeep)
                Text(sec.map { $0.name + (lyric.isEmpty ? "" : " · “\(lyric)”") } ?? "")
                    .font(.onest(12, .semibold))
                    .foregroundStyle(Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)

            HStack(spacing: 6) {
                circleButton(ChevronIcon(left: true)) { store.step(-1) }
                    .accessibilityLabel("Previous chord")
                circleButton(ChevronIcon(left: false)) { store.step(1) }
                    .accessibilityLabel("Next chord")
            }
            .padding(.bottom, 2)
        }
    }

    private func circleButton<L: View>(_ label: L, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .foregroundStyle(Color.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.paperDeep))
        }
        .pressable(0.9)
    }

    private var tones: some View {
        let pal = store.palette
        let cur = store.current
        return HStack(spacing: 6) {
            ForEach(cur.q.intervals, id: \.self) { i in
                HStack(spacing: 7) {
                    Text(store.name(cur.root + i))
                        .font(.onest(10.5, .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(pal.col(cur.root + i)))
                        .animation(.easeInOut(duration: 0.5), value: cur.root)
                    Text(Theory.intervalLabel[i] ?? "\(i)")
                        .font(.mono(11, .bold))
                        .foregroundStyle(Color.mutedDeep)
                }
                .padding(.leading, 4)
                .padding(.trailing, 11)
                .frame(height: 30)
                .background(Capsule().fill(.white))
            }
        }
    }

    private var qualities: some View {
        let cur = store.current
        return ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Quality.allCases) { q in
                    let on = q == cur.q
                    Button { store.setQuality(q) } label: {
                        Text(q.label)
                            .font(.onest(13, .bold))
                            .foregroundStyle(on ? .white : Color.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(Capsule().fill(on ? Color.ink : Color.paperDeep))
                            .animation(.easeOut(duration: 0.25), value: on)
                    }
                    .pressable()
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private var modeRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                segment("Chord shape", on: store.fretMode == .shape) { store.fretMode = .shape }
                segment("Full scale", on: store.fretMode == .scale) { store.fretMode = .scale }
            }
            .padding(3)
            .background(Capsule().fill(Color.paperDeep))

            Button { store.hear(store.current.root, store.current.q) } label: {
                Text("Strum")
                    .font(.onest(13, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.accent))
            }
            .pressable()
        }
    }

    private func segment(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.onest(13, .bold))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Capsule().fill(on ? Color.white : .clear).shadow(color: .black.opacity(on ? 0.1 : 0), radius: 3, y: 2))
                .contentShape(Capsule())
                .animation(.easeOut(duration: 0.25), value: on)
        }
        .buttonStyle(.plain)
    }
}

struct ChevronIcon: View {
    var left: Bool
    var body: some View {
        Path { p in
            if left {
                p.move(to: CGPoint(x: 15, y: 18)); p.addLine(to: CGPoint(x: 9, y: 12)); p.addLine(to: CGPoint(x: 15, y: 6))
            } else {
                p.move(to: CGPoint(x: 9, y: 18)); p.addLine(to: CGPoint(x: 15, y: 12)); p.addLine(to: CGPoint(x: 9, y: 6))
            }
        }
        .stroke(style: StrokeStyle(lineWidth: 2.75, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
        .scaleEffect(16 / 24)
        .frame(width: 16, height: 16)
    }
}

// MARK: - Fretboard

private struct FretDot: Equatable {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var bg: Color
    var fg: Color
    var label: String
    var fontSize: CGFloat
    var opacity: Double = 1
    /// Outer ring (root): gap in paper, then colored ring.
    var ringColor: Color?
    var ringGap: CGFloat = 3
    var ringWidth: CGFloat = 2
    /// Inner stroke (open strings).
    var inset: Color?
    var insetWidth: CGFloat = 2.5
    var drop = false
    var glow: Color?
    var scale: CGFloat = 1
    var midi: Int?
}

struct Fretboard: View {
    @Environment(SongStore.self) private var store

    private let x0: CGFloat = 46, nutY: CGFloat = 46, fh: CGFloat = 38
    private var topY: CGFloat { nutY - 22 }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width
            let sp = (W - 18 - x0) / 5
            let sx = { (i: Int) -> CGFloat in x0 + CGFloat(i) * sp }
            let fy = { (f: Int) -> CGFloat in f == 0 ? topY : nutY + (CGFloat(f) - 0.5) * fh }
            let pal = store.palette
            let cur = store.current
            let v = Theory.voicing(cur.root, cur.q)
            let shape = store.fretMode == .shape

            ZStack(alignment: .topLeading) {
                // Frets
                ForEach(0...12, id: \.self) { f in
                    let h: CGFloat = f == 0 ? 6 : 2
                    RoundedRectangle(cornerRadius: 2)
                        .fill(f == 0 ? Color.ink : Color.paperLine)
                        .frame(width: 5 * sp + 20, height: h)
                        .position(x: x0 - 10 + (5 * sp + 20) / 2, y: nutY + CGFloat(f) * fh)
                }
                // Inlays
                ForEach(Array(inlays(sx).enumerated()), id: \.offset) { _, p in
                    Circle().fill(Color.inlay).frame(width: 12, height: 12).position(p)
                }
                // Fret numbers
                ForEach(1...12, id: \.self) { f in
                    Text("\(f)")
                        .font(.mono(10, .bold))
                        .foregroundStyle([3, 5, 7, 9, 12].contains(f) ? Color.mutedDeep : Color.mutedLight)
                        .frame(width: 22)
                        .position(x: 11, y: nutY + (CGFloat(f) - 0.5) * fh)
                }
                // Strings
                ForEach(0..<6, id: \.self) { i in
                    let w = 2.6 - CGFloat(i) * 0.3
                    Rectangle()
                        .fill(shape && v[i] < 0 ? Color.paperLine : Color.muted)
                        .frame(width: w, height: 12 * fh)
                        .position(x: sx(i), y: nutY + 6 * fh)
                        .animation(.easeOut(duration: 0.3), value: v[i])
                }

                // Full scale layer
                ZStack(alignment: .topLeading) {
                    let dots = scaleDots(cur: cur, pal: pal, sx: sx, fy: fy)
                    ForEach(dots.indices, id: \.self) { i in
                        dotView(dots[i], delay: 0)
                    }
                }
                .opacity(shape ? 0 : 1)
                .allowsHitTesting(!shape)
                .animation(.easeInOut(duration: 0.45), value: shape)

                // Chord shape layer
                ZStack(alignment: .topLeading) {
                    barre(v: v, cur: cur, pal: pal, sx: sx, fy: fy)
                    let dots = chordDots(v: v, cur: cur, pal: pal, sx: sx, fy: fy)
                    ForEach(0..<6, id: \.self) { i in
                        dotView(dots[i], delay: Double(i) * 0.028)
                    }
                }
                .opacity(shape ? 1 : 0)
                .allowsHitTesting(shape)
                .animation(.easeInOut(duration: 0.45), value: shape)
            }
            .frame(width: W, height: g.size.height, alignment: .topLeading)
        }
    }

    private func inlays(_ sx: (Int) -> CGFloat) -> [CGPoint] {
        [3, 5, 7, 9].map { CGPoint(x: (sx(2) + sx(3)) / 2, y: nutY + (CGFloat($0) - 0.5) * fh) }
            + [CGPoint(x: (sx(1) + sx(2)) / 2, y: nutY + 11.5 * fh), CGPoint(x: (sx(3) + sx(4)) / 2, y: nutY + 11.5 * fh)]
    }

    private func chordDots(v: [Int], cur: PlacedChord, pal: Palette, sx: (Int) -> CGFloat, fy: (Int) -> CGFloat) -> [FretDot] {
        let lit = store.lit
        return v.enumerated().map { i, f in
            let pc = f < 0 ? 0 : m12(Theory.tuning[i] + f)
            let c = pal.col(pc)
            let glow = lit ? pal.col(pc, 0.7, 0.2, 0.55) : nil
            if f < 0 {
                return FretDot(x: sx(i), y: topY, size: 22, bg: .clear, fg: .mutedLight, label: "×", fontSize: 15)
            }
            if f == 0 {
                return FretDot(x: sx(i), y: topY, size: 26, bg: .paper, fg: pal.tintFg(pc), label: store.name(pc), fontSize: 10.5,
                               inset: c, glow: glow, scale: lit ? 1.25 : 1, midi: Theory.tuning[i])
            }
            let isRoot = pc == cur.root
            return FretDot(x: sx(i), y: fy(f), size: 32, bg: c, fg: .white, label: store.name(pc), fontSize: 11.5,
                           ringColor: isRoot ? c : nil, drop: !isRoot, glow: glow, scale: lit ? 1.25 : 1,
                           midi: Theory.tuning[i] + f)
        }
    }

    private func scaleDots(cur: PlacedChord, pal: Palette, sx: (Int) -> CGFloat, fy: (Int) -> CGFloat) -> [FretDot] {
        let lit = store.lit
        let curPcs = cur.chord.pitchClasses
        let scale = store.scalePitchClasses
        var out: [FretDot] = []
        out.reserveCapacity(78)
        for (i, t) in Theory.tuning.enumerated() {
            for f in 0...12 {
                let pc = m12(t + f)
                let tone = curPcs.contains(pc), inScale = scale.contains(pc), isRoot = pc == cur.root
                let size: CGFloat = tone ? 28 : 20
                let fontSize: CGFloat = tone ? 10.5 : 8.5
                let opacity: Double = tone || inScale ? 1 : 0
                let dotScale: CGFloat = lit && tone ? 1.2 : 1
                let bg: Color = tone ? pal.col(pc) : (f == 0 ? Color.paper : Color.inlay)
                let fg: Color = tone ? Color.white : Color.mutedDeep
                let ring: Color? = isRoot ? pal.col(pc) : nil
                let inset: Color? = f == 0 && !tone ? Color.paperLine : nil
                let glow: Color? = lit && tone ? pal.col(pc, 0.7, 0.2, 0.5) : nil
                out.append(FretDot(
                    x: sx(i), y: fy(f), size: size, bg: bg, fg: fg,
                    label: store.name(pc), fontSize: fontSize, opacity: opacity,
                    ringColor: ring, ringGap: 2.5, ringWidth: 2,
                    inset: inset, insetWidth: 1.5,
                    glow: glow, scale: dotScale, midi: t + f))
            }
        }
        return out
    }

    @ViewBuilder
    private func barre(v: [Int], cur: PlacedChord, pal: Palette, sx: (Int) -> CGFloat, fy: (Int) -> CGFloat) -> some View {
        let fr = v.filter { $0 > 0 }
        let mn = fr.min() ?? 0
        let bar: (x: CGFloat, w: CGFloat, y: CGFloat, on: Bool) = {
            guard mn > 0 else { return (x0, 0, fy(1), false) }
            let idx = v.indices.filter { v[$0] == mn }
            guard idx.count >= 2, let a = idx.first, let b = idx.last,
                  v[a...b].allSatisfy({ $0 >= mn }) else { return (x0, 0, fy(mn), false) }
            return (sx(a) - 16, sx(b) - sx(a) + 32, fy(mn), true)
        }()
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.72)
        Capsule()
            .fill(pal.col(cur.root, 0.64, 0.19, 0.3))
            .frame(width: bar.w, height: 30)
            .position(x: bar.x + bar.w / 2, y: bar.y)
            .opacity(bar.on ? 1 : 0)
            .animation(spring, value: bar.x)
            .animation(spring, value: bar.w)
            .animation(spring, value: bar.y)
            .animation(.easeOut(duration: 0.4), value: bar.on)
            .allowsHitTesting(false)
    }

    private func dotView(_ d: FretDot, delay: Double) -> some View {
        let move = Animation.spring(response: 0.55, dampingFraction: 0.62).delay(delay)
        return Text(d.label)
            .font(.onest(d.fontSize, .heavy))
            .foregroundStyle(d.fg)
            .frame(width: d.size, height: d.size)
            .background(Circle().fill(d.bg))
            .overlay {
                if let inset = d.inset {
                    Circle().strokeBorder(inset, lineWidth: d.insetWidth)
                }
            }
            .background {
                if let ring = d.ringColor {
                    ZStack {
                        Circle().fill(ring).padding(-(d.ringGap + d.ringWidth))
                        Circle().fill(Color.paper).padding(-d.ringGap)
                    }
                }
            }
            .shadow(color: .black.opacity(d.drop ? 0.18 : 0), radius: 4, y: 3)
            .shadow(color: d.glow ?? .clear, radius: d.glow == nil ? 0 : 12)
            .contentShape(Circle())
            .onTapGesture { if let m = d.midi { store.note(m) } }
            .scaleEffect(d.scale)
            .opacity(d.opacity)
            .animation(.easeInOut(duration: 0.5), value: d.bg)
            .animation(.easeInOut(duration: 0.4), value: d.size)
            .animation(.easeInOut(duration: 0.5), value: d.opacity)
            .animation(.bounce.delay(delay), value: d.scale)
            .position(x: d.x, y: d.y)
            .animation(move, value: d.y)
    }
}
