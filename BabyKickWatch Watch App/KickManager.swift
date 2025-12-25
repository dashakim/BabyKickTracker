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
        
        // Observe shared storage changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload data when shared storage changes
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
        // Get a fresh reference to shared defaults to ensure we read latest data
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ WATCH: Cannot access shared storage, using local")
            return
        }
        
        // Load today's kick count
        let kicks: [Kick]
        if let data = sharedDefaults.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            kicks = decoded
            print("⌚ Loaded \(kicks.count) total kicks from shared storage (group: \(appGroupIdentifier))")
        } else {
            kicks = []
            print("⌚ No kicks data found in shared storage")
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        todayKickCount = kicks.filter { kick in
            Calendar.current.startOfDay(for: kick.timestamp) == today
        }.count

        print("⌚ Today's count: \(todayKickCount) kicks")

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

        // Save to shared container (auto-synced with iPhone via App Groups)
        var kicks = loadKicks()
        
        // Check if kick already exists (avoid duplicates)
        if !kicks.contains(where: { $0.id == kick.id }) {
            kicks.append(kick)
            saveKicks(kicks)
            
            // Update today's count
            let today = Calendar.current.startOfDay(for: Date())
            todayKickCount = kicks.filter { kick in
                Calendar.current.startOfDay(for: kick.timestamp) == today
            }.count

            // Send to iPhone for real-time update
            sendKickToPhone(kick)
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
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone
        if let type = message["type"] as? String {
            print("⌚ Received message from iPhone: \(type)")
            switch type {
            case "newKick":
                // iPhone logged a kick - merge it with our data
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
                        let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) ?? UserDefaults.standard
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
                                print("⌚ Merged kick from iPhone: \(id), total now: \(kicks.count)")
                            }
                        } else {
                            print("⌚ Kick already exists, skipping")
                        }
                        
                        // Reload to update UI
                        self.loadData()
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
        
        // Handle kick from context
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
                let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) ?? UserDefaults.standard
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
                }
                
                // Reload to update UI
                self.loadData()
            }
        } else {
            // If no kick data, just reload from shared storage
            DispatchQueue.main.async {
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
