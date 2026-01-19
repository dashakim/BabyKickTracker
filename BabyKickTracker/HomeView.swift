import SwiftUI

struct HomeView: View {
    @StateObject private var storage = KickStorage.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var justTapped = false
    @State private var showingNameAlert = false
    @State private var nameInput = ""
    @State private var showFeedback = false
    @State private var rippleScale: CGFloat = 0
    @State private var showingStatistics = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea(edges: .bottom)

                ScrollView {
                    VStack(spacing: 24) {
                        // Baby name greeting
                        HStack {
                            if !storage.babyName.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tracking kicks for")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.textSecondary)
                                    Text(storage.babyName)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Theme.primary)
                                }
                            } else {
                                Text("Tap to set baby's name")
                                    .font(.system(size: 15))
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Spacer()

                            Button(action: { showingNameAlert = true }) {
                                Image(systemName: storage.babyName.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Active session banner
                        if let session = storage.activeSession {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.success)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active Session")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("\(session.kicks.count) kicks · Ends \(session.endTime, style: .time)")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(Theme.successLight)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.success.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        }

                        // Main tap button - redesigned for emotional comfort
                        Button(action: logKick) {
                            VStack(spacing: 16) {
                                ZStack {
                                    // Ripple effect on tap
                                    if justTapped {
                                        Circle()
                                            .stroke(Theme.primary.opacity(0.3), lineWidth: 2)
                                            .frame(width: 150, height: 150)
                                            .scaleEffect(rippleScale)
                                            .opacity(2 - rippleScale)
                                    }

                                    // Main circle with subtle gradient and inner glow
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Theme.primary.opacity(0.95),
                                                    Theme.primary
                                                ],
                                                center: .center,
                                                startRadius: 20,
                                                endRadius: 75
                                            )
                                        )
                                        .frame(width: 150, height: 150)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                .blur(radius: 3)
                                                .offset(x: 0, y: 1)
                                        )

                                    // Icon - pregnant person
                                    Image("footprints")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.white.opacity(0.95))
                                        .frame(width: 60, height: 60)
                                }
                                .scaleEffect(justTapped ? 0.92 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: justTapped)
                                .shadow(color: Theme.primary.opacity(0.15), radius: 12, x: 0, y: 6)

                                // Human, emotional text
                                Text("I felt a kick")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)

                                // Feedback text that fades in/out
                                if showFeedback {
                                    Text("Kick recorded 💗")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.success)
                                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 30)

                        // Stats
                        HStack(spacing: 12) {
                            ModernStatBox(
                                number: storage.todayKicks.count,
                                label: "Today",
                                icon: "calendar"
                            )
                            Button(action: { showingStatistics = true }) {
                                ModernStatBox(
                                    number: storage.kicks.count,
                                    label: "Total",
                                    icon: "chart.bar.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)

                        // Recent kicks
                        if !storage.kicks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Activity")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 8) {
                                    ForEach(Array(storage.kicks.suffix(5).reversed())) { kick in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Theme.primaryLight)
                                                .frame(width: 8, height: 8)

                                            Text(kick.timestamp, style: .time)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Theme.textPrimary)

                                            Spacer()

                                            Text(kick.timestamp, style: .date)
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                                .cardStyle()
                                .padding(.horizontal, 20)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "heart.text.square")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.textTertiary)

                                Text("No kicks logged yet")
                                    .font(.system(size: 15))
                                    .foregroundColor(Theme.textSecondary)

                                Text("Tap the button above when you feel a kick")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Kick Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    syncStatusView
                }
            }
            .alert("Baby's Name", isPresented: $showingNameAlert) {
                TextField("Enter name", text: $nameInput)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    if !nameInput.isEmpty {
                        storage.saveBabyName(nameInput)
                    }
                }
                Button("Cancel", role: .cancel) {
                    nameInput = storage.babyName
                }
            } message: {
                Text("What would you like to call your baby?")
            }
            .onAppear {
                nameInput = storage.babyName
                storage.loadData() // Reload data when view appears
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Reload data when app comes to foreground
                storage.loadData()
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView()
            }
        }
    }

    private func logKick() {
        let kick = Kick(
            timestamp: Date(),
            sessionId: storage.activeSession?.id
        )
        storage.saveKick(kick)

        // Gentle haptic - light and subtle, not jarring
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Breathing animation - scale in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
            justTapped = true
        }

        // Ripple effect
        withAnimation(.easeOut(duration: 1.2)) {
            rippleScale = 2.0
        }

        // Show feedback text
        withAnimation(.easeIn(duration: 0.2)) {
            showFeedback = true
        }

        // Reset everything gently
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                justTapped = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showFeedback = false
            }
            rippleScale = 0
        }
    }

    // Sync status indicator
    private var syncStatusView: some View {
        HStack(spacing: 4) {
            switch cloudKitManager.syncState {
            case .idle:
                if cloudKitManager.isOnline {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(Theme.success)
                        .font(.system(size: 16))
                }
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
            case .error(let message):
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundColor(Theme.primaryDark)
                    .font(.system(size: 16))
            }
        }
    }
}

struct ModernStatBox: View {
    let number: Int
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.primary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(number)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

// MARK: - Statistics View
struct StatisticsView: View {
    @StateObject private var storage = KickStorage.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Overview Stats
                        VStack(spacing: 12) {
                            StatCard(
                                title: "Total Kicks",
                                value: "\(storage.kicks.count)",
                                icon: "heart.fill",
                                color: Theme.primary
                            )

                            StatCard(
                                title: "Average Per Day",
                                value: String(format: "%.1f", averageKicksPerDay),
                                icon: "chart.line.uptrend.xyaxis",
                                color: Theme.secondary
                            )

                            StatCard(
                                title: "Most Active Day",
                                value: mostActiveDay,
                                icon: "star.fill",
                                color: Theme.accent
                            )

                            StatCard(
                                title: "Days Tracking",
                                value: "\(totalDaysTracking)",
                                icon: "calendar",
                                color: Theme.success
                            )
                        }
                        .padding(.horizontal, 20)

                        // Recent 7 Days Breakdown
                        if !storage.kicks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Last 7 Days")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 8) {
                                    ForEach(last7DaysData, id: \.date) { item in
                                        HStack {
                                            Text(item.date, style: .date)
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.textSecondary)
                                                .frame(width: 100, alignment: .leading)

                                            // Bar visualization
                                            GeometryReader { geometry in
                                                HStack(spacing: 4) {
                                                    Rectangle()
                                                        .fill(Theme.primary)
                                                        .frame(width: barWidth(for: item.count, maxWidth: geometry.size.width - 60))
                                                        .cornerRadius(4)

                                                    Text("\(item.count)")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(Theme.textPrimary)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                }
                                .cardStyle()
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var averageKicksPerDay: Double {
        guard totalDaysTracking > 0 else { return 0 }
        return Double(storage.kicks.count) / Double(totalDaysTracking)
    }

    private var totalDaysTracking: Int {
        guard !storage.kicks.isEmpty else { return 0 }
        let dates = Set(storage.kicks.map { Calendar.current.startOfDay(for: $0.timestamp) })
        return dates.count
    }

    private var mostActiveDay: String {
        guard !storage.kicks.isEmpty else { return "N/A" }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: storage.kicks) { kick in
            calendar.startOfDay(for: kick.timestamp)
        }

        if let maxDay = grouped.max(by: { $0.value.count < $1.value.count }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: maxDay.key)
        }

        return "N/A"
    }

    private var last7DaysData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var result: [(date: Date, count: Int)] = []

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let count = storage.kicks.filter { kick in
                    calendar.startOfDay(for: kick.timestamp) == date
                }.count
                result.append((date: date, count: count))
            }
        }

        return result.reversed()
    }

    private func barWidth(for count: Int, maxWidth: CGFloat) -> CGFloat {
        guard let maxCount = last7DaysData.max(by: { $0.count < $1.count })?.count, maxCount > 0 else {
            return 0
        }
        return CGFloat(count) / CGFloat(maxCount) * maxWidth
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)

                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()
        }
        .padding(16)
        .cardStyle()
    }
}
