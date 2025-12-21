import SwiftUI

struct HomeView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var justTapped = false
    @State private var showingNameAlert = false
    @State private var nameInput = ""

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

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

                        // Main tap button
                        Button(action: logKick) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: justTapped ? [Theme.success, Theme.success.opacity(0.8)] : [Theme.primary, Theme.primaryDark],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 180, height: 180)

                                    VStack(spacing: 6) {
                                        Image(systemName: justTapped ? "checkmark.circle.fill" : "hand.tap.fill")
                                            .font(.system(size: 44))
                                            .foregroundColor(.white)

                                        Text(justTapped ? "Logged!" : "Tap")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .scaleEffect(justTapped ? 1.05 : 1.0)
                                .shadow(color: Theme.primary.opacity(0.3), radius: 20, x: 0, y: 10)

                                Text("Tap when baby kicks")
                                    .font(.system(size: 15))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 20)

                        // Stats
                        HStack(spacing: 12) {
                            ModernStatBox(
                                number: storage.todayKicks.count,
                                label: "Today",
                                icon: "calendar"
                            )
                            ModernStatBox(
                                number: storage.kicks.count,
                                label: "Total",
                                icon: "chart.bar.fill"
                            )
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
            }
        }
    }

    private func logKick() {
        let kick = Kick(
            timestamp: Date(),
            sessionId: storage.activeSession?.id
        )
        storage.saveKick(kick)

        // Visual feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            justTapped = true
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                justTapped = false
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
