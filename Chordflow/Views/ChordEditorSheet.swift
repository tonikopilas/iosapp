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
                    Button { store.hear(c.root, c.q) } label: {
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

                SettingCard(title: "Length", meta: "\(beats) BEAT\(beats == 1 ? "" : "S") IN \(store.timeSignature.rawValue)") {
                    PaperSegmented(options: lengths, selection: c.bars,
                                   label: { "\(formatBars($0)) bar\($0 <= 1 ? "" : "s")" },
                                   onSelect: { b in withAnimation(.settle) { store.setBars(chordID, b) } })
                    BarPreview(bars: c.bars, beatsPerBar: store.beatsPerBar, color: pal.col(c.root))
                }

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
