import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct TallyWidgetBundle: WidgetBundle {
    var body: some Widget {
        TallyCounterWidget()
        TallyPinnedCountersWidget()
        TallySessionLiveActivity()
        if #available(iOSApplicationExtension 18.0, *) {
            TallyQuickIncrementControl()
        }
    }
}

struct TallyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TallyWidgetSnapshot
}

struct TallyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TallyWidgetEntry {
        TallyWidgetEntry(
            date: Date(),
            snapshot: .init(
                generatedAt: Date(),
                counters: [
                    .init(
                        id: UUID(),
                        name: "Demo",
                        value: 12,
                        goal: 20,
                        symbol: "number.square.fill",
                        colorRaw: "blue",
                        folderName: "Favorites",
                        isPinned: true
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TallyWidgetEntry) -> Void) {
        completion(TallyWidgetEntry(date: Date(), snapshot: TallySharedContainer.readWidgetSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TallyWidgetEntry>) -> Void) {
        let entry = TallyWidgetEntry(date: Date(), snapshot: TallySharedContainer.readWidgetSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct TallyCounterWidget: Widget {
    let kind = "TallyCounterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TallyWidgetProvider()) { entry in
            TallyCounterWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tally Counter")
        .description("See and adjust your first pinned counter.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct TallyCounterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TallyWidgetEntry

    private var counter: TallyWidgetCounterSnapshot? {
        entry.snapshot.counters.first(where: \.isPinned) ?? entry.snapshot.counters.first
    }

    var body: some View {
        if let counter {
            switch family {
            case .accessoryCircular:
                Gauge(
                    value: Double(counter.value),
                    in: 0...Double(max(counter.goal ?? max(counter.value, 1), 1))
                ) {
                    Image(systemName: counter.symbol)
                } currentValueLabel: {
                    Text("\(counter.value)").monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)

            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label(counter.name, systemImage: counter.symbol).font(.headline)
                    Text("\(counter.value)").font(.title2.bold()).monospacedDigit()
                    Text(counter.folderName).font(.caption2).foregroundStyle(.secondary)
                }

            default:
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Image(systemName: counter.symbol).font(.title2)
                        Spacer()
                        if counter.isPinned { Image(systemName: "pin.fill").font(.caption) }
                    }
                    Text(counter.name).font(.headline).lineLimit(1)
                    Text("\(counter.value)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                    if let goal = counter.goal, goal > 0 {
                        ProgressView(value: min(max(Double(counter.value) / Double(goal), 0), 1))
                    }
                    HStack(spacing: 8) {
                        Button(intent: TallyExtensionIncrementIntent(counterID: counter.id.uuidString, amount: 1)) {
                            Label("+1", systemImage: "plus").labelStyle(.titleOnly)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(intent: TallyExtensionIncrementIntent(counterID: counter.id.uuidString, amount: 5)) {
                            Label("+5", systemImage: "plus").labelStyle(.titleOnly)
                        }
                        .buttonStyle(.bordered)
                    }
                    Text(counter.folderName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } else {
            ContentUnavailableView("No Counters", systemImage: "number.square")
        }
    }
}

struct TallyPinnedCountersWidget: Widget {
    let kind = "TallyPinnedCountersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TallyWidgetProvider()) { entry in
            TallyPinnedCountersWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pinned Tally Counters")
        .description("See and adjust several pinned counters.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TallyPinnedCountersWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TallyWidgetEntry

    private var counters: [TallyWidgetCounterSnapshot] {
        let pinned = entry.snapshot.counters.filter(\.isPinned)
        let source = pinned.isEmpty ? entry.snapshot.counters : pinned
        return Array(source.prefix(family == .systemLarge ? 8 : 4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tally", systemImage: "number.circle.fill").font(.headline)
            if counters.isEmpty {
                Text("Pin a counter to show it here.").foregroundStyle(.secondary)
            } else {
                ForEach(counters) { counter in
                    HStack(spacing: 10) {
                        Image(systemName: counter.symbol).frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(counter.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(counter.folderName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text("\(counter.value)").font(.title3.bold()).monospacedDigit()
                        Button(intent: TallyExtensionIncrementIntent(counterID: counter.id.uuidString, amount: 1)) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase \(counter.name) by one")
                    }
                }
            }
            Spacer(minLength: 0)
            Text("Updated \(entry.snapshot.generatedAt, style: .relative)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct TallySessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TallySessionActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        context.attributes.title,
                        systemImage: context.state.isPaused ? "pause.circle.fill" : "timer.circle.fill"
                    )
                    .font(.headline)
                    Spacer()
                    Text(durationText(context.state.elapsedSeconds)).monospacedDigit().font(.title3.bold())
                }
                Text(context.attributes.counterName).font(.caption).foregroundStyle(.secondary)
                if let progress = context.state.progress {
                    ProgressView(value: progress)
                }
                if let value = context.state.counterValue {
                    Text("Counter: \(value)").font(.caption.weight(.semibold))
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.82))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(durationText(context.state.elapsedSeconds)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.counterName).foregroundStyle(.secondary)
                        Spacer()
                        if let value = context.state.counterValue { Text("\(value)").bold() }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            } compactTrailing: {
                Text(durationText(context.state.elapsedSeconds)).monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            }
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
struct TallyQuickIncrementControl: ControlWidget {
    static let kind = "TallyQuickIncrementControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TallyExtensionIncrementIntent(counterID: "", amount: 1)) {
                Label("Increment Tally", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Increment Tally")
        .description("Increase the first pinned Tally counter by one.")
    }
}

private func durationText(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    let hours = safe / 3600
    let minutes = (safe % 3600) / 60
    let remainder = safe % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
        : String(format: "%02d:%02d", minutes, remainder)
}
