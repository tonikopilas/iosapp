import SwiftUI

/// Write parts note by note on the neck: tab with rhythm, playback and analysis.
struct TabPanel: View {
    @Environment(SongStore.self) private var store
    @State private var renaming = false
    @State private var renameText = ""

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 14) {
                partBar
                if let tab = store.currentTab {
                    PaperCard(radius: 28, padding: EdgeInsets(top: 16, leading: 14, bottom: 14, trailing: 14)) {
                        VStack(alignment: .leading, spacing: 12) {
                            TabStaff(tab: tab)
                            TabToolbar()
                            TabFretboard()
                        }
                    }
                    TabAnalysisView()
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .alert("Rename part", isPresented: $renaming) {
            TextField("Name", text: $renameText)
            Button("Save") { if let id = store.currentTab?.id { store.renameTab(id, renameText) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Parts

    private var partBar: some View {
        HStack(spacing: 8) {
            Menu {
                if !store.tabs.isEmpty {
                    Section("Parts") {
                        ForEach(store.tabs) { t in
                            Button { store.selectTab(t.id) } label: {
                                if t.id == store.currentTab?.id { Label(t.name, systemImage: "checkmark") } else { Text(t.name) }
                            }
                        }
                    }
                }
                Button { withAnimation(.settle) { store.addTab() } } label: { Label("New part", systemImage: "plus") }
                if let t = store.currentTab {
                    Button {
                        renameText = t.name
                        renaming = true
                    } label: { Label("Rename", systemImage: "pencil") }
                    Button { store.duplicateTab(t.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { store.clearTab() } label: { Label("Clear notes", systemImage: "eraser") }
                    Button(role: .destructive) { withAnimation(.settle) { store.deleteTab(t.id) } } label: {
                        Label("Delete part", systemImage: "trash")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow(text: "PART \(partNumber) OF \(max(1, store.tabs.count))", size: 9.5, tracking: 0.1, color: .white.opacity(0.55))
                        Text(store.currentTab?.name ?? "No parts yet")
                            .font(.onest(20, .heavy))
                            .em(-0.03, 20)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).opacity(0.7)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }

            InfoButton(topic: .tab, onPaper: false)

            Button { store.tabLoop.toggle() } label: {
                LoopIcon()
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(store.tabLoop ? Color.accent.opacity(0.5) : .white.opacity(0.12)))
            }
            .pressable(0.9)
            .accessibilityLabel("Loop the part")

            Button { store.toggleTabPlay() } label: {
                ZStack {
                    if store.tabPlaying { PauseIcon() } else { PlayIcon(size: 16).padding(.leading, 2) }
                }
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accent))
                .shadow(color: Color.accent.opacity(0.45), radius: 10, y: 6)
            }
            .pressable(0.92)
            .disabled((store.currentTab?.events.isEmpty ?? true))
            .accessibilityLabel(store.tabPlaying ? "Stop tab" : "Play tab")
        }
        .padding(.horizontal, 4)
    }

    private var partNumber: Int {
        (store.tabs.firstIndex { $0.id == store.currentTab?.id } ?? 0) + 1
    }

    private var emptyState: some View {
        PaperCard(padding: EdgeInsets(top: 22, leading: 18, bottom: 18, trailing: 18)) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.paperDeep))
                Text("Write a riff or a solo").font(.onest(22, .heavy)).em(-0.03, 22)
                Text("Tap strings and frets on a neck to write notes in order. Pick a length for each note, stack notes into chords, then play it back. Chordflow tells you what key it's in, which chords it outlines and where it could go next.")
                    .font(.onest(13.5, .medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color.mutedDeep)
                    .fixedSize(horizontal: false, vertical: true)
                Button { withAnimation(.settle) { store.addTab() } } label: {
                    Text("Start a tab")
                        .font(.onest(14, .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(Color.accent))
                }
                .pressable()
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Staff

private let rowH: CGFloat = 19

private struct TabStaff: View {
    @Environment(SongStore.self) private var store
    var tab: Tab

    var body: some View {
        let ts = store.timeSignature
        let bars = tab.bars(ts)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    clef
                    ForEach(bars.indices, id: \.self) { b in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(b + 1)")
                                .font(.mono(9, .bold))
                                .foregroundStyle(Color.muted)
                                .padding(.leading, 4)
                                .frame(height: 12)
                            HStack(spacing: 0) {
                                ForEach(bars[b]) { p in
                                    TabColumn(event: p.event,
                                              selected: store.tabCursor == p.event.id,
                                              playing: store.tabPlayID == p.event.id,
                                              crosses: p.end > ts.barTicks * (p.bar + 1))
                                        .id(p.event.id)
                                        .onTapGesture { store.selectEvent(p.event.id) }
                                }
                            }
                        }
                        barLine
                    }
                    endSlot
                        .id("end")
                }
                .padding(.trailing, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -14)
            .onChange(of: store.tabCursor) { _, id in
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(id ?? "end", anchor: .center) }
            }
            .onChange(of: store.tabPlayID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 6 * rowH + 36)
    }

    /// String names at the start of the staff, high E on top as in printed tab.
    private var clef: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 14)
            ForEach((0..<6).reversed(), id: \.self) { s in
                Text(s == 5 ? "e" : Theory.sharp[m12(Theory.tuning[s])])
                    .font(.mono(10, .bold))
                    .foregroundStyle(Color.muted)
                    .frame(width: 22, height: rowH)
            }
        }
        .padding(.leading, 14)
        .background(alignment: .topLeading) { staffLines(width: 36).offset(x: 14, y: 14).opacity(0.5) }
    }

    private var barLine: some View {
        Rectangle()
            .fill(Color.mutedDeep)
            .frame(width: 1.5, height: 5 * rowH)
            .padding(.top, 14 + rowH / 2)
    }

    /// Where new notes go when nothing is selected.
    private var endSlot: some View {
        let on = store.tabCursor == nil || store.tabCursor == tab.events.last?.id
        return VStack(spacing: 0) {
            Spacer().frame(height: 14)
            ZStack {
                staffLines(width: 44)
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(on ? Color.accent : Color.muted)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.paper))
                    .overlay(Circle().strokeBorder(on ? Color.accent : Color.outline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
            }
            .frame(width: 44, height: 6 * rowH)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.selectEvent(tab.events.last?.id) }
        .accessibilityLabel("Write after the last note")
    }
}

func staffLines(width: CGFloat) -> some View {
    Canvas { ctx, size in
        for s in 0..<6 {
            let y = (CGFloat(s) + 0.5) * rowH
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(.paperLine), lineWidth: 1.2)
        }
    }
    .frame(width: width, height: 6 * rowH)
    .allowsHitTesting(false)
}

private struct TabColumn: View {
    @Environment(SongStore.self) private var store
    var event: TabEvent
    var selected: Bool
    var playing: Bool
    var crosses: Bool

    var body: some View {
        let w = 32 + CGFloat(min(event.ticks, 48)) / 48 * 26
        let pal = store.palette
        VStack(spacing: 2) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accent.opacity(0.14) : playing ? Color.ink.opacity(0.08) : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.accent, lineWidth: selected ? 1.5 : 0))
                    .padding(.horizontal, 2)
                staffLines(width: w)
                if event.isRest {
                    Text("rest")
                        .font(.mono(9, .bold))
                        .foregroundStyle(Color.muted)
                        .frame(width: w, height: 6 * rowH)
                }
                ForEach(event.notes, id: \.string) { n in
                    Text("\(n.fret)")
                        .font(.mono(12, .bold))
                        .foregroundStyle(playing ? .white : Color.ink)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 18, minHeight: 16)
                        .background(RoundedRectangle(cornerRadius: 5).fill(playing ? pal.col(n.pc) : Color.paper))
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(pal.col(n.pc)).frame(height: 2).opacity(playing ? 0 : 1)
                        }
                        .position(x: w / 2, y: (CGFloat(5 - n.string) + 0.5) * rowH)
                }
            }
            .frame(width: w, height: 6 * rowH)
            .scaleEffect(playing ? 1.06 : 1)
            .animation(.bounce, value: playing)
            Text(NoteLength.from(event.ticks)?.label ?? "\(event.ticks)")
                .font(.mono(9, .bold))
                .foregroundStyle(crosses ? Color.accent : selected ? Color.ink : Color.muted)
                .frame(height: 12)
        }
        .padding(.top, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Toolbar

private struct TabToolbar: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        let l = store.tabLength
        let beats = Double(l.ticks) / Double(store.timeSignature.ticksPerBeat)
        let beatText = beats == beats.rounded() ? "\(Int(beats))" : String(format: "%.2g", beats)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Eyebrow(text: "\(NoteLength.describe(l.ticks).uppercased()) · \(beatText) BEAT\(beats == 1 ? "" : "S")")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                InfoButton(topic: .noteValues)
                    .padding(-6)
            }
            HStack(spacing: 4) {
                ForEach(NoteValue.allCases) { v in
                    let on = l.value == v
                    Button { store.setTabLength(NoteLength(value: v, dotted: l.dotted, triplet: l.triplet)) } label: {
                        Text(v.label)
                            .font(.onest(14, .heavy))
                            .foregroundStyle(on ? .white : Color.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Capsule().fill(on ? Color.ink : Color.paperDeep))
                    }
                    .pressable()
                    .accessibilityLabel(v.name)
                }
                toggle(".", on: l.dotted, label: "Dotted") {
                    store.setTabLength(NoteLength(value: l.value, dotted: !l.dotted, triplet: false))
                }
                toggle("3", on: l.triplet, label: "Triplet") {
                    store.setTabLength(NoteLength(value: l.value, dotted: false, triplet: !l.triplet))
                }
            }
            HStack(spacing: 4) {
                Button { store.tabStack.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 12, weight: .bold))
                        Text("Chord").font(.onest(13, .heavy))
                    }
                    .foregroundStyle(store.tabStack ? .white : Color.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Capsule().fill(store.tabStack ? Color.accent : Color.paperDeep))
                }
                .pressable()
                .accessibilityHint("When on, taps add notes to the selected column")
                tool("Rest", system: nil) { store.addRest() }
                Spacer(minLength: 0)
                tool(nil, system: "chevron.left") { store.moveCursor(-1) }.accessibilityLabel("Previous note")
                tool(nil, system: "chevron.right") { store.moveCursor(1) }.accessibilityLabel("Next note")
                Menu {
                    Button { store.shiftEvent(semitones: 1) } label: { Label("Up a fret", systemImage: "arrow.up") }
                    Button { store.shiftEvent(semitones: -1) } label: { Label("Down a fret", systemImage: "arrow.down") }
                    Button { store.shiftEvent(semitones: 12) } label: { Label("Up an octave", systemImage: "arrow.up.to.line") }
                    Button { store.shiftEvent(semitones: -12) } label: { Label("Down an octave", systemImage: "arrow.down.to.line") }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.paperDeep))
                }
                .disabled(store.cursorEvent == nil)
                tool(nil, system: "delete.left.fill") { store.deleteEvent() }
                    .accessibilityLabel("Delete note")
                    .disabled(store.cursorEvent == nil)
            }
        }
    }

    private func toggle(_ text: String, on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.onest(16, .black))
                .foregroundStyle(on ? .white : Color.ink)
                .frame(width: 34, height: 36)
                .background(Capsule().fill(on ? Color.accent : Color.paperDeep))
        }
        .pressable()
        .accessibilityLabel(label)
    }

    private func tool(_ text: String?, system: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let system {
                    Image(systemName: system).font(.system(size: 13, weight: .bold))
                } else {
                    Text(text ?? "").font(.onest(13, .heavy))
                }
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, text == nil ? 0 : 12)
            .frame(minWidth: 36)
            .frame(height: 36)
            .background(Capsule().fill(Color.paperDeep))
        }
        .pressable()
    }
}

// MARK: - Fretboard

/// A horizontal neck, high E on top like the tab above it. Tap to write.
private struct TabFretboard: View {
    @Environment(SongStore.self) private var store
    private let frets = 15
    private let cellW: CGFloat = 46, openW: CGFloat = 38, cellH: CGFloat = 32

    var body: some View {
        let pal = store.palette
        let scale = Set(store.scalePitchClasses)
        let hint = Set(store.tabHint)
        let selected = store.cursorEvent?.notes ?? []
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow(text: store.tabStack ? "TAP TO ADD TO THE SELECTED CHORD" : "TAP TO WRITE A NOTE")
                Spacer()
                Eyebrow(text: "· = IN \(store.keyName.uppercased())")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 2) {
                    ZStack(alignment: .topLeading) {
                        board
                        ForEach(0..<6, id: \.self) { row in
                            let s = 5 - row
                            HStack(spacing: 0) {
                                ForEach(0...frets, id: \.self) { f in
                                    let pc = m12(Theory.tuning[s] + f)
                                    let isSel = selected.contains(TabNote(string: s, fret: f))
                                    cell(pc: pc, fret: f, inScale: scale.contains(pc), hinted: hint.contains(pc),
                                         selected: isSel, pal: pal)
                                        .onTapGesture { store.tabTap(string: s, fret: f) }
                                }
                            }
                            .offset(y: CGFloat(row) * cellH)
                        }
                    }
                    .frame(width: openW + CGFloat(frets) * cellW, height: 6 * cellH, alignment: .topLeading)
                    HStack(spacing: 0) {
                        Text("0").frame(width: openW)
                        ForEach(1...frets, id: \.self) { f in
                            Text("\(f)").frame(width: cellW)
                                .foregroundStyle([3, 5, 7, 9, 12, 15].contains(f) ? Color.mutedDeep : Color.mutedLight)
                        }
                    }
                    .font(.mono(10, .bold))
                    .foregroundStyle(Color.muted)
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -14)
        }
    }

    /// Frets, strings and inlays.
    private var board: some View {
        Canvas { ctx, size in
            ctx.fill(Path(roundedRect: CGRect(x: openW, y: 0, width: size.width - openW, height: size.height), cornerRadius: 8),
                     with: .color(Color.paperDeep.opacity(0.8)))
            for (f, double) in [(3, false), (5, false), (7, false), (9, false), (12, true), (15, false)] where f <= frets {
                let x = openW + (CGFloat(f) - 0.5) * cellW
                if double {
                    for y in [cellH * 1.5 + cellH / 2, cellH * 3.5 + cellH / 2] {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(.inlay))
                    }
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: size.height / 2 - 5, width: 10, height: 10)), with: .color(.inlay))
                }
            }
            for f in 0...frets {
                let x = openW + CGFloat(f) * cellW
                var p = Path(); p.move(to: CGPoint(x: x, y: 2)); p.addLine(to: CGPoint(x: x, y: size.height - 2))
                ctx.stroke(p, with: .color(f == 0 ? .ink : .paperLine), lineWidth: f == 0 ? 5 : 2)
            }
            for row in 0..<6 {
                let y = (CGFloat(row) + 0.5) * cellH
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(row >= 3 ? Color.mutedDeep.opacity(0.7) : Color.muted), lineWidth: 0.9 + CGFloat(row) * 0.3)
            }
        }
        .allowsHitTesting(false)
    }

    private func cell(pc: Int, fret: Int, inScale: Bool, hinted: Bool, selected: Bool, pal: Palette) -> some View {
        ZStack {
            if selected {
                Text("\(fret)")
                    .font(.onest(12, .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(pal.col(pc)))
                    .ring(Circle(), gap: 2, width: 2, color: Color.accent)
            } else if hinted {
                Text(store.name(pc))
                    .font(.onest(9.5, .heavy))
                    .foregroundStyle(pal.tintFg(pc))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(pal.tint(pc)))
                    .overlay(Circle().strokeBorder(pal.col(pc), lineWidth: 2))
            } else if inScale {
                Circle().fill(Color.mutedLight.opacity(0.7)).frame(width: 5, height: 5)
            }
        }
        .frame(width: fret == 0 ? openW : cellW, height: cellH)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.2), value: selected)
        .animation(.easeOut(duration: 0.2), value: hinted)
    }
}

// MARK: - Analysis

private struct TabAnalysisView: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        if let a = store.tabAnalysis, a.noteCount > 0 {
            VStack(spacing: 12) {
                keyCard(a)
                chordsCard(a)
                checkCard(a)
                nextCard(a)
            }
        } else {
            TipCard(text: "Tap a string and fret on the neck above to write your first note. Pick the length first; choose Chord to stack several notes in one column.",
                    topic: .tab)
        }
    }

    private func header(_ title: String, _ meta: String? = nil, topic: LearnTopic? = nil) -> some View {
        HStack {
            Text(title).font(.onest(18, .heavy)).em(-0.025, 18)
            if let topic { InfoButton(topic: topic).padding(-4) }
            Spacer()
            if let meta { Eyebrow(text: meta) }
        }
    }

    private func keyCard(_ a: TabAnalysis) -> some View {
        let pal = store.palette
        let top = a.guesses.first
        // The finder only knows major and minor; Dorian counts as minor, Mixolydian as major.
        let songMinor = store.mode == .minor || store.mode == .dorian
        let matches = top.map { $0.key == store.key && ($0.mode == .minor) == songMinor } ?? true
        return PaperCard(padding: EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)) {
            VStack(alignment: .leading, spacing: 10) {
                header("Key", "\(a.noteCount) NOTE\(a.noteCount == 1 ? "" : "S")", topic: .keyFinding)
                if let top {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(store.name(top.key)) \(top.mode.name.lowercased())")
                            .font(.onest(30, .black))
                            .em(-0.04, 30)
                            .foregroundStyle(pal.col(top.key, 0.56, 0.2))
                        Text(confidence(top, a.guesses))
                            .font(.mono(10, .bold))
                            .foregroundStyle(Color.muted)
                    }
                    Text(matches ? "Sounds like the song's key. Everything fits together."
                         : "The song is in \(store.keyName), but these notes lean towards \(store.name(top.key)) \(top.mode.name.lowercased()).")
                        .font(.onest(12.5, .medium))
                        .foregroundStyle(Color.mutedDeep)
                        .fixedSize(horizontal: false, vertical: true)
                    if a.guesses.count > 1 {
                        HStack(spacing: 6) {
                            Eyebrow(text: "OR")
                            ForEach(a.guesses.dropFirst()) { g in
                                Text("\(store.name(g.key)) \(g.mode.name.lowercased())")
                                    .font(.onest(12, .bold))
                                    .foregroundStyle(pal.tintFg(g.key))
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .background(Capsule().fill(pal.tint(g.key)))
                            }
                        }
                    }
                    if !matches {
                        Button { withAnimation(.settle) { store.setKeyOnly(top.key, top.mode) } } label: {
                            Text("Set song key to \(store.name(top.key)) \(top.mode.name.lowercased())")
                                .font(.onest(13, .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Capsule().fill(Color.ink))
                        }
                        .pressable()
                    }
                } else {
                    Text("Write at least three different notes and Chordflow will guess the key.")
                        .font(.onest(12.5, .medium))
                        .foregroundStyle(Color.mutedDeep)
                }
            }
        }
    }

    private func confidence(_ top: KeyGuess, _ all: [KeyGuess]) -> String {
        guard all.count > 1 else { return "" }
        let gap = top.score - all[1].score
        return gap > 0.12 ? "CLEAR" : gap > 0.04 ? "LIKELY" : "CLOSE CALL"
    }

    private func chordsCard(_ a: TabAnalysis) -> some View {
        let pal = store.palette
        return PaperCard(padding: EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)) {
            VStack(alignment: .leading, spacing: 10) {
                header("Chords it outlines", "PER BAR", topic: .chordFinder)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(a.bars) { bar in
                            Button {
                                if let c = bar.chord { store.hint(c.root, c.q) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("BAR \(bar.index + 1)").font(.mono(8.5, .bold)).opacity(0.7)
                                    Text(bar.chord.map { store.chordName($0.root, $0.q) } ?? "–")
                                        .font(.onest(17, .heavy))
                                    Text(bar.chord.map { store.numeral($0.root, $0.q) } ?? "rest")
                                        .font(.mono(9, .bold)).opacity(0.7)
                                }
                                .foregroundStyle(bar.chord.map { pal.tintFg($0.root) } ?? Color.muted)
                                .padding(.horizontal, 11)
                                .frame(minWidth: 62, alignment: .leading)
                                .frame(height: 62)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(bar.chord.map { pal.tint($0.root) } ?? Color.paperDeep))
                            }
                            .pressable()
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -14)
                Text("Each bar gets the chord that explains most of its notes, weighing long notes more. Tap one to hear it and see its notes on the neck.")
                    .font(.onest(12, .medium))
                    .foregroundStyle(Color.mutedDeep)
                    .fixedSize(horizontal: false, vertical: true)
                Button { withAnimation(.settle) { store.sectionFromTab() } } label: {
                    Label("Add these chords as a section", systemImage: "plus")
                        .font(.onest(13, .heavy))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Capsule().fill(Color.paperDeep))
                }
                .pressable()
                .disabled(a.bars.allSatisfy { $0.chord == nil })
            }
        }
    }

    private func checkCard(_ a: TabAnalysis) -> some View {
        PaperCard(padding: EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)) {
            VStack(alignment: .leading, spacing: 10) {
                header("Does it make sense?")
                ForEach(a.hints) { h in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: h.kind == .good ? "checkmark.circle.fill"
                              : h.kind == .warn ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(h.kind == .good ? Color(hex: 0x2E9E6A) : h.kind == .warn ? Color.accent : Color.muted)
                            .padding(.top, 1)
                        Text(h.text)
                            .font(.onest(13, .medium))
                            .lineSpacing(3)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func nextCard(_ a: TabAnalysis) -> some View {
        let pal = store.palette
        let ideas = store.tabNextIdeas(a)
        return PaperCard(padding: EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)) {
            VStack(alignment: .leading, spacing: 10) {
                header("Where next?", "IN \(store.keyName.uppercased())", topic: .functions)
                Text("Pick a chord to move to. Its notes light up on the neck: land on one of them on the next downbeat and the change will be clear.")
                    .font(.onest(12, .medium))
                    .foregroundStyle(Color.mutedDeep)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(ideas) { s in
                    let on = store.tabHint == s.q.intervals.map { m12(s.root + $0) }
                    Button { store.hint(s.root, s.q) } label: {
                        HStack(spacing: 12) {
                            Text(store.chordName(s.root, s.q))
                                .font(.onest(20, .black))
                                .foregroundStyle(pal.col(s.root, 0.56, 0.2))
                                .frame(minWidth: 54, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.why).font(.onest(12.5, .semibold)).foregroundStyle(Color.ink)
                                Text("\(store.numeral(s.root, s.q)) · notes \(s.q.intervals.map { store.name(s.root + $0) }.joined(separator: " "))")
                                    .font(.mono(10, .bold))
                                    .foregroundStyle(Color.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: on ? "eye.fill" : "eye")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(on ? Color.accent : Color.muted)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? Color.white : Color.paperDeep.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
