import SwiftUI

struct SessionsView: View {
    @EnvironmentObject private var store: TallyStore
    @State private var showingNewSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            SessionStatCard(title: "Active", value: "\(store.activeSessions.count)", systemImage: "timer")
                            SessionStatCard(title: "Completed", value: "\(store.finishedSessions.count)", systemImage: "checkmark.circle")
                        }
                        .padding(.horizontal)

                        if !store.activeSessions.isEmpty {
                            SectionHeader(title: "Active Sessions", subtitle: "Timers update while this screen is open")
                            VStack(spacing: 10) {
                                ForEach(store.activeSessions) { session in
                                    ActiveSessionRow(session: session)
                                }
                            }
                            .padding(.horizontal)
                        }

                        if !store.finishedSessions.isEmpty {
                            SectionHeader(title: "Recent Sessions", subtitle: "Finished counting blocks")
                            VStack(spacing: 10) {
                                ForEach(store.finishedSessions.prefix(20)) { session in
                                    FinishedSessionRow(session: session)
                                }
                            }
                            .padding(.horizontal)
                        }

                        if store.sessions.isEmpty {
                            ContentUnavailableView("No Sessions Yet", systemImage: "timer", description: Text("Start a timed counting session to track focused counting blocks."))
                                .padding(.top, 40)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewSession = true } label: {
                        Label("Start", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NewSessionView()
            }
        }
    }

    private var background: some View {
        Group {
            if store.theme == .oled {
                Color.black.ignoresSafeArea()
            } else {
                LinearGradient(colors: [Color(.systemBackground), Color.orange.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
        }
    }
}

struct NewSessionView: View {
    @EnvironmentObject private var store: TallyStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedCounterID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Title", text: $title)
                    Picker("Counter", selection: $selectedCounterID) {
                        Text("Standalone Session").tag(UUID?.none)
                        ForEach(store.activeCounters) { counter in
                            Text(counter.name).tag(Optional(counter.id))
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section {
                    Text("A session stores the start time and the selected counter value. When you end it, Tally records duration and value change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        store.startSession(counterID: selectedCounterID, title: title, notes: notes)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ActiveSessionRow: View {
    @EnvironmentObject private var store: TallyStore
    let session: TallySession
    @State private var showingCancelConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            HStack(spacing: 12) {
                Circle()
                    .fill(.orange.opacity(0.18))
                    .overlay(Image(systemName: "timer").foregroundStyle(.orange))
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.headline)
                    Text("\(session.counterName) • started \(session.startedAt, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(context.date.timeIntervalSince(session.startedAt)))
                        .font(.title3.weight(.heavy).monospacedDigit())
                }

                Spacer()

                Menu {
                    Button("End Session") { store.endSession(session) }
                    Button("Cancel Session", role: .destructive) { showingCancelConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .confirmationDialog("Cancel session?", isPresented: $showingCancelConfirmation) {
            Button("Cancel Session", role: .destructive) { store.cancelSession(session) }
        } message: {
            Text("Canceling removes this active session without saving a summary.")
        }
    }
}

struct FinishedSessionRow: View {
    @EnvironmentObject private var store: TallyStore
    let session: TallySession
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.blue.opacity(0.16))
                .overlay(Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue))
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.headline)
                Text("\(session.counterName) • \(session.startedAt, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(formatDuration(session.duration))
                    if let delta = session.delta {
                        Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                    }
                }
                .font(.subheadline.weight(.bold).monospacedDigit())
            }

            Spacer()

            Menu {
                Button("Delete Session", role: .destructive) { showingDeleteConfirmation = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .confirmationDialog("Delete session?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Session", role: .destructive) { store.deleteSession(session) }
        }
    }
}

struct SessionStatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private func formatDuration(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remaining = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remaining)
    }
    return String(format: "%02d:%02d", minutes, remaining)
}
