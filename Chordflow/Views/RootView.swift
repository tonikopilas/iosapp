import SwiftUI

struct RootView: View {
    @Environment(SongStore.self) private var store
    @State private var pagerPosition: Int? = 0
    @State private var pageFraction: CGFloat = 0

    private let tabs = ["Song", "Neck", "Key", "Next"]

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            ZStack(alignment: .top) {
                Color.stage.ignoresSafeArea()
                AmbientBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    HeaderView()
                        .padding(.horizontal, 18)
                        .padding(.top, max(12, safeTop - 4))
                    tabBar
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                    pager
                        .padding(.top, 12)
                }
                .ignoresSafeArea(.container, edges: [.top, .bottom])

                if let toast = store.toast {
                    ToastView(toast: toast)
                        .padding(.top, max(20, safeTop))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(40)
                }

                VStack {
                    Spacer()
                    MiniPlayer()
                        .padding(.horizontal, 12)
                        .padding(.bottom, safeBottom > 0 ? 30 : 12)
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard)
                .zIndex(30)
            }
            .animation(.bounce, value: store.toast)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onChange(of: store.panelRequest) { _, req in
            guard let req else { return }
            withAnimation(.settle) { pagerPosition = req }
            store.panelRequest = nil
        }
    }

    private var tabBar: some View {
        GeometryReader { g in
            let w = (g.size.width - 8) / 4
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.25), radius: 7, y: 4)
                    .frame(width: w, height: 32)
                    .offset(x: 4 + pageFraction * w)
                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            store.goPanel(i)
                        } label: {
                            Text(tabs[i])
                                .font(.onest(13.5, .bold))
                                .em(-0.01, 13.5)
                                .foregroundStyle(store.panel == i ? Color.ink : .white.opacity(0.85))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .animation(.easeOut(duration: 0.25), value: store.panel)
                    }
                }
                .padding(4)
            }
        }
        .frame(height: 40)
        .glass(Capsule(), tint: .white.opacity(0.1))
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                SongPanel().containerRelativeFrame(.horizontal).id(0)
                NeckPanel().containerRelativeFrame(.horizontal).id(1)
                KeyPanel().containerRelativeFrame(.horizontal).id(2)
                NextPanel().containerRelativeFrame(.horizontal).id(3)
            }
            .scrollTargetLayout()
            .onGeometryChange(for: CGFloat.self) { proxy in
                let f = proxy.frame(in: .scrollView)
                return -f.minX / max(1, f.width / 4)
            } action: { f in
                pageFraction = min(3, max(0, f))
                let p = Int(pageFraction.rounded())
                if p != store.panel { store.panel = p }
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pagerPosition)
        .scrollDisabled(store.dragID != nil)
    }
}

struct AmbientBackground: View {
    @Environment(SongStore.self) private var store

    var body: some View {
        let pal = store.palette
        let cur = store.current, nxt = store.nextChord
        let pos = store.pos
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(pal.col(cur.root, 0.55, 0.2))
                .frame(width: 440, height: 440)
                .blur(radius: 80)
                .opacity(0.75)
                .scaleEffect(store.lit ? 1.08 : 1)
                .offset(x: -120 + CGFloat(pos % 3) * 24, y: -140 + CGFloat(pos % 2) * 30)
                .animation(.easeInOut(duration: 1.2), value: cur.root)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 2.4), value: pos)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 2.4), value: store.lit)

            GeometryReader { g in
                Circle()
                    .fill(pal.col(nxt.root, 0.5, 0.2))
                    .frame(width: 380, height: 380)
                    .blur(radius: 90)
                    .opacity(0.55)
                    .offset(x: g.size.width - 380 + 160 - CGFloat(pos % 4) * 18, y: 160 + CGFloat(pos % 3) * 22)
                    .animation(.easeInOut(duration: 1.6), value: nxt.root)
                    .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 3), value: pos)
            }

            LinearGradient(stops: [
                .init(color: Color.stage.opacity(0.15), location: 0),
                .init(color: Color.stage.opacity(0.55), location: 0.45),
                .init(color: Color.stage.opacity(0.85), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .opacity(store.playing ? 1 : 0.8)
        .animation(.easeInOut(duration: 0.6), value: store.playing)
        .allowsHitTesting(false)
    }
}

struct ToastView: View {
    @Environment(SongStore.self) private var store
    var toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(toast.dot).frame(width: 10, height: 10)
            Text(toast.text).font(.onest(13.5, .bold)).lineLimit(1)
            Button("View") { store.dismissToastAndView() }
                .font(.onest(12.5, .bold))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Color.accent, in: Capsule())
                .foregroundStyle(.white)
                .pressable()
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 44)
        .glass(Capsule(), tint: Color(hex: 0x28262E, opacity: 0.78))
        .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
    }
}
