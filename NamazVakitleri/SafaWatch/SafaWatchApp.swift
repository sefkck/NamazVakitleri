import SwiftUI

@main
struct SafaWatchApp: App {
    init() {
        WatchStore.shared.activate()
        #if DEBUG
        // Simülatör testi: -watchDemo YES → İstanbul konumu (iPhone eşli değilken).
        if UserDefaults.standard.bool(forKey: "watchDemo") {
            WatchStore.apply(["lat": 41.0082, "lon": 28.9784, "tz": "Europe/Istanbul", "city": "İstanbul Fatih"])
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
