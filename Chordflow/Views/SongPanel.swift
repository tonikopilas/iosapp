import SwiftUI

/// Chip frames in global space, kept outside of view state so scrolling doesn't re-render the panel.
private final class FrameBox {
    var frames: [String: CGRect] = [:]
    var viewport: CGRect = .zero
}

private struct DragState {
    var sectionID: String
    var chordID: String
    /// Finger position relative to the chip's top-left at lift.
    var grab: CGSize
    var location: CGPoint
    var lastReorder = Date.distantPast
}

struct SongPanel: View {
    @Environment(SongStore.self) private var store
    @State private var box = FrameBox()
    @State private var drag: DragState?
    @State private var layoutTick = 0

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    ForEach(store.sections) { section in
                        sectionCard(section)
                    }

                    Button {
                        withAnimation(.settle) { store.addSection() }
                    } label: {
                        HStack(spacing: 8) {
                            PlusIcon(size: 16, weight: 2.75)
                            Text("Add section").font(.onest(14, .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .glass(Capsule(), tint: .white.opacity(0.1))
                    }
                    .pressable(0.98)

                    Text("Tap a chord to hear it. Hold and drag to reorder. Red dot = outside the key.")
                        .font(.onest(12, .medium))
                        .lineSpacing(6)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Eyebrow(text: "\(s.chords.count) BARS")
                    Button { store.playSection(s) } label: {
                        PlayIcon(size: 13)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.ink))
                    }
                    .pressable(0.9)
                    .accessibilityLabel("Play from here")
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(s.chords) { c in
                        chip(c, in: s)
                            .id(c.id)
                            .zIndex(store.dragID == c.id ? 20 : 1)
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
                        .frame(height: 98)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.paperDash, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .pressable()
                }
            }
        }
    }

    // MARK: Chip

    @ViewBuilder
    private func chip(_ c: Chord, in s: SongSection) -> some View {
        let pal = store.palette
        let isSel = store.sel.chordID == c.id
        let isPlay = store.playing && isSel
        let isDrag = store.dragID == c.id
        let name = store.chordName(c)
        let fg: Color = isPlay ? .white : .ink
        let beats = store.beatsPerChord
        let prog: CGFloat = isPlay ? min(1, CGFloat(store.beat + 1) / CGFloat(beats)) : 0
        let scale: CGFloat = isDrag ? 1.08 : isPlay ? (store.lit ? 1.07 : 1.03) : 1

        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                // Touch layer (tap to hear, hold to drag)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isPlay ? pal.col(c.root, 0.6, 0.2) : pal.tint(c.root))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                    .gesture(dragGesture(c, s).exclusively(before: TapGesture().onEnded {
                        store.tap(sectionID: s.id, chordID: c.id)
                    }))

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
                    let nameSize: CGFloat = name.count > 4 ? 15 : name.count > 3 ? 18 : 22
                    Text(name)
                        .font(.onest(nameSize, .heavy))
                        .em(-0.035, nameSize)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 3)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(fg)
                .padding(EdgeInsets(top: 9, leading: 9, bottom: 8, trailing: 9))
                .allowsHitTesting(false)

                TextField("", text: Binding(get: { c.lyric }, set: { store.setLyric(c.id, $0) }),
                          prompt: Text("lyric…").foregroundStyle(fg.opacity(0.4)))
                    .font(.onest(11.5, .medium))
                    .foregroundStyle(fg)
                    .tint(.accent)
                    .lineLimit(1)
                    .submitLabel(.done)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 8)

                // Beat progress
                GeometryReader { g in
                    Rectangle()
                        .fill(.white.opacity(0.9))
                        .frame(width: g.size.width * prog, height: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .animation(isPlay ? .linear(duration: 60 / Double(store.bpm)) : nil, value: prog)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 98)
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
                    .opacity(isSel && !isDrag ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: isSel)
                    .allowsHitTesting(false)
            )

            if isSel && !store.playing && !isDrag {
                Button {
                    withAnimation(.settle) { store.delete(sectionID: s.id, chordID: c.id) }
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
        .shadow(color: .black.opacity(isDrag ? 0.35 : 0), radius: 20, y: 18)
        .scaleEffect(scale)
        .animation(.bounce, value: scale)
        .offset(dragOffset(for: c.id))
        .transaction { t in if isDrag { t.animation = nil } }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { r in
            box.frames[c.id] = r
            if drag != nil { layoutTick &+= 1 }
        }
    }

    // MARK: Drag to reorder

    private func dragOffset(for id: String) -> CGSize {
        _ = layoutTick
        guard let d = drag, d.chordID == id, let r = box.frames[id] else { return .zero }
        return CGSize(width: d.location.x - d.grab.width - r.minX, height: d.location.y - d.grab.height - r.minY)
    }

    private func dragGesture(_ c: Chord, _ s: SongSection) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let dv) = value else { return }
                if store.dragID != c.id {
                    // Lifted: grow the chip and lock paging before the finger moves.
                    store.dragID = c.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                guard let dv else { return }
                if drag == nil {
                    guard let r = box.frames[c.id] else { return }
                    let start = dv.startLocation
                    drag = DragState(sectionID: s.id, chordID: c.id,
                                     grab: CGSize(width: start.x - r.minX, height: start.y - r.minY),
                                     location: start)
                }
                drag?.location = dv.location
                reorderIfHovering(dv.location)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                    drag = nil
                    store.dragID = nil
                }
            }
    }

    private func reorderIfHovering(_ p: CGPoint) {
        guard let d = drag, Date().timeIntervalSince(d.lastReorder) > 0.18,
              let sec = store.sections.first(where: { $0.id == d.sectionID }) else { return }
        for (i, other) in sec.chords.enumerated() where other.id != d.chordID {
            if let r = box.frames[other.id], r.contains(p) {
                drag?.lastReorder = Date()
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                    store.reorder(sectionID: d.sectionID, chordID: d.chordID, to: i)
                }
                return
            }
        }
    }
}
