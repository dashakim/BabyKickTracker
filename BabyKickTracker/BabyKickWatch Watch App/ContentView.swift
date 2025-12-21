import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var kickManager = KickManager.shared
    @State private var justTapped = false
    @State private var kickCount = 0

    var body: some View {
        VStack {
            if let session = kickManager.activeSession {
                // Active session indicator
                VStack(spacing: 4) {
                    Text("Session Active")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("\(session.kickCount) kicks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()

            // Main tap button
            Button(action: logKick) {
                ZStack {
                    Circle()
                        .fill(justTapped ? Color.green : Color.pink)
                        .frame(width: 120, height: 120)
                        .scaleEffect(justTapped ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: justTapped)

                    VStack(spacing: 4) {
                        Text("TAP")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if justTapped {
                            Text("✓")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
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
        .onAppear {
            kickManager.loadData()
        }
    }

    private func logKick() {
        kickManager.logKick()

        // Visual feedback
        justTapped = true
        WKInterfaceDevice.current().play(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            justTapped = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
