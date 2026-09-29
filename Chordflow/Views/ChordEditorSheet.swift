import SwiftUI

/// Edit one chord: root, type and length in bars.
struct ChordEditorSheet: View {
    @Environment(SongStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var chordID: String

    private let lengths: [Double] = [0.5, 1, 2, 3, 4]

    var body: some View {
        if let pc = store.chord(chordID) {
            content(pc)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func content(_ pc: PlacedChord) -> some View {
        let pal = store.palette
        let c = pc.chord
        let section = store.sections.first { $0.id == pc.sectionID }
        let beats = store.beats(of: c)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "Edit chord", subtitle: section.map { $0.name.uppercased() }) { dismiss() }
                    .padding(.horizontal, -14)

                // Big chord name with audition button
                HStack(alignment: .bottom, spacing: 14) {
                    Text(store.chordName(c))
                        .font(.onest(60, .black))
                        .em(-0.055, 60)
                        .foregroundStyle(pal.col(c.root, 0.72, 0.18))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .scaleEffect(store.lit ? 1.04 : 1, anchor: .bottomLeading)
                        .animation(.bounce, value: store.lit)
                        .contentTransition(.interpolate)
                        .animation(.settle, value: c)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.numeral(c.root, c.q)).font(.mono(12, .bold))
                        Text(store.inKey(c) ? "In \(store.keyName)" : "Outside \(store.keyName)")
                            .font(.onest(12, .semibold))
                            .foregroundStyle(store.inKey(c) ? .white.opacity(0.6) : Color.accent)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 8)
                    Spacer(minLength: 0)
                    Button { store.hear(c) } label: {
                        PlayIcon(size: 18)
                            .padding(.leading, 2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Color.accent))
                            .shadow(color: Color.accent.opacity(0.45), radius: 10, y: 6)
                    }
                    .pressable(0.92)
                    .padding(.bottom, 4)
                    .accessibilityLabel("Hear chord")
                }
                .padding(.horizontal, 4)

                SettingCard(title: "Root") {
                    NoteGrid(selected: c.root) { store.setRoot(chordID, $0) }
                }

                SettingCard(title: "Type", meta: c.q.intervals.map { store.name(c.root + $0) }.joined(separator: " · ")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 4), spacing: 6) {
                        ForEach(Quality.allCases) { q in
                            let on = q == c.q
                            Button { store.setQuality(chordID, q) } label: {
                                Text(q.label)
                                    .font(.onest(13, .bold))
                                    .foregroundStyle(on ? .white : Color.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(Capsule().fill(on ? Color.ink : Color.paperDeep))
                                    .animation(.easeOut(duration: 0.2), value: on)
                            }
                            .pressable()
                        }
                    }
                }

                TipCard(text: store.explain(c), topic: .qualities)

                lengthCard(c, beats: beats)
                bassCard(c)
                shapeCard(c)
                styleCard(c)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.settle) { store.duplicateChord(chordID) }
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                            .font(.onest(14, .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .glass(Capsule())
                    }
                    .pressable()
                    Button(role: .destructive) {
                        withAnimation(.settle) { store.delete(chordID: chordID) }
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.onest(14, .bold))
                            .foregroundStyle(Color.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .glass(Capsule(), tint: Color.accent.opacity(0.14))
                    }
                    .pressable()
                }
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }
}

extension ChordEditorSheet {
    private func lengthCard(_ c: Chord, beats: Int) -> some View {
        let pal = store.palette
        return SettingCard(title: "Length", meta: "\(beats) BEAT\(beats == 1 ? "" : "S") IN \(store.timeSignature.rawValue)") {
            PaperSegmented(options: lengths, selection: c.bars,
                           label: { "\(formatBars($0)) bar\($0 <= 1 ? "" : "s")" },
                           onSelect: { b in withAnimation(.settle) { store.setBars(chordID, b) } })
            HStack(spacing: 10) {
                Text("Fine-tune").font(.onest(14, .heavy))
                Spacer()
                stepButton("minus") { withAnimation(.settle) { store.setBeats(chordID, beats - 1) } }
                    .disabled(beats <= 1)
                Text("\(beats) beat\(beats == 1 ? "" : "s")")
                    .font(.onest(15, .heavy))
                    .monospacedDigit()
                    .frame(minWidth: 70)
                    .contentTransition(.numericText())
                stepButton("plus") { withAnimation(.settle) { store.setBeats(chordID, beats + 1) } }
            }
            BarPreview(bars: c.bars, beatsPerBar: store.beatsPerBar, color: pal.col(c.root))
        }
    }

    private func bassCard(_ c: Chord) -> some View {
        return SettingCard(title: "Bass note", meta: c.slashBass.map { "SLASH /\(store.name($0))" } ?? "ROOT POSITION") {
            let tones = c.q.intervals.prefix(4)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(tones.enumerated()), id: \.offset) { k, i in
                        let pc = m12(c.root + i)
                        let on = (c.slashBass ?? m12(c.root)) == pc
                        chip(k == 0 ? "Root \(store.name(pc))" : "\(inversionName(k)) · \(store.name(pc))", on: on) {
                            store.setBass(chordID, k == 0 ? nil : pc)
                        }
                    }
                    Menu {
                        ForEach(0..<12, id: \.self) { pc in
                            Button(store.name(pc)) { store.setBass(chordID, pc) }
                        }
                    } label: {
                        let other = c.slashBass.map { !c.pitchClasses.contains($0) } ?? false
                        Text(other ? "Other · \(store.name(c.slashBass ?? 0))" : "Other…")
                            .font(.onest(13, .bold))
                            .foregroundStyle(other ? .white : Color.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(Capsule().fill(other ? Color.ink : Color.paperDeep))
                    }
                    InfoButton(topic: .inversions)
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -14)
        }
    }

    private func shapeCard(_ c: Chord) -> some View {
        let pal = store.palette
        return SettingCard(title: "Shape", meta: Theory.shapeString(c.shape).uppercased()) {
            let options = Theory.voicings(c.root, c.q, bass: c.slashBass)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    chip("Auto", on: c.voicing == nil) { store.setVoicing(chordID, nil) }
                    if let v = c.voicing, !options.contains(v) {
                        chip("Custom", on: true) {}
                    }
                    ForEach(options, id: \.self) { v in
                        let p = Theory.position(v)
                        chip(p == 0 ? "Open" : "Fret \(p)", on: c.voicing == v) { store.setVoicing(chordID, v) }
                    }
                    InfoButton(topic: .voicings)
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -14)
            MiniShape(frets: c.shape, color: pal.col(c.root))
        }
    }

    private func styleCard(_ c: Chord) -> some View {
        return SettingCard(title: "Playing style", meta: c.style == nil ? "SONG DEFAULT" : "THIS CHORD ONLY") {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    chip("Song (\(store.style.label))", on: c.style == nil) { store.setChordStyle(chordID, nil) }
                    ForEach(PlayStyle.allCases) { st in
                        chip(st.label, on: c.style == st) { store.setChordStyle(chordID, st) }
                    }
                    InfoButton(topic: .styles)
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -14)
        }
    }

    private func inversionName(_ k: Int) -> String {
        switch k {
        case 1: "1st inv"
        case 2: "2nd inv"
        default: "3rd inv"
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.onest(13, .bold))
                .foregroundStyle(on ? .white : Color.ink)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Capsule().fill(on ? Color.ink : Color.paperDeep))
                .animation(.easeOut(duration: 0.2), value: on)
        }
        .pressable()
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.paperDeep))
        }
        .buttonRepeatBehavior(.enabled)
        .pressable(0.9)
    }
}

/// A tiny chord diagram: six strings, five frets from the shape's position.
struct MiniShape: View {
    var frets: [Int]
    var color: Color

    var body: some View {
        let fretted = frets.filter { $0 > 0 }
        let base = max(1, (fretted.max() ?? 0) > 4 ? (fretted.min() ?? 1) : 1)
        HStack(alignment: .top, spacing: 10) {
            Text(base > 1 ? "\(base)fr" : "")
                .font(.mono(10, .bold))
                .foregroundStyle(Color.muted)
                .frame(width: 26, alignment: .trailing)
                .padding(.top, 22)
            Canvas { ctx, size in
                let sp = size.width / 5, fh = (size.height - 16) / 5, top: CGFloat = 16
                for i in 0..<6 {
                    var p = Path(); p.move(to: CGPoint(x: CGFloat(i) * sp, y: top)); p.addLine(to: CGPoint(x: CGFloat(i) * sp, y: size.height))
                    ctx.stroke(p, with: .color(.muted), lineWidth: 1.2)
                }
                for f in 0...5 {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: top + CGFloat(f) * fh)); p.addLine(to: CGPoint(x: size.width, y: top + CGFloat(f) * fh))
                    ctx.stroke(p, with: .color(f == 0 && base == 1 ? .ink : .paperLine), lineWidth: f == 0 && base == 1 ? 3 : 1.2)
                }
                for (i, f) in frets.enumerated() {
                    let x = CGFloat(i) * sp
                    if f < 0 {
                        ctx.draw(Text("×").font(.onest(11, .bold)).foregroundColor(.muted), at: CGPoint(x: x, y: 6))
                    } else if f == 0 {
                        ctx.stroke(Path(ellipseIn: CGRect(x: x - 4, y: 2, width: 8, height: 8)), with: .color(.mutedDeep), lineWidth: 1.5)
                    } else {
                        let y = top + (CGFloat(f - base) + 0.5) * fh
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14)), with: .color(color))
                    }
                }
            }
            .frame(width: 140, height: 96)
            Spacer(minLength: 0)
        }
    }
}

/// Beat dots grouped into bars, so the length is visible at a glance.
private struct BarPreview: View {
    var bars: Double
    var beatsPerBar: Int
    var color: Color

    var body: some View {
        let total = max(1, Int((bars * Double(beatsPerBar)).rounded()))
        let barCount = Int((Double(total) / Double(beatsPerBar)).rounded(.up))
        HStack(spacing: 10) {
            ForEach(0..<barCount, id: \.self) { b in
                HStack(spacing: 4) {
                    ForEach(0..<beatsPerBar, id: \.self) { i in
                        let on = b * beatsPerBar + i < total
                        Capsule()
                            .fill(on ? color : Color.paperDeep)
                            .frame(width: i == 0 ? 14 : 8, height: 8)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.settle, value: total)
    }
}
