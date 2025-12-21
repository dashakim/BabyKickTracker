import SwiftUI

struct HistoryView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var viewMode: ViewMode = .allKicks

    enum ViewMode: String, CaseIterable {
        case allKicks = "All Kicks"
        case sessions = "Sessions"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented control
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)

                    // Content
                    ScrollView {
                        if viewMode == .allKicks {
                            allKicksView
                        } else {
                            sessionsView
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var allKicksView: some View {
        VStack(spacing: 16) {
            if storage.kicks.isEmpty {
                emptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Kicks Yet",
                    message: "Start logging kicks from the Home tab"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(groupedKicks.enumerated()), id: \.offset) { _, item in
                        ModernDaySection(date: item.key, kicks: item.value)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
    }

    private var sessionsView: some View {
        VStack(spacing: 16) {
            if storage.sessions.isEmpty {
                emptyStateView(
                    icon: "clock.badge.checkmark",
                    title: "No Sessions Yet",
                    message: "Start a 2-hour session from the Sessions tab"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(storage.sessions.reversed()) { session in
                        ModernSessionCard(session: session)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.primaryLight.opacity(0.3))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 42))
                    .foregroundColor(Theme.primary)
            }
            .padding(.top, 60)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var groupedKicks: [(key: Date, value: [Kick])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: storage.kicks) { kick in
            calendar.startOfDay(for: kick.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

struct ModernDaySection: View {
    let date: Date
    let kicks: [Kick]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text(date.formatted(.dateTime.year()))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // Count badge
                Text("\(kicks.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.primaryLight)
                    .cornerRadius(8)
            }

            // Kicks list
            VStack(spacing: 0) {
                ForEach(Array(kicks.sorted(by: { $0.timestamp > $1.timestamp }).enumerated()), id: \.element.id) { index, kick in
                    HStack(spacing: 12) {
                        // Dot
                        ZStack {
                            Circle()
                                .fill(Theme.primaryLight.opacity(0.5))
                                .frame(width: 24, height: 24)

                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 8, height: 8)
                        }

                        // Time
                        Text(kick.timestamp, style: .time)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        // Session indicator
                        if kick.sessionId != nil {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.secondary)
                        }
                    }
                    .padding(.vertical, 12)

                    if index < kicks.count - 1 {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

struct ModernSessionCard: View {
    let session: MealSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text(session.mealTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if session.isActive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 6, height: 6)

                        Text("Active")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.success)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.successLight)
                    .cornerRadius(12)
                }
            }

            // Stats
            HStack(spacing: 12) {
                // Kicks count
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.primary)

                        Text("Kicks")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text("\(session.kicks.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.primaryLight.opacity(0.3))
                .cornerRadius(10)

                // Duration
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.secondary)

                        Text("Duration")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text("2 hours")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.secondaryLight.opacity(0.5))
                .cornerRadius(10)
            }

            // Kicks timeline (if any)
            if !session.kicks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Timeline")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)

                    FlowLayout(spacing: 8) {
                        ForEach(session.kicks) { kick in
                            Text(kick.timestamp, style: .time)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.primaryLight.opacity(0.5))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

// Flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
