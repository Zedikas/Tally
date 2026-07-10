import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: TallyStore

    var body: some View {
        NavigationStack {
            List {
                if store.history.isEmpty {
                    ContentUnavailableView("No History Yet", systemImage: "clock", description: Text("Counter changes will appear here."))
                } else {
                    Section {
                        ForEach(store.history) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) { store.clearHistory() }
                        .disabled(store.history.isEmpty)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: TallyHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.counterName)
                    .font(.headline)
                Spacer()
                Text(entry.action)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(entry.delta >= 0 ? .green : .red)
            }
            HStack {
                Text("\(entry.beforeValue) → \(entry.afterValue)")
                Spacer()
                Text(entry.date, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
