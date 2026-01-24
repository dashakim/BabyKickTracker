import SwiftUI
import WatchConnectivity

@main
struct BabyKickWatch_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var kickManager = KickManager.shared
    @State private var lastActiveDate: Date?

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            let calendar = Calendar.current

            if newPhase == .active {
                // Check if midnight crossed while in background
                if let lastDate = lastActiveDate {
                    let lastDay = calendar.startOfDay(for: lastDate)
                    let today = calendar.startOfDay(for: Date())

                    if lastDay != today {
                        // Day changed while in background - force full reload
                        kickManager.handleDayChange()
                    } else {
                        // Same day - normal refresh
                        kickManager.forceRefresh()
                    }
                } else {
                    // First activation - normal refresh
                    kickManager.forceRefresh()
                }

                // Update last active date
                lastActiveDate = Date()
            } else if newPhase == .inactive || newPhase == .background {
                // Track when we go to background
                lastActiveDate = Date()
            }
        }
    }
}
