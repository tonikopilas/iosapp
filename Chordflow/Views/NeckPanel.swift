import SwiftUI

struct NeckPanel: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        let find = store.fretMode == .find
        ScrollView(.vertical) {
            PaperCard(radius: 28, padding: EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16)) {
                VStack(alignment: .leading, spacing: 14) {
                    if find {
                        FinderHeader()
                    } else {
                        header
                        tones
                        qualities
                    }
                    modeRow
                    if store.fretMode == .shape && store.hasCurrent { positions }
                    labelsRow
                    TipCard(text: tip, topic: find ? .chordFinder : store.fretMode == .scale ? .modes : .voicings, onPaper: true)
                    Fretboard()
                        .frame(height: 560)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
    }

    private var tip: String {
        switch store.fretMode {
        case .shape:
            store.hasCurrent ? store.explain(store.current.chord)
                : "Add a chord on the Song tab to see its shape here."
        case .scale:
            "Coloured dots are the notes of \(store.chordName(store.current)); grey dots are the rest of \(store.keyName). Any of them is a safe note to play over this chord. Ringed dots are the root."
        case .find:
            "Tap one fret on each string you play. Tap the same fret again to mute that string, or the top row to play it open. Chordflow names the chord."
        }
    }

    private var header: some View {
        let pal = store.palette
        let cur = store.current
        let sec = store.currentSection
        return HStack(alignment: .bottom, spacing: 12) {
            Text(store.chordName(cur))
                .font(.onest(56, .black))
                .em(-0.055, 56)
                .foregroundStyle(pal.col(cur.root, 0.58, 0.2))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .scaleEffect(store.lit ? 1.04 : 1, anchor: .bottomLeading)
                .animation(.bounce, value: store.lit)
                .animation(.easeInOut(duration: 0.5), value: cur.root)
                .frame(height: 50, alignment: .bottom)
                .layoutPriority(1)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(store.numeral(cur.root, cur.q)) · \(store.keyName)")
                    .font(.mono(11, .bold))
                    .foregroundStyle(Color.mutedDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(sec?.name ?? "")
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
        return ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(cur.q.intervals, id: \.self) { i in
                    HStack(spacing: 7) {
                        Text(store.name(cur.root + i))
                            .font(.onest(10.5, .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(pal.col(cur.root + i)))
                            .animation(.easeInOut(duration: 0.5), value: cur.root)
                        Text(cur.q.degreeLabel(i))
                            .font(.mono(11, .bold))
                            .foregroundStyle(Color.mutedDeep)
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 11)
                    .frame(height: 30)
                    .background(Capsule().fill(.white))
                    .onTapGesture { store.note(48 + m12(cur.root + i)) }
                }
                if let b = cur.chord.slashBass {
                    Text("bass \(store.name(b))")
                        .font(.mono(11, .bold))
                        .foregroundStyle(Color.mutedDeep)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Capsule().strokeBorder(Color.outline, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
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
                InfoButton(topic: .qualities)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private var modeRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                segment("Shape", on: store.fretMode == .shape) { store.fretMode = .shape }
                segment("Scale", on: store.fretMode == .scale) { store.fretMode = .scale }
                segment("Find", on: store.fretMode == .find) { store.fretMode = .find }
            }
            .padding(3)
            .background(Capsule().fill(Color.paperDeep))

            Button {
                if store.fretMode == .find { store.hear(frets: store.finderFrets) } else { store.hear(store.current.chord) }
            } label: {
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

    /// Where on the neck to play the chord.
    private var positions: some View {
        let cur = store.current
        let options = Theory.voicings(cur.root, cur.q, bass: cur.chord.slashBass)
        let custom = cur.chord.voicing.flatMap { v in options.contains(v) ? nil : v }
        return ScrollView(.horizontal) {
            HStack(spacing: 6) {
                positionChip("Auto", detail: nil, on: cur.chord.voicing == nil) { store.setVoicing(cur.id, nil) }
                if let custom {
                    positionChip("Custom", detail: Theory.shapeString(custom), on: true) {}
                }
                ForEach(options, id: \.self) { v in
                    let p = Theory.position(v)
                    positionChip(p == 0 ? "Open" : "Fret \(p)", detail: Theory.shapeString(v), on: cur.chord.voicing == v) {
                        store.setVoicing(cur.id, v)
                    }
                }
                InfoButton(topic: .voicings)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private func positionChip(_ title: String, detail: String?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title).font(.onest(12, .heavy))
                if let detail { Text(detail).font(.mono(9, .bold)).opacity(0.7) }
            }
            .foregroundStyle(on ? .white : Color.ink)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(on ? Color.ink : Color.paperDeep))
            .animation(.easeOut(duration: 0.2), value: on)
        }
        .pressable()
    }

    private var labelsRow: some View {
        HStack(spacing: 8) {
            Eyebrow(text: "DOTS SHOW")
            HStack(spacing: 0) {
                segment("Notes", on: store.fretLabels == .notes) { store.fretLabels = .notes }
                segment("Intervals", on: store.fretLabels == .degrees) { store.fretLabels = .degrees }
            }
            .padding(3)
            .background(Capsule().fill(Color.paperDeep))
            InfoButton(topic: .intervals)
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

// MARK: - Chord finder

extension SongStore {
    var finderMidi: [Int] {
        finderFrets.enumerated().compactMap { i, f in f >= 0 ? Theory.tuning[i] + f : nil }
    }

    /// Sets a string's fret; tapping the same fret again mutes the string.
    func finderTap(string: Int, fret: Int) {
        finderFrets[string] = finderFrets[string] == fret ? -1 : fret
        if finderFrets[string] >= 0 { note(Theory.tuning[string] + fret) }
    }

    func finderClear() { finderFrets = [-1, -1, -1, -1, -1, -1] }

    /// Copies the selected chord's shape into the finder, to tweak it.
    func finderLoadCurrent() { finderFrets = current.chord.shape }
}

private struct FinderHeader: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        let pal = store.palette
        let midi = store.finderMidi
        let matches = ChordFinder.identify(midi)
        let best = matches.first
        let notes = Array(Set(midi.map(m12))).sorted { a, b in
            m12(a - (best?.root ?? 0)) < m12(b - (best?.root ?? 0))
        }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                Text(title(midi: midi, best: best))
                    .font(.onest(best == nil ? 34 : 52, .black))
                    .em(-0.05, 52)
                    .foregroundStyle(best.map { pal.col($0.root, 0.58, 0.2) } ?? Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(height: 50, alignment: .bottom)
                    .animation(.settle, value: best?.id)
                Spacer(minLength: 0)
                if let best {
                    Text(store.numeral(best.root, best.q))
                        .font(.mono(12, .bold))
                        .foregroundStyle(Color.mutedDeep)
                        .padding(.bottom, 6)
                }
            }
            Text(subtitle(midi: midi, best: best, notes: notes))
                .font(.onest(12.5, .semibold))
                .foregroundStyle(Color.mutedDeep)
                .fixedSize(horizontal: false, vertical: true)

            if matches.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        Eyebrow(text: "ALSO")
                        ForEach(matches.dropFirst().prefix(4)) { m in
                            Button { store.preview(m.root, m.q, bass: m.bass) } label: {
                                Text(store.chordName(m))
                                    .font(.onest(13, .heavy))
                                    .foregroundStyle(pal.tintFg(m.root))
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(Capsule().fill(pal.tint(m.root)))
                            }
                            .pressable()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -16)
            }

            HStack(spacing: 8) {
                action("Add to song", filled: true, enabled: best != nil) {
                    if let best {
                        withAnimation(.settle) {
                            store.addChord(best.root, best.q, bass: best.bass, voicing: store.finderFrets)
                        }
                    }
                }
                action("To tab", filled: false, enabled: !midi.isEmpty) { store.addShapeToTab(store.finderFrets) }
                Menu {
                    Button { store.finderLoadCurrent() } label: {
                        Label("Load \(store.chordName(store.current))", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) { store.finderClear() } label: { Label("Clear", systemImage: "xmark") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.paperDeep))
                }
            }
        }
    }

    private func title(midi: [Int], best: ChordMatch?) -> String {
        if let best { return store.chordName(best) }
        switch Set(midi.map(m12)).count {
        case 0: return "Tap the neck"
        case 1: return store.name(midi[0])
        default: return "No name"
        }
    }

    private func subtitle(midi: [Int], best: ChordMatch?, notes: [Int]) -> String {
        let names = notes.map { store.name($0) }.joined(separator: " · ")
        if midi.isEmpty { return "Pick one fret per string and the chord gets named as you go." }
        if let best {
            let tones = notes.map { "\(store.name($0)) (\(best.q.degreeLabel($0 - best.root)))" }.joined(separator: " ")
            let missing = best.missing.isEmpty ? "" : " The 5th is left out; that's normal on guitar."
            let bass = best.bass.map { " \(store.name($0)) in the bass." } ?? ""
            return tones + "." + bass + missing + (store.inKey(Chord(id: "", root: best.root, q: best.q)) ? " In \(store.keyName)." : " Outside \(store.keyName).")
        }
        let pcs = Set(midi.map(m12))
        if pcs.count == 1 { return "One note. Add another string to build an interval or chord." }
        if pcs.count == 2, let lo = midi.min(), let hi = midi.max() {
            return "\(names): a \(ChordFinder.intervalName(lo, hi)). Add a third note for a full chord."
        }
        return "\(names). These notes don't form a common chord. Try muting a string."
    }

    private func action(_ title: String, filled: Bool, enabled: Bool, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.onest(13.5, .heavy))
                .foregroundStyle(filled ? .white : Color.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Capsule().fill(filled ? Color.ink : Color.paperDeep))
                .opacity(enabled ? 1 : 0.4)
        }
        .pressable()
        .disabled(!enabled)
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
            let find = store.fretMode == .find
            let v = find ? store.finderFrets : cur.chord.shape
            let shape = store.fretMode == .shape

            ZStack(alignment: .topLeading) {
                // Board
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Color.paperDeep.opacity(0.55), Color.paperDeep.opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 5 * sp + 36, height: 12 * fh)
                    .position(x: x0 + 5 * sp / 2, y: nutY + 6 * fh)
                // Frets
                ForEach(0...12, id: \.self) { f in
                    let h: CGFloat = f == 0 ? 7 : (f == 12 ? 3 : 2)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(f == 0 ? Color.ink : Color.paperLine)
                        .shadow(color: .black.opacity(f == 0 ? 0 : 0.08), radius: 0, y: 1)
                        .frame(width: 5 * sp + 20, height: h)
                        .position(x: x0 - 10 + (5 * sp + 20) / 2, y: nutY + CGFloat(f) * fh)
                }
                // String names under the board
                ForEach(0..<6, id: \.self) { i in
                    Text(Theory.sharp[m12(Theory.tuning[i])])
                        .font(.mono(10, .bold))
                        .foregroundStyle(Color.muted)
                        .position(x: sx(i), y: nutY + 12 * fh + 18)
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
                // Strings (wound bass strings are thicker)
                ForEach(0..<6, id: \.self) { i in
                    let w = 2.8 - CGFloat(i) * 0.35
                    Rectangle()
                        .fill((shape || find) && v[i] < 0 ? Color.paperLine : (i < 3 ? Color.mutedDeep.opacity(0.75) : Color.muted))
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

                // Find layer: every position is a tap target.
                if find {
                    ForEach(0..<6, id: \.self) { i in
                        ForEach(0...12, id: \.self) { f in
                            Color.white.opacity(0.001)
                                .frame(width: sp, height: f == 0 ? 40 : fh)
                                .contentShape(Rectangle())
                                .position(x: sx(i), y: fy(f))
                                .onTapGesture { store.finderTap(string: i, fret: f) }
                        }
                    }
                    let dots = finderDots(pal: pal, sx: sx, fy: fy)
                    ForEach(0..<6, id: \.self) { i in
                        dotView(dots[i], delay: 0).allowsHitTesting(false)
                    }
                }
            }
            .frame(width: W, height: g.size.height, alignment: .topLeading)
        }
    }

    private func inlays(_ sx: (Int) -> CGFloat) -> [CGPoint] {
        [3, 5, 7, 9].map { CGPoint(x: (sx(2) + sx(3)) / 2, y: nutY + (CGFloat($0) - 0.5) * fh) }
            + [CGPoint(x: (sx(1) + sx(2)) / 2, y: nutY + 11.5 * fh), CGPoint(x: (sx(3) + sx(4)) / 2, y: nutY + 11.5 * fh)]
    }

    /// Note name, or the interval above `root` when showing intervals.
    private func label(_ pc: Int, root: Int, q: Quality?) -> String {
        guard store.fretLabels == .degrees else { return store.name(pc) }
        if let q { return q.degreeLabel(pc - root) }
        let l = Theory.intervalLabel[m12(pc - root)] ?? ""
        return l == "R" ? "1" : l
    }

    private func finderDots(pal: Palette, sx: (Int) -> CGFloat, fy: (Int) -> CGFloat) -> [FretDot] {
        let frets = store.finderFrets
        let best = ChordFinder.identify(store.finderMidi).first
        let lowest = frets.firstIndex { $0 >= 0 }
        return frets.enumerated().map { i, f in
            if f < 0 {
                return FretDot(x: sx(i), y: topY, size: 22, bg: .clear, fg: .mutedLight, label: "×", fontSize: 15)
            }
            let pc = m12(Theory.tuning[i] + f)
            let c = pal.col(pc)
            let text = best.map { label(pc, root: $0.root, q: $0.q) } ?? store.name(pc)
            if f == 0 {
                return FretDot(x: sx(i), y: topY, size: 26, bg: .paper, fg: pal.tintFg(pc), label: text, fontSize: 10.5,
                               inset: c, midi: Theory.tuning[i])
            }
            return FretDot(x: sx(i), y: fy(f), size: 32, bg: c, fg: .white, label: text, fontSize: 11.5,
                           ringColor: i == lowest ? c : nil, drop: i != lowest, midi: Theory.tuning[i] + f)
        }
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
                return FretDot(x: sx(i), y: topY, size: 26, bg: .paper, fg: pal.tintFg(pc), label: label(pc, root: cur.root, q: cur.q), fontSize: 10.5,
                               inset: c, glow: glow, scale: lit ? 1.25 : 1, midi: Theory.tuning[i])
            }
            let isRoot = pc == cur.root
            return FretDot(x: sx(i), y: fy(f), size: 32, bg: c, fg: .white, label: label(pc, root: cur.root, q: cur.q), fontSize: 11.5,
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
                    label: tone ? label(pc, root: cur.root, q: cur.q) : label(pc, root: store.key, q: nil),
                    fontSize: fontSize, opacity: opacity,
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
