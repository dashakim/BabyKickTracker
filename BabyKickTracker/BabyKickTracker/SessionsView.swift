import SwiftUI

struct SessionsView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var showingMealTimePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Track baby kicks within 2 hours after eating")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let session = storage.activeSession {
                        // Active session view
                        VStack(spacing: 20) {
                            HStack {
                                Text("Active Session")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Tracking")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(20)
                            }

                            VStack(spacing: 12) {
                                TimeCard(label: "Started", time: session.mealTime)
                                TimeCard(label: "Ends", time: session.endTime)
                            }

                            // Progress bar
                            VStack(spacing: 8) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 10)
                                            .cornerRadius(5)

                                        Rectangle()
                                            .fill(Color.pink)
                                            .frame(width: geometry.size.width * progress(for: session), height: 10)
                                            .cornerRadius(5)
                                    }
                                }
                                .frame(height: 10)

                                Text(timeRemaining(for: session))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                            }

                            // Kick count
                            VStack(spacing: 8) {
                                Text("\(session.kicks.count)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.pink)
                                Text("Kicks in this session")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pink.opacity(0.05))
                            .cornerRadius(12)

                            // Info box
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Continue logging kicks from the Home screen. They will be automatically tracked in this session.")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding()

                    } else {
                        // No session view
                        VStack(spacing: 20) {
                            Text("⏱️")
                                .font(.system(size: 60))
                                .padding(.top, 40)

                            Text("No active session")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Start a 2-hour tracking session after your next meal")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button(action: { showingMealTimePicker = true }) {
                                Text("Start Session")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 15)
                                    .background(Color.pink)
                                    .cornerRadius(25)
                                    .shadow(radius: 5)
                            }
                            .padding(.top, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding()
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Meal Sessions")
                            .font(.headline)

                        Text("Doctors often recommend tracking baby kicks for 2 hours after meals, when the baby is typically most active due to increased blood sugar levels.")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        Text("During a session, all kicks you log will be associated with that meal time, helping you and your healthcare provider track patterns.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding()
                }
                .padding(.vertical)
            }
            .navigationTitle("Meal Sessions")
            .alert("Start Session", isPresented: $showingMealTimePicker) {
                Button("Just now") {
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
            return "Session ended"
        }
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        return "\(hours)h \(minutes)m remaining"
    }
}

struct TimeCard: View {
    let label: String
    let time: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(time, style: .time)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}
