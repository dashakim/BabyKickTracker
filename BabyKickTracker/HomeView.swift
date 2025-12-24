import SwiftUI

struct HomeView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var justTapped = false
    @State private var showingNameAlert = false
    @State private var nameInput = ""
    @State private var showFeedback = false
    @State private var rippleScale: CGFloat = 0

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
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
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
