import Foundation
import WatchConnectivity
import Combine

// Shared Kick model (matches iPhone app)
struct Kick: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let sessionId: String?

    init(id: String = UUID().uuidString, timestamp: Date = Date(), sessionId: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
    }
}

struct ActiveSession: Codable {
    let id: String
    let kickCount: Int
    let endTime: Date
}

class KickManager: NSObject, ObservableObject {
    static let shared = KickManager()

    @Published var todayKickCount: Int = 0
    @Published var activeSession: ActiveSession?

    private var midnightTimer: Timer?
    private var lastKickLoggedAt: Date?

    // IMPORTANT: Must match iPhone app's App Group identifier
    // Configure in Xcode: Target → Signing & Capabilities → App Groups
    private let appGroupIdentifier = "group.com.daria.BabyKickTracker"

    // Use shared container for syncing with iPhone
    private var defaults: UserDefaults {
        if let shared = UserDefaults(suiteName: appGroupIdentifier) {
            return shared
        }
        // Fallback to standard if App Group not configured yet
        return UserDefaults.standard
    }

    private let kicksKey = "baby_kicks" // Use same key as iPhone for shared access

    override private init() {
        super.init()
        setupWatchConnectivity()
        verifyAppGroupSetup()
        loadData() // Load data immediately on initialization
        setupMidnightTimer() // Schedule automatic reload at midnight

        // Observe shared storage changes for App Groups sync
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload data when shared storage changes
            print("⌚ UserDefaults changed - reloading data")
            self?.loadData()
        }
    }

    deinit {
        midnightTimer?.invalidate()
        midnightTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func verifyAppGroupSetup() {
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("✅ WATCH: App Groups configured correctly: \(appGroupIdentifier)")

            // Debug: Check what's actually in shared storage
            if let data = sharedDefaults.data(forKey: kicksKey),
               let kicks = try? JSONDecoder().decode([Kick].self, from: data) {
                print("⌚ DEBUG: Shared storage has \(kicks.count) kicks")
            } else {
                print("⌚ DEBUG: Shared storage has NO kicks data")
            }

            // Debug: Check local storage too
            if let localData = UserDefaults.standard.data(forKey: kicksKey),
               let localKicks = try? JSONDecoder().decode([Kick].self, from: localData) {
                print("⌚ DEBUG: Local storage has \(localKicks.count) kicks")
            } else {
                print("⌚ DEBUG: Local storage has NO kicks data")
            }
        } else {
            print("⚠️ WATCH WARNING: App Groups not configured! Using local storage only.")
            print("⚠️ Follow instructions in SYNC_SETUP.md to enable iPhone-Watch sync")
        }
    }

    private func setupMidnightTimer() {
        let calendar = Calendar.current
        let now = Date()

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return
        }

        let secondsUntilMidnight = tomorrow.timeIntervalSince(now)

        midnightTimer = Timer.scheduledTimer(withTimeInterval: secondsUntilMidnight, repeats: false) { [weak self] _ in
            print("⌚ MIDNIGHT DETECTED - Reloading data")
            DispatchQueue.main.async {
                self?.loadData()
                self?.setupMidnightTimer() // Reschedule for next midnight
            }
        }

        print("⌚ Scheduled midnight reload in \(Int(secondsUntilMidnight)) seconds")
    }

    func loadData() {
        // Skip reload if we just logged a kick (prevent blinking)
        if let lastLogged = lastKickLoggedAt, Date().timeIntervalSince(lastLogged) < 2.0 {
            print("⌚ Skipping reload - just logged a kick")
            return
        }

        // Always read fresh from shared storage
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ WATCH: Cannot access shared storage")
            return
        }

        // Force synchronization to ensure we get latest data from App Groups
        sharedDefaults.synchronize()

        // Read kicks from shared storage
        var kicks: [Kick] = []
        if let data = sharedDefaults.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            kicks = decoded
        }

        // Calculate today's kicks
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let todayKicks = kicks.filter { kick in
            let kickDay = calendar.startOfDay(for: kick.timestamp)
            return calendar.isDate(kickDay, inSameDayAs: today)
        }
        todayKickCount = todayKicks.count

        print("⌚ Loaded \(kicks.count) total, \(todayKickCount) today")

        // Load active session if exists
        if let sessionData = sharedDefaults.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: sessionData) {
            if session.endTime > Date() {
                activeSession = session
                print("⌚ Active session found: \(session.kickCount) kicks")
            }
        }

        // If Watch Connectivity is active, request sync to ensure we have latest data
        // Always request sync when iPhone is reachable (don't rely on count threshold)
        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("⌚ Requesting sync from iPhone to ensure latest data")
                self.requestFullSyncFromiPhone()
            }
        }
    }

    func logKick() {
        let kick = Kick(
            timestamp: Date(),
            sessionId: activeSession?.id
        )

        // Always read fresh from shared storage first to ensure we have latest data
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ ⌚: Cannot access shared storage for save")
            return
        }
        
        var allKicks: [Kick] = []
        if let data = sharedDefaults.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            allKicks = decoded
        }
        
        // Check if kick already exists (avoid duplicates)
        if !allKicks.contains(where: { $0.id == kick.id }) {
            allKicks.append(kick)
            saveKicks(allKicks)
            
            // Update today's count
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            todayKickCount = allKicks.filter { kick in
                let kickDay = calendar.startOfDay(for: kick.timestamp)
                return calendar.isDate(kickDay, inSameDayAs: today)
            }.count

            // Mark that we just logged a kick to prevent immediate reload
            lastKickLoggedAt = Date()

            // Send to iPhone for real-time update
            sendKickToPhone(kick)
        } else {
            print("⌚ Kick already exists, reloading data")
            loadData()
        }
    }

    func manualRefresh() {
        print("⌚ Manual refresh triggered")
        loadData()

        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            requestFullSyncFromiPhone()
        }
    }

    private func loadKicks() -> [Kick] {
        guard let data = defaults.data(forKey: kicksKey),
              let kicks = try? JSONDecoder().decode([Kick].self, from: data) else {
            return []
        }
        return kicks
    }

    private func saveKicks(_ kicks: [Kick]) {
        if let data = try? JSONEncoder().encode(kicks) {
            defaults.set(data, forKey: kicksKey)
            // Note: synchronize() is deprecated and not needed for App Groups
            // Writes to App Groups are immediate and shared across processes
            print("⌚ Saved \(kicks.count) kicks to shared storage")
        }
    }

    // MARK: - Watch Connectivity

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    private func sendKickToPhone(_ kick: Kick) {
        guard WCSession.default.activationState == .activated else {
            print("⚠️ Watch Connectivity not activated, kick saved to shared storage only")
            return
        }

        // Encode the full kick object to send complete data
        let kickData: [String: Any] = [
            "type": "newKick",
            "id": kick.id,
            "timestamp": kick.timestamp.timeIntervalSince1970,
            "sessionId": kick.sessionId ?? ""
        ]

        // Try to send immediately if phone is reachable
        if WCSession.default.isReachable {
            print("⌚→📱 Sending kick to iPhone (reachable)")
            WCSession.default.sendMessage(kickData, replyHandler: { response in
                print("✅ iPhone confirmed kick receipt")
            }) { error in
                print("❌ Error sending kick to iPhone: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ Phone not reachable, will sync all kicks via background context")
        }

        // Always update application context with FULL kicks array for reliable background sync
        // This ensures that if watch logs multiple kicks while out of range, all are synced
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        if let allKicksData = sharedDefaults.data(forKey: kicksKey),
           let allKicks = try? JSONDecoder().decode([Kick].self, from: allKicksData),
           let kicksData = try? JSONEncoder().encode(allKicks) {
            do {
                let fullSyncData: [String: Any] = [
                    "type": "fullSync",
                    "kicks": kicksData,
                    "totalCount": allKicks.count
                ]
                try WCSession.default.updateApplicationContext(fullSyncData)
                print("✅ Updated application context with \(allKicks.count) total kicks")
            } catch {
                print("❌ Failed to update context: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension KickManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
            
            // When Watch Connectivity activates, request full sync from iPhone
            // This ensures we have all the latest data
            if activationState == .activated && session.isReachable {
                print("⌚ Requesting full sync from iPhone")
                requestFullSyncFromiPhone()
            } else {
                // If not reachable, just reload from shared storage
                DispatchQueue.main.async {
                    self.loadData()
                }
            }
        }
    }
    
    private func requestFullSyncFromiPhone() {
        guard WCSession.default.isReachable else {
            print("⌚ iPhone not reachable, will sync from shared storage")
            DispatchQueue.main.async {
                self.loadData()
            }
            return
        }
        
        // Request all kicks from iPhone
        let request: [String: Any] = ["type": "requestSync"]
        WCSession.default.sendMessage(request, replyHandler: { response in
            if let kicksData = response["kicks"] as? Data,
               let allKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) {
                print("⌚ Received \(allKicks.count) kicks from iPhone sync")
                DispatchQueue.main.async {
                    // Save all kicks to shared storage
                    guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }
                    if let data = try? JSONEncoder().encode(allKicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        print("⌚ Saved \(allKicks.count) kicks from iPhone sync")
                    }
                    // Reload to update count
                    self.loadData()
                }
            }
        }) { error in
            print("⌚ Error requesting sync: \(error.localizedDescription)")
            // Fallback to loading from shared storage
            DispatchQueue.main.async {
                self.loadData()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone
        if let type = message["type"] as? String {
            print("⌚ Received message from iPhone: \(type)")
            switch type {
            case "fullSync":
                // iPhone sent all kicks - replace our data with this
                if let kicksData = message["kicks"] as? Data,
                   let allKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) {
                    print("⌚ Received full sync from iPhone: \(allKicks.count) kicks")
                    DispatchQueue.main.async {
                        // Save all kicks to shared storage
                        guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }
                        if let data = try? JSONEncoder().encode(allKicks) {
                            sharedDefaults.set(data, forKey: self.kicksKey)
                            print("⌚ Saved \(allKicks.count) kicks from iPhone full sync")
                        }
                        // Reload to update count
                        self.loadData()
                    }
                }
            case "newKick":
                // iPhone logged a kick - merge it directly from the message
                // This avoids App Groups propagation delays
                if let id = message["id"] as? String,
                   let timestampInterval = message["timestamp"] as? TimeInterval {
                    let sessionId = message["sessionId"] as? String
                    let timestamp = Date(timeIntervalSince1970: timestampInterval)
                    let kick = Kick(
                        id: id,
                        timestamp: timestamp,
                        sessionId: sessionId?.isEmpty == true ? nil : sessionId
                    )
                    
                    DispatchQueue.main.async {
                        // Load current kicks from shared storage
                        guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                            print("⚠️ ⌚: Cannot access shared storage for merge")
                            return
                        }
                        
                        var kicks: [Kick] = []
                        if let data = sharedDefaults.data(forKey: self.kicksKey),
                           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                            kicks = decoded
                        }
                        
                        // Add kick if it doesn't exist
                        if !kicks.contains(where: { $0.id == kick.id }) {
                            kicks.append(kick)
                            // Save back to shared storage
                            if let data = try? JSONEncoder().encode(kicks) {
                                sharedDefaults.set(data, forKey: self.kicksKey)
                                print("⌚ Merged kick from iPhone message: \(id), total now: \(kicks.count)")
                            }
                            
                            // Update today's count immediately from the merged kicks
                            let calendar = Calendar.current
                            let today = calendar.startOfDay(for: Date())
                            let newCount = kicks.filter { kick in
                                let kickDay = calendar.startOfDay(for: kick.timestamp)
                                return calendar.isDate(kickDay, inSameDayAs: today)
                            }.count
                            
                            // Update count - we calculated it from the merged data, so it's correct
                            self.todayKickCount = newCount
                            self.objectWillChange.send()
                            print("⌚ UI update triggered - count: \(self.todayKickCount)")

                            // Don't call loadData() here - it would read stale data from App Groups
                            // The count is already correct from the merged kicks
                        } else {
                            print("⌚ Kick already exists, reloading to sync")
                            // Only reload if kick already exists (might be in shared storage)
                            self.loadData()
                        }
                    }
                }
            case "sessionUpdate":
                if let sessionId = message["sessionId"] as? String,
                   let kickCount = message["kickCount"] as? Int,
                   let endTimeInterval = message["endTime"] as? TimeInterval {
                    let session = ActiveSession(
                        id: sessionId,
                        kickCount: kickCount,
                        endTime: Date(timeIntervalSince1970: endTimeInterval)
                    )
                    DispatchQueue.main.async {
                        self.activeSession = session
                        // Save to defaults
                        if let data = try? JSONEncoder().encode(session) {
                            self.defaults.set(data, forKey: "activeSession")
                        }
                        // Also reload kicks to ensure sync
                        self.loadData()
                    }
                }
            case "sessionEnded":
                DispatchQueue.main.async {
                    self.activeSession = nil
                    self.defaults.removeObject(forKey: "activeSession")
                    // Reload data to ensure sync
                    self.loadData()
                }
            default:
                break
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Handle background updates from iPhone
        print("⌚ Received application context from iPhone")
        
        // Handle full sync from context
        if let type = applicationContext["type"] as? String, type == "fullSync",
           let kicksData = applicationContext["kicks"] as? Data,
           let allKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) {
            print("⌚ Received full sync from iPhone context: \(allKicks.count) kicks")
            DispatchQueue.main.async {
                // Save all kicks to shared storage
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }
                if let data = try? JSONEncoder().encode(allKicks) {
                    sharedDefaults.set(data, forKey: self.kicksKey)
                    print("⌚ Saved \(allKicks.count) kicks from iPhone full sync context")
                }
                // Reload to update count
                self.loadData()
                self.objectWillChange.send()
            }
            return
        }
        
        // Handle kick from context - merge directly to avoid App Groups delays
        if let type = applicationContext["type"] as? String, type == "newKick",
           let id = applicationContext["id"] as? String,
           let timestampInterval = applicationContext["timestamp"] as? TimeInterval {
            let sessionId = applicationContext["sessionId"] as? String
            let timestamp = Date(timeIntervalSince1970: timestampInterval)
            let kick = Kick(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId?.isEmpty == true ? nil : sessionId
            )
            
            DispatchQueue.main.async {
                // Load current kicks from shared storage
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                    print("⚠️ ⌚: Cannot access shared storage for context merge")
                    return
                }
                
                var kicks: [Kick] = []
                if let data = sharedDefaults.data(forKey: self.kicksKey),
                   let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                    kicks = decoded
                }
                
                // Add kick if it doesn't exist
                if !kicks.contains(where: { $0.id == kick.id }) {
                    kicks.append(kick)
                    // Save back to shared storage
                    if let data = try? JSONEncoder().encode(kicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        print("⌚ Merged kick from iPhone context: \(id), total now: \(kicks.count)")
                    }
                    
                    // Update today's count immediately from the merged kicks
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let newCount = kicks.filter { kick in
                        let kickDay = calendar.startOfDay(for: kick.timestamp)
                        return calendar.isDate(kickDay, inSameDayAs: today)
                    }.count
                    
                    // Update count - we calculated it from the merged data, so it's correct
                    self.todayKickCount = newCount
                    self.objectWillChange.send()
                    print("⌚ UI update triggered from context - count: \(self.todayKickCount)")

                    // Don't call loadData() here - it would read stale data from App Groups
                    // The count is already correct from the merged kicks
                } else {
                    print("⌚ Kick already exists in context, reloading to sync")
                    // Only reload if kick already exists (might be in shared storage)
                    self.loadData()
                }
            }
        } else {
            // If no kick data, just reload from shared storage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadData()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages with reply handler
        self.session(session, didReceiveMessage: message)
        replyHandler(["status": "received"])
    }

    // MARK: - Future CloudKit Integration
    // TODO: CloudKit will be added to iPhone app and will automatically sync to Watch
    // via the shared App Group container. No additional CloudKit code needed on Watch.
}
