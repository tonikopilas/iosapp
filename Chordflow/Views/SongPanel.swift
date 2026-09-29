import SwiftUI
import UniformTypeIdentifiers

/// Chip frames in global space, kept outside of view state so scrolling doesn't re-render the panel.
private final class FrameBox {
    var frames: [String: CGRect] = [:]
    var viewport: CGRect = .zero
}

struct SongPanel: View {
    @Environment(SongStore.self) private var store
    @State private var box = FrameBox()
    @State private var renaming: SongSection?
    @State private var renameText = ""

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    if store.sections.isEmpty {
                        emptySong
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    ForEach(store.sections) { section in
                        sectionCard(section)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    addSectionButton

                    TipCard(text: "Tap a chord to hear it, tap it again to edit. Use − and + on the selected chord to change its length. Hold and drag to move it. A red dot means the chord uses notes outside the key.",
                            topic: .bars)
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { box.viewport = $0 }
            .onChange(of: store.sel.chordID) { _, cid in
                guard store.playing, let cid, let r = box.frames[cid] else { return }
                let vp = box.viewport
                if r.minY < vp.minY + 8 || r.maxY > vp.maxY - 120 {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo(cid, anchor: UnitPoint(x: 0.5, y: 0.12))
                    }
                }
            }
        }
        .alert("Rename section", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let s = renaming { store.renameSection(s.id, renameText) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    // MARK: Empty & add

    private var emptySong: some View {
        PaperCard(padding: EdgeInsets(top: 22, leading: 18, bottom: 18, trailing: 18)) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.paperDeep))
                Text("No sections yet").font(.onest(22, .heavy)).em(-0.03, 22)
                Text("Songs are built from sections like Verse and Chorus, each a row of chords. Add one to start, or pick a template with a ready-made progression.")
                    .font(.onest(13.5, .medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color.mutedDeep)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button { withAnimation(.settle) { store.addSection(named: "Verse") } } label: {
                        Text("Add a verse")
                            .font(.onest(14, .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Capsule().fill(Color.accent))
                    }
                    .pressable()
                    Button {
                        store.refreshLibrary()
                        store.showLibrary = true
                    } label: {
                        Text("Templates")
                            .font(.onest(14, .heavy))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Capsule().fill(Color.paperDeep))
                    }
                    .pressable()
                }
                .padding(.top, 4)
            }
        }
    }

    private var addSectionButton: some View {
        Menu {
            Section("Add a section named") {
                ForEach(["Intro", "Verse", "Pre-Chorus", "Chorus", "Bridge", "Solo", "Breakdown", "Outro"], id: \.self) { n in
                    Button(n) { withAnimation(.settle) { store.addSection(named: n) } }
                }
            }
        } label: {
            HStack(spacing: 8) {
                PlusIcon(size: 16, weight: 2.75)
                Text("Add section").font(.onest(14, .bold))
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).opacity(0.6)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .glass(Capsule(), tint: .white.opacity(0.1))
        } primaryAction: {
            withAnimation(.settle) { store.addSection() }
        }
        .accessibilityHint("Hold to choose a name")
    }

    // MARK: Section card

    private func sectionCard(_ s: SongSection) -> some View {
        let pal = store.palette
        return PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(s.chords.first.map { pal.col($0.root) } ?? Color.paperDash)
                        .frame(width: 10, height: 10)
                        .animation(.easeInOut(duration: 0.6), value: s.chords.first?.root)
                    Text(s.name)
                        .font(.onest(20, .heavy))
                        .em(-0.025, 20)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Eyebrow(text: sectionMeta(s))
                        .lineLimit(1)
                        .fixedSize()
                    sectionMenu(s)
                    Button { store.playSection(s) } label: {
                        PlayIcon(size: 13)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.ink))
                    }
                    .pressable(0.9)
                    .accessibilityLabel("Play from here")
                }

                if s.chords.isEmpty {
                    Text("Empty section. Tap Suggest for ideas, add chords from the Key or Next tab, or drag a chord in here.")
                        .font(.onest(12.5, .medium))
                        .lineSpacing(3)
                        .foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(s.chords) { c in
                        chip(c, in: s)
                            .id(c.id)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                    Button {
                        store.suggest(for: s.id)
                    } label: {
                        VStack(spacing: 4) {
                            PlusIcon(size: 20, weight: 2.75)
                            Text("Suggest").font(.onest(11, .bold))
                        }
                        .foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.paperDash, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .pressable()
                }

                sectionFooter(s)
            }
        }
        // Dropping on the card (not on a chord) moves the chord to the end of this section.
        .onDrop(of: [.text], delegate: SectionDrop(sectionID: s.id, store: store))
    }

    /// Repeat count and a clearly visible delete, so neither hides in the ••• menu.
    private func sectionFooter(_ s: SongSection) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                footerStep("minus", enabled: s.repeats > 1) { store.setRepeats(s.id, s.repeats - 1) }
                    .accessibilityLabel("Fewer repeats")
                Text(s.repeats == 1 ? "Plays once" : "Plays ×\(s.repeats)")
                    .font(.onest(12.5, .bold))
                    .monospacedDigit()
                    .frame(minWidth: 74)
                    .contentTransition(.numericText())
                footerStep("plus", enabled: s.repeats < 8) { store.setRepeats(s.id, s.repeats + 1) }
                    .accessibilityLabel("More repeats")
            }
            .frame(height: 34)
            .background(Capsule().fill(Color.paperDeep))
            .animation(.settle, value: s.repeats)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                withAnimation(.settle) { store.deleteSection(s.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(size: 12, weight: .bold))
                    Text("Delete").font(.onest(12.5, .bold))
                }
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(Color.accent.opacity(0.1)))
            }
            .pressable()
            .accessibilityLabel("Delete \(s.name)")
        }
    }

    private func footerStep(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(enabled ? Color.ink : Color.outline)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func sectionMeta(_ s: SongSection) -> String {
        let bars = formatBars(s.bars)
        return "\(bars) BAR\(s.bars == 1 ? "" : "S")" + (s.repeats > 1 ? " ×\(s.repeats)" : "")
    }

    private func sectionMenu(_ s: SongSection) -> some View {
        let index = store.sections.firstIndex { $0.id == s.id } ?? 0
        return Menu {
            Button {
                renameText = s.name
                renaming = s
            } label: { Label("Rename", systemImage: "pencil") }

            Picker(selection: Binding(get: { s.repeats }, set: { n in withAnimation { store.setRepeats(s.id, n) } })) {
                ForEach([1, 2, 3, 4, 8], id: \.self) { n in
                    Text(n == 1 ? "Play once" : "Repeat ×\(n)").tag(n)
                }
            } label: {
                Label("Repeat", systemImage: "repeat")
            }
            .pickerStyle(.menu)

            Menu {
                ForEach([0.5, 1, 2, 4], id: \.self) { b in
                    Button("\(formatBars(b)) bar\(b <= 1 ? "" : "s") each") {
                        withAnimation(.settle) { store.setAllBars(s.id, b) }
                    }
                }
            } label: { Label("Set all chord lengths", systemImage: "ruler") }

            Button {
                withAnimation(.settle) { store.duplicateSection(s.id) }
            } label: { Label("Duplicate", systemImage: "plus.square.on.square") }

            if index > 0 {
                Button {
                    withAnimation(.settle) { store.moveSection(s.id, by: -1) }
                } label: { Label("Move up", systemImage: "arrow.up") }
            }
            if index < store.sections.count - 1 {
                Button {
                    withAnimation(.settle) { store.moveSection(s.id, by: 1) }
                } label: { Label("Move down", systemImage: "arrow.down") }
            }

            Divider()
            Button(role: .destructive) {
                withAnimation(.settle) { store.deleteSection(s.id) }
            } label: { Label("Delete section", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.paperDeep))
                .contentShape(Circle())
        }
        .accessibilityLabel("Section options")
    }

    // MARK: Chip

    /// − length + right on the selected chord.
    private func lengthStepper(_ c: Chord) -> some View {
        let pal = store.palette
        return HStack(spacing: 0) {
            chipStep("minus", enabled: c.bars > 0.5) { withAnimation(.settle) { store.stepBars(c.id, up: false) } }
                .accessibilityLabel("Shorter")
            Text(store.lengthLabel(c).replacingOccurrences(of: " BARS", with: "").replacingOccurrences(of: " BAR", with: "")
                .replacingOccurrences(of: " BEATS", with: "b").replacingOccurrences(of: " BEAT", with: "b"))
                .font(.mono(11, .bold))
                .foregroundStyle(pal.tintFg(c.root))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            chipStep("plus", enabled: c.bars < 16) { withAnimation(.settle) { store.stepBars(c.id, up: true) } }
                .accessibilityLabel("Longer")
        }
        .frame(height: 22)
        .background(Capsule().fill(.white.opacity(0.7)))
        .padding(.horizontal, -4)
        .transition(.opacity)
    }

    private func chipStep(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(enabled ? Color.ink : Color.outline)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
    }

    @ViewBuilder
    private func chip(_ c: Chord, in s: SongSection) -> some View {
        let pal = store.palette
        let isSel = store.sel.chordID == c.id
        let isPlay = store.playing && isSel
        let name = store.chordName(c)
        let fg: Color = isPlay ? .white : .ink
        let total = store.beats(of: c)
        let prog: CGFloat = isPlay ? min(1, CGFloat(store.beat + 1) / CGFloat(total)) : 0
        let scale: CGFloat = isPlay ? (store.lit ? 1.07 : 1.03) : 1
        let nameSize: CGFloat = name.count > 4 ? 15 : name.count > 3 ? 18 : 22

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(store.numeral(c.root, c.q))
                        .font(.mono(10, .bold))
                        .foregroundStyle(isPlay ? .white.opacity(0.85) : pal.tintFg(c.root))
                    Spacer(minLength: 0)
                    if !store.inKey(c) {
                        Circle().fill(Color.accent).frame(width: 6, height: 6)
                            .accessibilityLabel("Outside the key")
                    }
                }
                Text(name)
                    .font(.onest(nameSize, .heavy))
                    .em(-0.035, nameSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 3)
                Spacer(minLength: 0)
                if isSel && !store.playing {
                    lengthStepper(c)
                } else {
                    Text(store.lengthLabel(c))
                        .font(.mono(9, .bold))
                        .em(0.06, 9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isPlay ? .white.opacity(0.75) : pal.tintFg(c.root).opacity(0.75))
                }
            }
            .foregroundStyle(fg)
            .padding(EdgeInsets(top: 9, leading: 9, bottom: 8, trailing: 9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isPlay ? pal.col(c.root, 0.6, 0.2) : pal.tint(c.root)))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { g in
                    Rectangle()
                        .fill(.white.opacity(0.9))
                        .frame(width: g.size.width * prog, height: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .animation(isPlay ? .linear(duration: 60 / Double(store.bpm)) : nil, value: prog)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .animation(.easeInOut(duration: 0.5), value: isPlay)
            .overlay(
                RoundedRectangle(cornerRadius: 20.5, style: .continuous)
                    .strokeBorder(Color.paper, lineWidth: 2.5)
                    .padding(-2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 22.5, style: .continuous)
                            .strokeBorder(Color.accent, lineWidth: 2)
                            .padding(-4.5)
                    )
                    .opacity(isSel ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: isSel)
                    .allowsHitTesting(false)
            )
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture { store.tap(sectionID: s.id, chordID: c.id) }
            .onDrag {
                store.dragID = c.id
                return NSItemProvider(object: c.id as NSString)
            }
            .onDrop(of: [.text], delegate: ChipDrop(targetID: c.id, store: store))

            if isSel && !store.playing {
                Button {
                    withAnimation(.settle) { store.delete(chordID: c.id) }
                } label: {
                    Text("×")
                        .font(.onest(13, .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.ink))
                        .overlay(Circle().strokeBorder(Color.paper, lineWidth: 2).padding(-2))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .pressable(0.9)
                .offset(x: 11, y: -11)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Remove")
            }
        }
        .scaleEffect(scale)
        .animation(.bounce, value: scale)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { box.frames[c.id] = $0 }
    }
}

// MARK: - Drag & drop

/// Hovering a dragged chord over another one moves it into that slot, live.
private struct ChipDrop: DropDelegate {
    let targetID: String
    let store: SongStore

    func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated {
            guard let d = store.dragID, d != targetID else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.move(d, onto: targetID) }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated { store.dragID = nil }
        return true
    }
}

/// Dragging a chord over another section's card moves it to the end of that section.
private struct SectionDrop: DropDelegate {
    let sectionID: String
    let store: SongStore

    func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated {
            guard let d = store.dragID,
                  let s = store.sections.first(where: { $0.id == sectionID }),
                  !s.chords.contains(where: { $0.id == d }) else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.move(d, toEndOf: sectionID) }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated { store.dragID = nil }
        return true
    }
}
