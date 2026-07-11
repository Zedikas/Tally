import SwiftUI
import UniformTypeIdentifiers

struct TallyMainTabsView: View {
    private enum Tab: Hashable {
        case counters
        case sessions
        case stats
        case history
        case settings
    }

    @EnvironmentObject private var store: TallyStore
    @AppStorage(StoredAccentColor.presetKey) private var accentColorRaw = TallyAccentColor.blue.rawValue
    @AppStorage(StoredAccentColor.customKey) private var customAccentHex = "FF1883"

    @State private var selectedTab: Tab = .counters
    @State private var showingOnboarding = false

    private var hasFiledCounters: Bool {
        store.activeCounters.contains { counter in
            if let folderID = counter.folderID, store.folder(id: folderID) != nil {
                return true
            }
            return store.folder(named: counter.group) != nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CountersView()
                .safeAreaInset(edge: .bottom, spacing: 6) {
                    if hasFiledCounters {
                        UnfiledDropDock()
                            .padding(.horizontal, 14)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .tag(Tab.counters)
                .tabItem {
                    Label("Counters", systemImage: "number.circle.fill")
                }

            SessionsView()
                .tag(Tab.sessions)
                .tabItem {
                    Label("Sessions", systemImage: "timer")
                }

            StatsView()
                .tag(Tab.stats)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.xaxis")
                }

            HistoryView()
                .tag(Tab.history)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tag(Tab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(StoredAccentColor.resolve(accentColorRaw, customHex: customAccentHex))
        .background {
            if store.theme == .oled {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            store.ensureFoldersMigrated()
            store.performScheduledResets()
            store.rescheduleAllResetNotifications()
            if !store.preferences.onboardingCompleted {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            TallyOnboardingView()
                .environmentObject(store)
        }
        .animation(
            store.preferences.reducedAnimations
                ? nil
                : .interactiveSpring(response: 0.28, dampingFraction: 0.84),
            value: hasFiledCounters
        )
    }
}

private struct UnfiledDropDock: View {
    @EnvironmentObject private var store: TallyStore
    @State private var isTargeted = false

    private var animation: Animation? {
        store.preferences.reducedAnimations
            ? nil
            : .interactiveSpring(response: 0.24, dampingFraction: 0.8)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.headline.weight(.bold))

            VStack(alignment: .leading, spacing: 1) {
                Text(isTargeted ? "Release to move to Unfiled" : "Unfiled")
                    .font(.subheadline.weight(.bold))
                Text(isTargeted ? "The counter will leave its folder" : "Drag a counter here to remove it from its folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.down.to.line.compact")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(isTargeted ? Color.accentColor : Color.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, isTargeted ? 15 : 11)
        .frame(maxWidth: .infinity)
        .background(
            isTargeted ? Color.accentColor.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isTargeted ? Color.accentColor.opacity(0.9) : Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [7, 5] : [])
                )
        }
        .scaleEffect(isTargeted && !store.preferences.reducedAnimations ? 1.025 : 1)
        .shadow(
            color: isTargeted ? Color.accentColor.opacity(0.22) : Color.black.opacity(0.08),
            radius: isTargeted ? 14 : 6,
            y: isTargeted ? 6 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onDrop(
            of: [UTType.plainText.identifier, UTType.text.identifier],
            delegate: UnfiledDockDropDelegate(
                store: store,
                isTargeted: $isTargeted,
                animation: animation
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Move counter to Unfiled")
        .accessibilityHint("Drag a counter from a folder and release it here")
        .animation(animation, value: isTargeted)
    }
}

private struct UnfiledDockDropDelegate: DropDelegate {
    let store: TallyStore
    @Binding var isTargeted: Bool
    let animation: Animation?

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [.plainText, .text]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        guard !isTargeted else { return }
        withAnimation(animation) {
            isTargeted = true
        }
        store.performHaptic(.selection)
    }

    func dropExited(info: DropInfo) {
        withAnimation(animation) {
            isTargeted = false
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.plainText, .text]).first else {
            withAnimation(animation) {
                isTargeted = false
            }
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let payload = object as? NSString else {
                Task { @MainActor in
                    withAnimation(animation) {
                        isTargeted = false
                    }
                }
                return
            }

            Task { @MainActor in
                defer {
                    withAnimation(animation) {
                        isTargeted = false
                    }
                }

                let value = payload as String
                guard value.hasPrefix("counter:"),
                      let id = UUID(uuidString: String(value.dropFirst("counter:".count))),
                      let counter = store.counters.first(where: { $0.id == id }) else {
                    return
                }

                let alreadyUnfiled = counter.folderID == nil && store.folder(named: counter.group) == nil
                guard !alreadyUnfiled else { return }

                withAnimation(animation) {
                    store.moveCounter(counter, to: nil)
                }
                store.performHaptic(.success)
            }
        }

        return true
    }
}
