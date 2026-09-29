import SwiftUI

/// Shared look for Chordflow's sheets: dark stage, big rounded corners.
extension View {
    func chordflowSheet(_ detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground {
                ZStack {
                    Color.stage
                    Color.white.opacity(0.04)
                }
            }
            .preferredColorScheme(.dark)
    }
}

/// Title row at the top of a sheet with a Done button.
struct SheetHeader: View {
    var title: String
    var subtitle: String?
    var done: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Eyebrow(text: subtitle, tracking: 0.14, color: .white.opacity(0.6))
                }
                Text(title).font(.onest(28, .black)).em(-0.035, 28)
            }
            Spacer()
            Button(action: done) {
                Text("Done")
                    .font(.onest(14, .heavy))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
            }
            .pressable()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }
}

/// Paper card with a title row, used to group settings.
struct SettingCard<Content: View>: View {
    var title: String
    var meta: String?
    @ViewBuilder var content: Content

    var body: some View {
        PaperCard(padding: EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.onest(18, .heavy)).em(-0.025, 18)
                    Spacer()
                    if let meta { Eyebrow(text: meta) }
                }
                content
            }
        }
    }
}

/// Pill segmented control in the paper style (like "Chord shape / Full scale").
struct PaperSegmented<T: Hashable>: View {
    var options: [T]
    var selection: T
    var label: (T) -> String
    var onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { o in
                let on = o == selection
                Button { onSelect(o) } label: {
                    Text(label(o))
                        .font(.onest(13, .bold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Capsule().fill(on ? Color.white : .clear)
                            .shadow(color: .black.opacity(on ? 0.1 : 0), radius: 3, y: 2))
                        .contentShape(Capsule())
                        .animation(.easeOut(duration: 0.25), value: on)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.paperDeep))
    }
}

/// 6×2 grid of the twelve notes, colored by the circle of fifths.
struct NoteGrid: View {
    @Environment(SongStore.self) private var store
    var selected: Int
    var onSelect: (Int) -> Void

    var body: some View {
        let pal = store.palette
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 6), spacing: 10) {
            ForEach(0..<12, id: \.self) { pc in
                let on = pc == selected
                Button { onSelect(pc) } label: {
                    Text(store.name(pc))
                        .font(.onest(14, .heavy))
                        .foregroundStyle(on ? .white : pal.tintFg(pc))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(on ? pal.col(pc) : pal.tint(pc)))
                        .ring(Circle(), gap: 2.5, width: 2, color: pal.col(pc), visible: on)
                        .scaleEffect(on ? 1.06 : 1)
                        .animation(.bounce, value: on)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
