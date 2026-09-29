import SwiftUI

@main
struct ChordflowApp: App {
    @State private var store = SongStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
