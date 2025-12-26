import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var kickManager = KickManager.shared
    @State private var justTapped = false
    @State private var kickCount = 0
    @State private var rippleScale: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Adaptive background for dark mode
            (colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.13) : Color.black)
                .ignoresSafeArea()

            VStack {
            if let session = kickManager.activeSession {
                // Active session indicator
                VStack(spacing: 4) {
                    Text("Session Active")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.64, green: 0.91, blue: 0.80))
                    Text("\(session.kickCount) kicks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()

            // Main tap button - gentle and comforting
            Button(action: logKick) {
                ZStack {
                    // Ripple on tap
                    if justTapped {
                        Circle()
                            .stroke(Color(red: 1.0, green: 0.71, blue: 0.82).opacity(0.4), lineWidth: 1.5)
                            .frame(width: 100, height: 100)
                            .scaleEffect(rippleScale)
                            .opacity(2 - rippleScale)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.71, blue: 0.82).opacity(0.95),
                                    Color(red: 1.0, green: 0.71, blue: 0.82)
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .blur(radius: 2)
                        )

                    // Pregnant person icon
                    Image("footprints")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white.opacity(0.95))
                        .frame(width: 45, height: 45)
                }
                .scaleEffect(justTapped ? 0.92 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: justTapped)
            }
            .buttonStyle(.plain)

            Spacer()

            // Today's count
            VStack(spacing: 2) {
                Text("\(kickManager.todayKickCount)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Always reload when view appears to ensure we have latest data
            print("⌚ View appeared - reloading data from shared storage")
            kickManager.loadData()
        }
        .onChange(of: kickManager.todayKickCount) { oldValue, newValue in
            // Debug: Log when count changes
            if oldValue != newValue {
                print("⌚ Today's count changed: \(oldValue) → \(newValue)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationWillEnterForegroundNotification)) { _ in
            // Reload data when Watch app comes to foreground
            // This is especially important after midnight when day changes
            print("⌚ Watch app entering foreground - reloading all data from shared storage")
            // Small delay to ensure any pending writes are complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                kickManager.loadData()
            }
        }
    }

    private func logKick() {
        kickManager.logKick()

        // Visual feedback
        justTapped = true

        // Haptic vibration feedback
        WKInterfaceDevice.current().play(.click)

        // Additional vibration after a short delay for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WKInterfaceDevice.current().play(.success)
        }

        // Ripple effect
        withAnimation(.easeOut(duration: 1.2)) {
            rippleScale = 2.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            justTapped = false
            rippleScale = 0
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
