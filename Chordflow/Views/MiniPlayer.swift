import SwiftUI

struct MiniPlayer: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        let pal = store.palette
        let cur = store.current
        let nxt = store.nextChord
        let name = store.chordName(cur)
        let beats = store.beatsPerChord

        HStack(spacing: 12) {
            // Album-art style chord tile
            Text(name)
                .font(.onest(name.count > 4 ? 14 : name.count > 2 ? 18 : 22, .black))
                .em(-0.04, 18)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 3)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [pal.col(cur.root, 0.66, 0.2), pal.col(nxt.root, 0.46, 0.2)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .animation(.easeInOut(duration: 0.6), value: cur.root)
                        .animation(.easeInOut(duration: 0.6), value: nxt.root)
                )
                .shadow(color: .black.opacity(0.35), radius: 9, y: 6)
                .scaleEffect(store.lit ? 1.08 : 1)
                .animation(.bounce, value: store.lit)
                .onTapGesture { store.goPanel(1) }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(store.currentSection?.name ?? store.title)
                        .font(.onest(15.5, .heavy))
                        .em(-0.02, 15.5)
                    Text(store.numeral(cur.root, cur.q))
                        .font(.mono(10.5, .bold))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<beats, id: \.self) { i in
                            Capsule()
                                .fill(store.playing && i <= store.beat ? Color.white : .white.opacity(0.3))
                                .frame(width: store.playing && i == store.beat ? 18 : 6, height: 6)
                                .animation(.easeOut(duration: 0.2), value: store.beat)
                                .animation(.easeOut(duration: 0.2), value: store.playing)
                        }
                    }
                    Text(store.playing ? "Next: \(store.chordName(nxt))" : "Tap play to hear it")
                        .font(.onest(11, .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { store.toggleLoop() } label: {
                HStack(spacing: 5) {
                    LoopIcon()
                    Text(store.loop == .section ? "Section" : "Song").font(.onest(11, .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(Capsule().fill(store.loop == .section ? Color.accent.opacity(0.5) : .white.opacity(0.12)))
                .animation(.easeOut(duration: 0.25), value: store.loop)
            }
            .pressable()
            .accessibilityLabel("Loop song or section")

            Button { store.togglePlay() } label: {
                ZStack {
                    if store.playing {
                        PauseIcon()
                    } else {
                        PlayIcon(size: 18).padding(.leading, 2)
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.accent))
                .shadow(color: Color.accent.opacity(0.45), radius: 10, y: 6)
            }
            .pressable(0.94)
            .accessibilityLabel(store.playing ? "Pause" : "Play")
        }
        .padding(.leading, 11)
        .padding(.trailing, 12)
        .frame(height: 74)
        .background {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color(hex: 0x222028, opacity: 0.62))
                shape.strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.45), radius: 20, y: 14)
        }
        .foregroundStyle(.white)
        .sensoryFeedback(.impact(weight: .light), trigger: store.playing)
    }
}

struct PauseIcon: View {
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.1).frame(width: 3.75, height: 12)
            RoundedRectangle(cornerRadius: 1.1).frame(width: 3.75, height: 12)
        }
        .frame(width: 18, height: 18)
    }
}

struct LoopIcon: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 17, y: 2)); p.addLine(to: CGPoint(x: 21, y: 6)); p.addLine(to: CGPoint(x: 17, y: 10))
            p.move(to: CGPoint(x: 3, y: 11)); p.addLine(to: CGPoint(x: 3, y: 10))
            p.addArc(center: CGPoint(x: 7, y: 10), radius: 4, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: 21, y: 6))
            p.move(to: CGPoint(x: 7, y: 22)); p.addLine(to: CGPoint(x: 3, y: 18)); p.addLine(to: CGPoint(x: 7, y: 14))
            p.move(to: CGPoint(x: 21, y: 13)); p.addLine(to: CGPoint(x: 21, y: 14))
            p.addArc(center: CGPoint(x: 17, y: 14), radius: 4, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: 3, y: 18))
        }
        .stroke(style: StrokeStyle(lineWidth: 2.75, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
        .scaleEffect(14 / 24)
        .frame(width: 14, height: 14)
    }
}
