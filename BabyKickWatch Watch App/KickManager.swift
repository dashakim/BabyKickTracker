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
        
        // Request sync after a short delay to ensure Watch Connectivity is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if WCSession.default.activationState == .activated {
                print("⌚ Requesting initial sync from iPhone")
                self.requestFullSyncFromiPhone()
            }
        }
        
        // Observe shared storage changes
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

    func loadData() {
        // Always read fresh from shared storage (don't use cached data)
        // Get a NEW reference each time to avoid caching issues
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ WATCH: Cannot access shared storage, using local")
            return
        }
        
        // Force synchronization - this helps with App Groups propagation delays
        // Note: synchronize() is deprecated but can help with App Groups timing
        sharedDefaults.synchronize()
        
        // Try reading multiple times to ensure we get latest data
        var kicks: [Kick] = []
        var lastCount = 0
        
        // Read up to 3 times to catch any propagation delays
        for attempt in 1...3 {
            if let data = sharedDefaults.data(forKey: kicksKey),
               let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                kicks = decoded
                if kicks.count != lastCount {
                    print("⌚ Loaded \(kicks.count) total kicks from shared storage (attempt \(attempt))")
                    lastCount = kicks.count
                    // If count changed, try once more to see if there's more data
                    if attempt < 3 {
                        sharedDefaults.synchronize()
                        continue
                    }
                } else {
                    // Count is stable, we have the latest
                    break
                }
            } else {
                if attempt == 1 {
                    print("⌚ No kicks data found in shared storage")
                }
                break
            }
        }
        
        if kicks.isEmpty {
            kicks = []
        }
        
        // Use calendar with explicit timezone to ensure consistent date comparison
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        let todayKicks = kicks.filter { kick in
            let kickDay = calendar.startOfDay(for: kick.timestamp)
            return calendar.isDate(kickDay, inSameDayAs: today)
        }
        todayKickCount = todayKicks.count

        // Debug logging - only log when count changes or on initial load
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.timeZone = calendar.timeZone
        
        print("⌚ WATCH: Loaded \(kicks.count) total kicks, \(todayKickCount) today")
        print("⌚ WATCH: Current time: \(formatter.string(from: now))")
        print("⌚ WATCH: Today starts at: \(formatter.string(from: today))")
        print("⌚ WATCH: Timezone: \(calendar.timeZone.identifier)")
        if todayKickCount > 0, let first = todayKicks.first, let last = todayKicks.last {
            print("⌚ WATCH: First today kick: \(formatter.string(from: first.timestamp))")
            print("⌚ WATCH: Last today kick: \(formatter.string(from: last.timestamp))")
        }
        
        // If Watch Connectivity is active, request sync to ensure we have latest data
        // This helps catch up if we're reading stale data from App Groups
        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            // Request sync in background (don't block)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.todayKickCount < 50 { // If count seems low, request sync
                    print("⌚ Count seems low, requesting sync from iPhone")
                    self.requestFullSyncFromiPhone()
                }
            }
        }

        if let sessionData = sharedDefaults.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: sessionData) {
            if session.endTime > Date() {
                activeSession = session
                print("⌚ Active session found: \(session.kickCount) kicks")
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

            // Send to iPhone for real-time update
            sendKickToPhone(kick)
        } else {
            print("⌚ Kick already exists, reloading data")
            loadData()
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
            print("⚠️ Phone not reachable, using background context")
        }

        // Always update application context for background sync
        do {
            try WCSession.default.updateApplicationContext(kickData)
            print("✅ Updated application context for background sync")
        } catch {
            print("❌ Failed to update context: \(error.localizedDescription)")
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
                            print("⌚ Updated today's count: \(self.todayKickCount) kicks (from merged data)")
                            
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
                    print("⌚ Updated today's count from context: \(self.todayKickCount) kicks (from merged data)")
                    
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
