import SwiftUI

struct HomeView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var justTapped = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Active session banner
                    if let session = storage.activeSession {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active 2-Hour Session")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(session.kicks.count) kicks in this session")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            Text("Ends at \(session.endTime, style: .time)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Main tap button
                    Button(action: logKick) {
                        VStack(spacing: 8) {
                            Text("TAP")
                                .font(.system(size: 48, weight: .bold))
                            Text("when baby kicks")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(width: 200, height: 200)
                        .background(
                            Circle()
                                .fill(justTapped ? Color.green : Color.pink)
                        )
                        .scaleEffect(justTapped ? 1.1 : 1.0)
                        .shadow(radius: 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 30)

                    // Stats
                    HStack(spacing: 15) {
                        StatBox(number: storage.todayKicks.count, label: "Today")
                        StatBox(number: storage.kicks.count, label: "Total")
                    }
                    .padding(.horizontal)

                    // Recent kicks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Kicks")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if storage.kicks.isEmpty {
                            Text("No kicks logged yet")
                                .foregroundColor(.gray)
                                .italic()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(Array(storage.kicks.suffix(5).reversed())) { kick in
                                HStack {
                                    Text(kick.timestamp, style: .time)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(kick.timestamp, style: .date)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Baby Kick Tracker")
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

struct StatBox: View {
    let number: Int
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.pink)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 3)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
