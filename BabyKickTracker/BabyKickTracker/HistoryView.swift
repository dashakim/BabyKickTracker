import SwiftUI

struct HistoryView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var viewMode: ViewMode = .allKicks

    enum ViewMode: Hashable {
        case allKicks, sessions
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toggle
                Picker("View Mode", selection: $viewMode) {
                    Text("All Kicks").tag(ViewMode.allKicks)
                    Text("Sessions").tag(ViewMode.sessions)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if viewMode == .allKicks {
                    allKicksView
                } else {
                    sessionsView
                }
            }
            .navigationTitle("Kick History")
        }
    }

    private var allKicksView: some View {
        ScrollView {
            if storage.kicks.isEmpty {
                emptyView(message: "No kicks recorded yet")
            } else {
                LazyVStack(spacing: 15) {
                    ForEach(groupedKicks, id: \.key) { entry in
                        DaySection(date: entry.key, kicks: entry.value)
                    }
                }
                .padding()
            }
        }
    }

    private var sessionsView: some View {
        ScrollView {
            if storage.sessions.isEmpty {
                emptyView(message: "No meal sessions recorded yet")
            } else {
                LazyVStack(spacing: 15) {
                    ForEach(Array(storage.sessions.reversed()), id: \.id) { session in
                        SessionCard(session: session)
                    }
                }
                .padding()
            }
        }
    }

    private func emptyView(message: String) -> some View {
        VStack(alignment: .center) {
            Text(message)
                .foregroundColor(.gray)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.vertical, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var groupedKicks: [(key: Date, value: [Kick])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: storage.kicks) { kick in
            calendar.startOfDay(for: kick.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

struct DaySection: View {
    let date: Date
    let kicks: [Kick]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date, format: Date.FormatStyle.dateTime.weekday(.wide).month(.abbreviated).day().year())
                    .font(.headline)
                Spacer()
                Text("\(kicks.count) kicks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
            }

            ForEach(kicks.sorted(by: { $0.timestamp > $1.timestamp })) { kick in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 8, height: 8)

                    Text(kick.timestamp, style: .time)
                        .font(.body)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}

struct SessionCard: View {
    let session: MealSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meal Session")
                    .font(.headline)
                Spacer()
                if session.isActive {
                    Text("ACTIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .cornerRadius(5)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Started: \(session.mealTime, format: Date.FormatStyle.dateTime.month(.abbreviated).day().year().hour().minute())")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Ends: \(session.endTime, format: Date.FormatStyle.dateTime.hour().minute())")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Stats
            HStack {
                VStack(spacing: 4) {
                    Text("\(session.kicks.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text("Kicks")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }

            // Kicks list
            if !session.kicks.isEmpty {
                Divider()

                Text("Kicks in this session:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)

                ForEach(session.kicks) { kick in
                    HStack {
                        Text("•")
                        Text(kick.timestamp, style: .time)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
