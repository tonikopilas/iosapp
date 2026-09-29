import SwiftUI

struct NextPanel: View {
    @Environment(SongStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: 2)

    var body: some View {
        let sg = store.suggestions
        let pal = store.palette
        let baseName = store.chordName(sg.base.root, sg.base.q)
        ScrollView(.vertical) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Text(baseName)
                        .font(.onest(19, .black))
                        .em(-0.03, 19)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(pal.tint(sg.base.root)))
                        .animation(.easeInOut(duration: 0.5), value: sg.base.root)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What comes next?").font(.onest(22, .heavy)).em(-0.03, 22)
                        Text("Ideas to follow \(baseName)\(sg.sectionName.map { " in " + $0 } ?? ""). Tap to hear, Add to drop it in.")
                            .font(.onest(12.5, .medium))
                            .lineSpacing(5)
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)

                sectionTitle("Strong moves", "FROM THE KEY")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(sg.strong) { x in SuggestionCard(s: x, dark: false) }
                }

                sectionTitle("Add some color", "BORROWED & SPICY")
                    .padding(.top, 6)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(sg.color) { x in SuggestionCard(s: x, dark: true) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
    }

    private func sectionTitle(_ title: String, _ eyebrow: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.onest(16, .heavy))
            Spacer()
            Eyebrow(text: eyebrow, size: 10, tracking: 0.1, color: .white.opacity(0.55))
        }
        .padding(.horizontal, 4)
    }
}

private struct SuggestionCard: View {
    @Environment(SongStore.self) private var store
    var s: Suggestion
    /// Glass card on the dark stage ("Add some color") instead of a paper card.
    var dark: Bool

    var body: some View {
        let pal = store.palette
        let basePcs = store.suggestions.base
        let baseSet = Set(basePcs.q.intervals.map { m12(basePcs.root + $0) })
        let pressed = store.previewKey == s.id

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.chordName(s.root, s.q))
                    .font(.onest(30, .black))
                    .em(-0.045, 30)
                    .foregroundStyle(dark ? pal.col(s.root, 0.82, 0.13) : pal.col(s.root, 0.56, 0.2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text(store.numeral(s.root, s.q))
                    .font(.mono(11, .bold))
                    .foregroundStyle(dark ? .white.opacity(0.7) : Color.mutedDeep)
            }
            Text(s.why)
                .font(.onest(12.5, .medium))
                .lineSpacing(3)
                .foregroundStyle(dark ? .white.opacity(0.78) : Color.mutedDeep)
                .frame(minHeight: 34, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                ForEach(s.q.intervals, id: \.self) { i in
                    let p = m12(s.root + i)
                    let on = baseSet.contains(p)
                    Text(store.name(p))
                        .font(.onest(9.5, .heavy))
                        .foregroundStyle(on ? .white : (dark ? .white.opacity(0.75) : Color.mutedDeep))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(on ? pal.col(p) : .clear))
                        .overlay(Circle().strokeBorder(on ? .clear : (dark ? .white.opacity(0.35) : Color.outline), lineWidth: 1.5))
                }
                Text(s.shared > 0 ? "\(s.shared) shared" : "fresh")
                    .font(.mono(10, .semibold))
                    .foregroundStyle(dark ? .white.opacity(0.55) : Color.muted)
                    .padding(.leading, 4)
                    .lineLimit(1)
            }
            Button {
                withAnimation(.settle) { store.addChord(s.root, s.q) }
            } label: {
                HStack(spacing: 6) {
                    PlusIcon(size: 12, weight: 3.2)
                    Text("Add").font(.onest(12.5, .bold))
                }
                .foregroundStyle(dark ? Color.ink : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(dark ? Color.white.opacity(0.92) : Color.ink))
            }
            .pressable()
        }
        .padding(14)
        .foregroundStyle(dark ? .white : Color.ink)
        .background {
            let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
            if dark {
                Color.clear.glass(shape, tint: .white.opacity(0.1))
            } else {
                shape.fill(Color.paper)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { store.preview(s.root, s.q) }
        .scaleEffect(pressed ? 0.95 : 1)
        .animation(.bounce, value: pressed)
    }
}
