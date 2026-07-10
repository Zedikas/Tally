import SwiftUI

@main
struct TallyApp: App {
    @StateObject private var store = TallyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.theme.colorScheme)
        }
    }
}
