import SwiftUI

@main
struct TallyApp: App {
    @StateObject private var store = TallyStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.theme.colorScheme)
                .onAppear {
                    store.performScheduledResets()
                    store.rescheduleAllResetNotifications()
                    #if TALLY_FULL_SIGNING
                    TallyFullSigningBridge.shared.publishWidgetSnapshot(from: store)
                    Task { await TallyFullSigningBridge.shared.updateLiveActivities(from: store) }
                    #endif
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    store.performScheduledResets()
                    store.rescheduleAllResetNotifications()
                    #if TALLY_FULL_SIGNING
                    TallyFullSigningBridge.shared.publishWidgetSnapshot(from: store)
                    Task { await TallyFullSigningBridge.shared.updateLiveActivities(from: store) }
                    #endif
                }
                .onChange(of: store.counters) { _, _ in
                    #if TALLY_FULL_SIGNING
                    TallyFullSigningBridge.shared.publishWidgetSnapshot(from: store)
                    #endif
                }
                .onChange(of: store.sessions) { _, _ in
                    #if TALLY_FULL_SIGNING
                    Task { await TallyFullSigningBridge.shared.updateLiveActivities(from: store) }
                    #endif
                }
        }
    }
}
