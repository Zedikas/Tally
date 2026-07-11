import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentColorRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customAccentHex = "FF1883"
    @State private var showingOnboarding = false

    var body: some Scene {
        fatalError("RootView is a View, not a Scene")
    }
}
