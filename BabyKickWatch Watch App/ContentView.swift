import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.daria.BabyKickTracker.watchkitapp", category: "ContentView")

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

            // Today's count with sync indicator
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(kickManager.todayKickCount)")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if kickManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    }
                }
                Text("today")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Debug: show sync status
                Text(kickManager.lastSyncStatus)
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .padding(.bottom, 8)
            }

            // Blocking overlay during initial data load
            if kickManager.isLoadingInitialData {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            // Only ensure local data is loaded - sync handled by App-level scenePhase
            #if DEBUG
            logger.debug("View appeared - loading local data")
            #endif
            kickManager.loadData()
        }
        .onChange(of: kickManager.todayKickCount) { oldValue, newValue in
            // Debug: Log when count changes
            #if DEBUG
            if oldValue != newValue {
                logger.debug("Today's count changed: \(oldValue) → \(newValue)")
            }
            #endif
        }
        // Note: Scene phase handling moved to App level for more reliable wrist-raise detection
    }

    private func logKick() {
        // Always allow kick logging - never block user taps
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
