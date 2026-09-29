import SwiftUI

struct HeaderView: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "NOW WRITING", tracking: 0.14, color: .white.opacity(0.6))
                TextField("", text: $store.title)
                    .font(.onest(32, .black))
                    .em(-0.035, 32)
                    .foregroundStyle(.white)
                    .tint(.accent)
                    .submitLabel(.done)
            }

            HStack(spacing: 8) {
                Button { store.goPanel(2) } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(store.palette.col(store.key))
                            .frame(width: 9, height: 9)
                            .animation(.easeInOut(duration: 0.6), value: store.key)
                        Text(store.keyName).font(.onest(13, .bold))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .glass(Capsule())
                }
                .pressable()

                HStack(spacing: 2) {
                    stepButton("−", action: store.bpmDown)
                    (Text("\(store.bpm) ") + Text("BPM").font(.onest(13, .medium)).foregroundColor(.white.opacity(0.6)))
                        .font(.onest(13, .bold))
                        .monospacedDigit()
                        .frame(minWidth: 62)
                    stepButton("+", action: store.bpmUp)
                }
                .padding(.horizontal, 4)
                .frame(height: 34)
                .glass(Capsule())

                Button { store.click.toggle() } label: {
                    Text("Click")
                        .font(.onest(12, .bold))
                        .foregroundStyle(store.click ? Color.ink : .white)
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.white.opacity(store.click ? 0.92 : 0.14)))
                        .animation(.easeOut(duration: 0.25), value: store.click)
                }
                .pressable()
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.onest(16, .bold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .pressable(0.88)
    }
}
