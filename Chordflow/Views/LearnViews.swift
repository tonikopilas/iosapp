import SwiftUI

/// Small ⓘ button that opens a theory lesson.
struct InfoButton: View {
    var topic: LearnTopic
    /// Dark ink on paper cards, white on the stage.
    var onPaper = true
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(onPaper ? Color.muted : .white.opacity(0.6))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learn: \(topic.title)")
        .sheet(isPresented: $show) {
            LessonSheet(start: topic)
                .chordflowSheet([.medium, .large])
        }
    }
}

/// A light-bulb note explaining what's on screen. Hidden when theory tips are off.
struct TipCard: View {
    @Environment(SongStore.self) private var store
    var text: String
    var topic: LearnTopic?
    var onPaper = false

    var body: some View {
        if store.showTips {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accent)
                    .padding(.top, 2)
                Text(text)
                    .font(.onest(12.5, .medium))
                    .lineSpacing(4)
                    .foregroundStyle(onPaper ? Color.mutedDeep : .white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let topic { InfoButton(topic: topic, onPaper: onPaper).padding(-4) }
            }
            .padding(12)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                if onPaper {
                    shape.fill(Color.paperDeep.opacity(0.7))
                } else {
                    Color.clear.glass(shape, tint: .white.opacity(0.06))
                }
            }
            .transition(.opacity)
        }
    }
}

/// One lesson, with links to related ones.
struct LessonSheet: View {
    @Environment(\.dismiss) private var dismiss
    var start: LearnTopic
    @State private var topic: LearnTopic?

    var body: some View {
        let t = topic ?? start
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: t.title, subtitle: "THEORY") { dismiss() }
                    .padding(.horizontal, -14)
                LessonBody(topic: t) { withAnimation(.settle) { topic = $0 } }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
    }
}

private struct LessonBody: View {
    var topic: LearnTopic
    var open: (LearnTopic) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaperCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, p in
                        Text(p)
                            .font(.onest(14.5, .medium))
                            .lineSpacing(5)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !topic.related.isEmpty {
                Eyebrow(text: "RELATED", size: 10, tracking: 0.1, color: .white.opacity(0.55))
                    .padding(.horizontal, 4)
                FlowRow(spacing: 8) {
                    ForEach(topic.related) { r in
                        Button { open(r) } label: {
                            Label(r.title, systemImage: r.symbol)
                                .font(.onest(13, .bold))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .glass(Capsule())
                        }
                        .pressable()
                    }
                }
            }
        }
    }
}

/// Every lesson in one place, opened from the header.
struct HandbookSheet: View {
    @Environment(SongStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var open: LearnTopic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let open {
                    SheetHeader(title: open.title, subtitle: "HANDBOOK") { dismiss() }
                        .padding(.horizontal, -14)
                    Button { withAnimation(.settle) { self.open = nil } } label: {
                        Label("All topics", systemImage: "chevron.left")
                            .font(.onest(13, .bold))
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .glass(Capsule())
                    }
                    .pressable()
                    LessonBody(topic: open) { t in withAnimation(.settle) { self.open = t } }
                } else {
                    SheetHeader(title: "Theory handbook", subtitle: "LEARN AS YOU WRITE") { dismiss() }
                        .padding(.horizontal, -14)
                    Text("Short lessons on everything Chordflow shows you. Look for the ⓘ buttons around the app for the lesson that fits.")
                        .font(.onest(13, .medium))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 4)
                    ForEach(LearnTopic.chapters.indices, id: \.self) { ci in
                        let chapter = LearnTopic.chapters[ci]
                        SettingCard(title: chapter.title) {
                            VStack(spacing: 0) {
                                ForEach(chapter.topics) { t in
                                    Button { withAnimation(.settle) { open = t } } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: t.symbol)
                                                .font(.system(size: 14, weight: .bold))
                                                .frame(width: 30, height: 30)
                                                .background(Circle().fill(Color.paperDeep))
                                            Text(t.title).font(.onest(15, .bold))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.muted)
                                        }
                                        .foregroundStyle(Color.ink)
                                        .padding(.vertical, 7)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    SettingCard(title: "Tips") {
                        Toggle(isOn: Binding(get: { store.showTips }, set: { store.setShowTips($0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Theory tips").font(.onest(15, .heavy))
                                Text("Light-bulb notes explaining each screen").font(.onest(12, .medium)).foregroundStyle(Color.mutedDeep)
                            }
                            .foregroundStyle(Color.ink)
                        }
                        .tint(.accent)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
    }
}

/// Wraps its children onto new lines when they don't fit.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
