import SwiftUI

struct SessionsView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var showingMealTimePicker = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea(edges: .bottom)

                ScrollView {
                    VStack(spacing: 24) {
                        // Info header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Track kicks for 2 hours after meals when baby is most active.")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        if let session = storage.activeSession {
                            // Active session view
                            VStack(spacing: 20) {
                                // Session header
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Active Session")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)

                                        Text("Started at \(session.mealTime, style: .time)")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.textSecondary)
                                    }

                                    Spacer()

                                    // Status badge
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Theme.success)
                                            .frame(width: 8, height: 8)

                                        Text("Tracking")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Theme.success)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.successLight)
                                    .cornerRadius(20)
                                }
                                .padding(20)
                                .cardStyle()

                                // Progress circle
                                ZStack {
                                    // Background circle
                                    Circle()
                                        .stroke(Theme.primaryLight, lineWidth: 12)
                                        .frame(width: 160, height: 160)

                                    // Progress circle
                                    Circle()
                                        .trim(from: 0, to: progress(for: session))
                                        .stroke(
                                            LinearGradient(
                                                colors: [Theme.primary, Theme.secondary],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                        )
                                        .frame(width: 160, height: 160)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut, value: progress(for: session))

                                    // Center content
                                    VStack(spacing: 8) {
                                        Text("\(session.kicks.count)")
                                            .font(.system(size: 48, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)

                                        Text("kicks")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding(.vertical, 20)

                                // Time remaining
                                VStack(spacing: 8) {
                                    HStack(spacing: 16) {
                                        VStack(spacing: 4) {
                                            Text(timeRemaining(for: session))
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text("Remaining")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Theme.cardBackground)
                                        .cornerRadius(12)

                                        VStack(spacing: 4) {
                                            Text(session.endTime, style: .time)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text("Ends at")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Theme.cardBackground)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(20)
                                .background(Theme.primaryLight.opacity(0.3))
                                .cornerRadius(16)

                                // Tip
                                HStack(spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(Theme.secondary)

                                    Text("Log kicks from the Home tab during this session")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.secondaryLight)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)

                        } else {
                            // No session - Start button
                            VStack(spacing: 24) {
                                // Empty state illustration
                                ZStack {
                                    Circle()
                                        .fill(Theme.primaryLight.opacity(0.3))
                                        .frame(width: 120, height: 120)

                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(Theme.primary)
                                }
                                .padding(.top, 20)

                                VStack(spacing: 12) {
                                    Text("No Active Session")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)

                                    Text("Start tracking kicks after your next meal")
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }

                                // Start button
                                Button(action: { showingMealTimePicker = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 16))

                                        Text("Start 2-Hour Session")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Theme.primary, Theme.primaryDark],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: Theme.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 40)
                        }

                        // Info section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About Meal Sessions")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            VStack(spacing: 12) {
                                InfoRow(
                                    icon: "fork.knife",
                                    text: "Baby is most active 1-2 hours after you eat due to increased blood sugar"
                                )

                                InfoRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    text: "Track patterns and share session data with your healthcare provider"
                                )

                                InfoRow(
                                    icon: "bell.fill",
                                    text: "All kicks logged during the session will be automatically tracked"
                                )
                            }
                        }
                        .padding(20)
                        .cardStyle()
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .alert("Start Session", isPresented: $showingMealTimePicker) {
                Button("Just finished eating") {
                    _ = storage.startSession(mealTime: Date())
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("When did you finish your meal?")
            }
        }
    }

    private func progress(for session: MealSession) -> CGFloat {
        let total = session.endTime.timeIntervalSince(session.startTime)
        let elapsed = Date().timeIntervalSince(session.startTime)
        return min(CGFloat(elapsed / total), 1.0)
    }

    private func timeRemaining(for session: MealSession) -> String {
        let diff = session.endTime.timeIntervalSinceNow
        if diff <= 0 {
            return "Ended"
        }
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.primary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}
