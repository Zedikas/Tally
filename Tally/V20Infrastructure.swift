import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct TallyEditorCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct StepPresetEditor: View {
    @Binding var steps: [Int]

    private var normalized: [Int] {
        var result = TallyCounter.sanitizedStepValues(steps)
        while result.count < 3 {
            result.append([1, 5, 10][result.count])
        }
        return Array(result.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step Buttons").font(.subheadline.weight(.semibold))
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    TextField("Step \(index + 1)", value: valueBinding(index), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func valueBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { normalized[index] },
            set: { value in
                var copy = normalized
                copy[index] = min(max(value, 1), 9999)
                steps = TallyCounter.sanitizedStepValues(copy)
            }
        )
    }
}

enum TallyHapticKind {
    case selection, light, success, warning
}

extension TallyStore {
    func performHaptic(_ kind: TallyHapticKind) {
        guard preferences.hapticsEnabled else { return }
        #if canImport(UIKit)
        switch kind {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif
    }

    func requestResetNotificationAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func cancelResetNotification(for counterID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [resetNotificationIdentifier(counterID)])
    }

    func rescheduleAllResetNotifications() {
        for counter in counters where !counter.isArchived {
            scheduleResetNotification(for: counter)
        }
    }

    func scheduleResetNotification(for counter: TallyCounter) {
        let center = UNUserNotificationCenter.current()
        let identifier = resetNotificationIdentifier(counter.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard counter.resetNotificationEnabled,
              counter.resetReminder != .none,
              !counter.isArchived else { return }

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            if settings.authorizationStatus == .notDetermined {
                Task { @MainActor in
                    if await self.requestResetNotificationAuthorization() {
                        self.scheduleResetNotification(for: counter)
                    }
                }
                return
            }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming reset"
            content.body = "\(counter.name) resets in five minutes."
            content.sound = .default
            content.userInfo = ["counterID": counter.id.uuidString]

            let components = self.notificationDateComponents(for: counter)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    func nextResetDate(for counter: TallyCounter, after date: Date = Date()) -> Date? {
        guard counter.resetReminder != .none else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = counter.resetHour
        components.minute = counter.resetMinute
        components.second = 0

        switch counter.resetReminder {
        case .none:
            return nil
        case .daily:
            let today = calendar.date(from: components) ?? date
            return today > date ? today : calendar.date(byAdding: .day, value: 1, to: today)
        case .weekly:
            return calendar.nextDate(
                after: date,
                matching: DateComponents(weekday: counter.resetWeekday, hour: counter.resetHour, minute: counter.resetMinute),
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        case .monthly:
            return calendar.nextDate(
                after: date,
                matching: DateComponents(day: counter.resetDayOfMonth, hour: counter.resetHour, minute: counter.resetMinute),
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }
    }

    func resetScheduleDescription(for counter: TallyCounter) -> String {
        guard let next = nextResetDate(for: counter) else { return "No scheduled reset" }
        return "Next reset \(next.formatted(date: .abbreviated, time: .shortened))"
    }

    private func notificationDateComponents(for counter: TallyCounter) -> DateComponents {
        let calendar = Calendar.current
        let nextReset = nextResetDate(for: counter) ?? Date()
        let warningDate = calendar.date(byAdding: .minute, value: -5, to: nextReset) ?? nextReset
        switch counter.resetReminder {
        case .none:
            return DateComponents()
        case .daily:
            return calendar.dateComponents([.hour, .minute], from: warningDate)
        case .weekly:
            return calendar.dateComponents([.weekday, .hour, .minute], from: warningDate)
        case .monthly:
            return calendar.dateComponents([.day, .hour, .minute], from: warningDate)
        }
    }

    private func resetNotificationIdentifier(_ counterID: UUID) -> String {
        "tally.reset.\(counterID.uuidString)"
    }
}

struct TallySigningCapability: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let availableInAppDBBuild: Bool

    static let all: [TallySigningCapability] = [
        .init(id: "local", title: "Local counters, sessions, notifications and backups", subtitle: "Fully available in the AppDB-safe build.", systemImage: "iphone", availableInAppDBBuild: true),
        .init(id: "shortcuts", title: "App Shortcuts", subtitle: "Implemented in the main app without an extension target.", systemImage: "command", availableInAppDBBuild: true),
        .init(id: "widgets", title: "Widgets and Live Activities", subtitle: "Source-ready, but requires a separately signed extension target.", systemImage: "rectangle.3.group", availableInAppDBBuild: false),
        .init(id: "cloud", title: "Automatic CloudKit sync", subtitle: "Source-ready, but requires iCloud entitlements in the provisioning profile.", systemImage: "icloud", availableInAppDBBuild: false)
    ]
}
