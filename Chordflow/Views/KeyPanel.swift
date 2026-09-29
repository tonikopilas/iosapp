import SwiftUI

struct Wedge: Shape {
    var r0: CGFloat, r1: CGFloat, a0: Double, a1: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: r1, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
        p.addArc(center: c, radius: r0, startAngle: .radians(a1), endAngle: .radians(a0), clockwise: true)
        p.closeSubpath()
        return p
    }
}

private struct CircleSegment: Identifiable {
    var id: String
    var pc: Int
    var minor: Bool
    var r0: CGFloat, r1: CGFloat
    var angle: Double
    var label: String
    var inKey: Bool
    var isCurrent: Bool
    var isKey: Bool
    var numeral: String
}

struct KeyPanel: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 14) {
                header
                circle
                    .padding(.vertical, 4)
                scaleCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Circle of fifths").font(.onest(22, .heavy)).em(-0.03, 22)
                Text("Lit wedges are in your key. Tap one to move the song there.")
                    .font(.onest(12.5, .medium))
                    .lineSpacing(5)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    roundButton("−") { store.transpose(-1) }.accessibilityLabel("Transpose down")
                    roundButton("+") { store.transpose(1) }.accessibilityLabel("Transpose up")
                }
                Eyebrow(text: "TRANSPOSE", size: 9.5, tracking: 0.1, color: .white.opacity(0.55))
            }
        }
        .padding(.horizontal, 4)
    }

    private func roundButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.onest(17, .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.14)))
        }
        .pressable(0.9)
    }

    // MARK: Circle of fifths

    private var segments: [CircleSegment] {
        let cur = store.current
        let dia = store.diatonic
        let hasCur = store.hasCurrent
        let minorish = store.mode == .minor || store.mode == .dorian
        var out: [CircleSegment] = []
        for (i, pc) in Theory.fifths.enumerated() {
            let a = (-90 + Double(i) * 30) * .pi / 180
            for (minor, p, r0, r1, label) in [(false, pc, CGFloat(110), CGFloat(160), Theory.circleMajor[i]),
                                              (true, m12(pc + 9), CGFloat(66), CGFloat(107), Theory.circleMinor[i])] {
                let off = m12(p - store.key)
                let dd = dia.first { $0.off == off }
                let ink = dd != nil && dd!.q == (minor ? .min : .maj)
                let isCur = hasCur && p == cur.root && (minor ? cur.q.isMinorish : cur.q.isMajorish)
                out.append(CircleSegment(id: "\(minor)\(i)", pc: p, minor: minor, r0: r0, r1: r1, angle: a, label: label,
                                         inKey: ink, isCurrent: isCur, isKey: p == store.key && minor == minorish,
                                         numeral: ink ? Theory.numeral(off, minor ? .min : .maj, store.mode) : ""))
            }
        }
        return out
    }

    private var circle: some View {
        let pal = store.palette
        let g = 1.4 * Double.pi / 180, h = 15 * Double.pi / 180
        let cx: CGFloat = 165
        return ZStack {
            ForEach(segments) { s in
                let shape = Wedge(r0: s.r0, r1: s.r1, a0: s.angle - h + g, a1: s.angle + h - g)
                let fill: Color = s.isCurrent ? pal.col(s.pc, 0.74, 0.2)
                    : s.inKey ? pal.col(s.pc, s.minor ? 0.5 : 0.56, 0.16) : .white.opacity(0.07)
                shape
                    .fill(fill)
                    .overlay(shape.stroke(Color.white.opacity(s.isKey ? 1 : 0), lineWidth: 2.5))
                    .shadow(color: s.isCurrent ? pal.col(s.pc, 0.7, 0.2, 0.8) : .clear, radius: s.isCurrent ? 10 : 0)
                    .contentShape(shape)
                    .onTapGesture { store.circleKey(s.pc, minor: s.minor) }
                    .animation(.easeInOut(duration: 0.6), value: fill)
                    .animation(.easeOut(duration: 0.3), value: s.isKey)
            }
            ForEach(segments) { s in
                let rm = (s.r0 + s.r1) / 2
                let x = cx + rm * cos(s.angle), y = cx + rm * sin(s.angle)
                Text(s.label)
                    .font(.onest(s.minor ? 11.5 : 15, .heavy))
                    .foregroundStyle(.white.opacity(s.inKey || s.isCurrent ? 1 : 0.5))
                    .fixedSize()
                    .position(x: x, y: y - (s.inKey ? 5 : 0))
                    .animation(.easeInOut(duration: 0.6), value: s.inKey)
                    .allowsHitTesting(false)
                Text(s.numeral)
                    .font(.mono(8.5, .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize()
                    .position(x: x, y: y + 9)
                    .allowsHitTesting(false)
            }
            Circle().fill(.white.opacity(0.08)).frame(width: 112, height: 112)
                .position(x: cx, y: cx)
                .allowsHitTesting(false)
            Text(store.name(store.key))
                .font(.onest(40, .black))
                .em(-0.04, 40)
                .fixedSize()
                .position(x: cx, y: 158)
                .contentTransition(.numericText())
                .animation(.settle, value: store.key)
            Text(store.mode.name.uppercased())
                .font(.mono(10, .bold))
                .em(0.12, 10)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize()
                .position(x: cx, y: 188)
        }
        .frame(width: 330, height: 330)
        .frame(maxWidth: .infinity)
    }

    // MARK: Scale card

    private var scaleCard: some View {
        let pal = store.palette
        let cur = store.current
        let curPcs = cur.chord.pitchClasses
        return PaperCard(padding: EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Scale").font(.onest(20, .heavy)).em(-0.025, 20)
                    Spacer()
                    Eyebrow(text: store.keyName.uppercased())
                }

                HStack(spacing: 0) {
                    ForEach(Mode.allCases) { m in
                        let on = store.mode == m
                        Button { store.setMode(m) } label: {
                            Text(m.name)
                                .font(.onest(12, .bold))
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
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

                HStack(spacing: 0) {
                    ForEach(Array(store.scalePitchClasses.enumerated()), id: \.offset) { i, pc in
                        let tone = curPcs.contains(pc)
                        Button { store.note(60 + m12(pc)) } label: {
                            VStack(spacing: 5) {
                                Text(store.name(pc))
                                    .font(.onest(14, .heavy))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(pal.col(pc)))
                                    .ring(Circle(), gap: 3, width: 2, color: pal.col(pc), visible: tone)
                                    .scaleEffect(store.lit && tone ? 1.12 : 1)
                                    .animation(.bounce, value: store.lit)
                                    .animation(.easeInOut(duration: 0.5), value: pc)
                                Text("\(i + 1)").font(.mono(10, .bold)).foregroundStyle(Color.muted)
                            }
                        }
                        .buttonStyle(.plain)
                        if i < 6 { Spacer(minLength: 0) }
                    }
                }

                Eyebrow(text: "CHORDS IN THIS KEY · TAP TO HEAR · + TO ADD")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4), spacing: 8) {
                    ForEach(store.diatonic, id: \.degree) { d in
                        diatonicTile(d)
                    }
                }
            }
        }
    }

    private func diatonicTile(_ d: Theory.DiatonicChord) -> some View {
        let pal = store.palette
        let cur = store.current
        let root = m12(store.key + d.off)
        let isCur = store.hasCurrent && root == cur.root && d.q == cur.q
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Theory.numeral(d.off, d.q, store.mode))
                    .font(.mono(10, .bold))
                    .foregroundStyle(pal.tintFg(root))
                Spacer(minLength: 0)
                Text(store.chordName(root, d.q))
                    .font(.onest(20, .heavy))
                    .em(-0.03, 20)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.ink)
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 74)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(pal.tint(root)))
            .ring(RoundedRectangle(cornerRadius: 18, style: .continuous), gap: 2.5, width: 2, color: .accent, visible: isCur)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture { store.preview(root, d.q) }
            .animation(.easeInOut(duration: 0.5), value: root)

            Button {
                withAnimation(.settle) { store.addChord(root, d.q) }
            } label: {
                PlusIcon(size: 12, weight: 3.2)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.ink))
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .pressable(0.88)
            .padding(1)
            .accessibilityLabel("Add to song")
        }
    }
}
