import SwiftUI

@main
struct ChordflowApp: App {
    @State private var store = SongStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveIfNeeded() }
        }
    }
}
