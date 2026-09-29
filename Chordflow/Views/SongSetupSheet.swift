import SwiftUI

/// Tempo, meter, key, sound, playing style and metronome for the current song.
struct SongSetupSheet: View {
    @Environment(SongStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let pal = store.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "Song setup", subtitle: store.title.isEmpty ? "UNTITLED" : store.title.uppercased()) { dismiss() }
                    .padding(.horizontal, -14)

                tempo

                SettingCard(title: "Time signature", meta: "\(store.beatsPerBar) BEATS PER BAR") {
                    PaperSegmented(options: Array(TimeSignature.allCases.prefix(4)), selection: store.timeSignature,
                                   label: { $0.rawValue },
                                   onSelect: { store.setTimeSignature($0) })
                    PaperSegmented(options: Array(TimeSignature.allCases.dropFirst(4)), selection: store.timeSignature,
                                   label: { $0.rawValue },
                                   onSelect: { store.setTimeSignature($0) })
                    explain(store.timeSignature.detail, .meter)
                }

                SettingCard(title: "Key", meta: store.keyName.uppercased()) {
                    NoteGrid(selected: store.key) { pc in withAnimation(.settle) { store.setKeyRoot(pc) } }
                    PaperSegmented(options: Mode.allCases, selection: store.mode,
                                   label: { $0.name },
                                   onSelect: { store.setMode($0) })
                    explain(store.modeBlurb + " Changing the key root moves every chord with it.", .modes)
                }

                SettingCard(title: "Sound") {
                    HStack(spacing: 8) {
                        ForEach(Sound.allCases) { s in
                            let on = s == store.sound
                            Button { store.setSound(s) } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: symbol(s))
                                        .font(.system(size: 22, weight: .semibold))
                                    Text(s.label).font(.onest(13, .heavy))
                                }
                                .foregroundStyle(on ? .white : Color.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 84)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(on ? pal.col(store.current.root, 0.6, 0.2) : Color.paperDeep))
                                .animation(.easeOut(duration: 0.25), value: on)
                            }
                            .pressable()
                        }
                    }
                }

                SettingCard(title: "Playing style") {
                    VStack(spacing: 6) {
                        ForEach(PlayStyle.allCases) { s in
                            let on = s == store.style
                            Button { store.setStyle(s) } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.label).font(.onest(15, .heavy))
                                        Text(s.detail).font(.onest(12, .medium)).foregroundStyle(Color.mutedDeep)
                                    }
                                    Spacer()
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(on ? Color.accent : Color.outline)
                                }
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(on ? Color.white : Color.paperDeep.opacity(0.6)))
                                .animation(.easeOut(duration: 0.2), value: on)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    explain("Press play to hear the style across the song. Any chord can use its own style from its editor.", .styles)
                }

                SettingCard(title: "Feel") {
                    slider("Strum speed", value: store.strumSpeed, in: 2...80,
                           left: "Snappy", right: "Lazy", readout: "\(Int(store.strumSpeed)) ms") { store.setStrumSpeed($0) }
                    slider("Let ring", value: store.ring, in: 0.25...2,
                           left: "Staccato", right: "Sustained", readout: "\(Int((store.ring * 100).rounded()))%") { store.setRing($0) }
                    slider("Swing", value: store.swing, in: 0...1,
                           left: "Straight", right: "Shuffle", readout: store.swing < 0.05 ? "Off" : "\(Int((store.swing * 100).rounded()))%") { store.setSwing($0) }
                    explain("Strum speed is the gap between strings. Let ring sets how long notes sustain. Swing delays every off-beat eighth, the shuffle feel of blues and jazz (heard in Arpeggio style).", nil)
                }

                SettingCard(title: "Metronome & look") {
                    VStack(spacing: 4) {
                        toggle("Click", "Metronome on every beat", store.click, store.setClick)
                        slider("Click volume", value: store.clickVolume, in: 0...1, left: "Soft", right: "Loud",
                               readout: "\(Int((store.clickVolume * 100).rounded()))%") { store.setClickVolume($0) }
                            .padding(.vertical, 4)
                        toggle("Count-in", "Clicks before playing starts", store.countIn, store.setCountIn)
                        if store.countIn {
                            PaperSegmented(options: [1, 2], selection: store.countInBars,
                                           label: { "\($0) bar\($0 == 1 ? "" : "s")" },
                                           onSelect: { store.setCountInBars($0) })
                        }
                        toggle("Color notes", "Each note gets its own color", store.colorNotes, store.setColorNotes)
                        toggle("Theory tips", "Explanations around the app", store.showTips, store.setShowTips)
                    }
                    .animation(.settle, value: store.countIn)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private var tempo: some View {
        SettingCard(title: "Tempo") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.bpm)")
                    .font(.onest(52, .black))
                    .em(-0.05, 52)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(store.bpm)))
                    .animation(.settle, value: store.bpm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BPM").font(.mono(12, .bold)).foregroundStyle(Color.muted)
                    Text(store.tempoName).font(.onest(11.5, .semibold)).foregroundStyle(Color.mutedDeep)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                roundButton("−") { store.setBPM(store.bpm - 1) }
                roundButton("+") { store.setBPM(store.bpm + 1) }
            }
            Slider(value: Binding(get: { Double(store.bpm) }, set: { store.setBPM(Int($0.rounded())) }),
                   in: 40...220, step: 1)
                .tint(.accent)
            Button { store.tapTempo() } label: {
                Text("Tap tempo")
                    .font(.onest(14, .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.accent))
            }
            .pressable(0.97)
        }
    }

    private func explain(_ text: String, _ topic: LearnTopic?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(text)
                .font(.onest(12, .medium))
                .lineSpacing(3)
                .foregroundStyle(Color.mutedDeep)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let topic { InfoButton(topic: topic).padding(-6) }
        }
    }

    private func slider(_ title: String, value: Double, in range: ClosedRange<Double>, left: String, right: String,
                        readout: String, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.onest(15, .heavy))
                Spacer()
                Text(readout).font(.mono(12, .bold)).foregroundStyle(Color.mutedDeep).monospacedDigit()
            }
            Slider(value: Binding(get: { value }, set: set), in: range)
                .tint(.accent)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(.onest(11, .semibold))
            .foregroundStyle(Color.muted)
        }
        .foregroundStyle(Color.ink)
    }

    private func roundButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.onest(18, .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.paperDeep))
        }
        .buttonRepeatBehavior(.enabled)
        .pressable(0.9)
    }

    private func toggle(_ title: String, _ detail: String, _ value: Bool, _ set: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { value }, set: set)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.onest(15, .heavy))
                Text(detail).font(.onest(12, .medium)).foregroundStyle(Color.mutedDeep)
            }
            .foregroundStyle(Color.ink)
        }
        .tint(.accent)
        .padding(.vertical, 4)
    }

    private func symbol(_ s: Sound) -> String {
        switch s {
        case .guitar: "guitars.fill"
        case .piano: "pianokeys"
        case .pad: "waveform"
        }
    }
}
