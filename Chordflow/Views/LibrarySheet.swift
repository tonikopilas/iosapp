import SwiftUI

/// All saved songs, plus templates to start a new one. Songs save automatically as you edit.
struct LibrarySheet: View {
    @Environment(SongStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: Song?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "Your songs", subtitle: "\(store.library.count) SAVED") { dismiss() }

                HStack(alignment: .firstTextBaseline) {
                    Text("Start new").font(.onest(16, .heavy))
                    Spacer()
                    Eyebrow(text: "FROM A TEMPLATE", size: 10, tracking: 0.1, color: .white.opacity(0.55))
                }
                .padding(.horizontal, 18)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(SongTemplate.all) { t in
                            Button { store.create(from: t) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    PlusIcon(size: 16, weight: 3)
                                        .foregroundStyle(Color.ink)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(.white.opacity(0.92)))
                                    Spacer(minLength: 0)
                                    Text(t.name).font(.onest(16, .heavy)).lineLimit(1)
                                    Text(t.detail).font(.onest(11.5, .medium)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                                }
                                .foregroundStyle(.white)
                                .padding(12)
                                .frame(width: 132, height: 116, alignment: .leading)
                                .glass(RoundedRectangle(cornerRadius: 22, style: .continuous), tint: .white.opacity(0.1))
                            }
                            .pressable()
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .scrollIndicators(.hidden)

                Text("Saved").font(.onest(16, .heavy))
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                if store.library.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("No saved songs yet").font(.onest(18, .heavy))
                        Text("Songs save by themselves as soon as you change something. Start from a template above, or close this and start writing.")
                            .font(.onest(13, .medium))
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 20)
                    .glass(RoundedRectangle(cornerRadius: 24, style: .continuous), tint: .white.opacity(0.06))
                    .padding(.horizontal, 14)
                }

                LazyVStack(spacing: 10) {
                    ForEach(store.library) { song in
                        songCard(song)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14)
                .animation(.settle, value: store.library.map(\.id))
            }
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
        .confirmationDialog("Delete “\(confirmDelete?.title ?? "")”?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete song", role: .destructive) {
                if let s = confirmDelete { store.deleteSong(s) }
                confirmDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func songCard(_ song: Song) -> some View {
        let pal = store.palette
        let isOpen = song.id == store.songID
        let chords = song.sections.flatMap(\.chords)
        let bars = song.totalBars
        let keyName = Theory.sharp[m12(song.key)] + " " + song.mode.name.lowercased()
        return PaperCard(radius: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(song.title.isEmpty ? "Untitled" : song.title)
                            .font(.onest(20, .heavy))
                            .em(-0.025, 20)
                            .lineLimit(1)
                        if isOpen {
                            Text("OPEN")
                                .font(.mono(9, .bold))
                                .em(0.1, 9)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .frame(height: 18)
                                .background(Capsule().fill(Color.accent))
                        }
                        Spacer(minLength: 0)
                        menu(song)
                    }
                    Eyebrow(text: "\(keyName.uppercased()) · \(song.bpm) BPM · \(song.timeSignature.rawValue) · \(formatBars(bars)) BARS" + (song.tabs.isEmpty ? "" : " · \(song.tabs.count) TAB\(song.tabs.count == 1 ? "" : "S")"))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        ForEach(Array(chords.prefix(8).enumerated()), id: \.offset) { _, c in
                            Text(Theory.sharp[m12(c.root)] + c.q.suffix)
                                .font(.onest(11, .heavy))
                                .foregroundStyle(pal.tintFg(c.root))
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .frame(height: 24)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(pal.tint(c.root)))
                        }
                        if chords.count > 8 {
                            Text("+\(chords.count - 8)").font(.mono(10, .bold)).foregroundStyle(Color.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("Edited \(song.updatedAt, format: .relative(presentation: .named))")
                        .font(.onest(11.5, .medium))
                        .foregroundStyle(Color.muted)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.accent, lineWidth: isOpen ? 2 : 0)
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .onTapGesture { store.open(song) }
    }

    private func menu(_ song: Song) -> some View {
        Menu {
            Button { store.duplicate(song) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button(role: .destructive) { confirmDelete = song } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.paperDeep))
                .contentShape(Circle())
        }
        .accessibilityLabel("Song options")
    }
}
