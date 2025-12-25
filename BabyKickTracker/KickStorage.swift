import Foundation
import Combine
import WatchConnectivity
import UIKit

class KickStorage: NSObject, ObservableObject {
    static let shared = KickStorage()

    @Published var kicks: [Kick] = []
    @Published var sessions: [MealSession] = []
    @Published var babyName: String = ""

    private let kicksKey = "baby_kicks"
    private let sessionsKey = "meal_sessions"
    private let babyNameKey = "baby_name"

    // IMPORTANT: Configure App Group in Xcode:
    // 1. Select your target → Signing & Capabilities
    // 2. Add "App Groups" capability
    // 3. Create group: group.com.yourcompany.babykicktracker
    // 4. Add same group to Watch App target
    // 5. Update appGroupIdentifier below to match
    private let appGroupIdentifier = "group.com.daria.BabyKickTracker"

    // Use shared container for syncing between iPhone and Watch
    private var defaults: UserDefaults {
        if let shared = UserDefaults(suiteName: appGroupIdentifier) {
            return shared
        }
        // Fallback to standard if App Group not configured yet
        return UserDefaults.standard
    }

    private override init() {
        super.init()
        migrateOldDataToAppGroups() // Migrate old data first
        setupWatchConnectivity()
        loadData()
        verifyAppGroupSetup()
        
        // Observe app lifecycle to reload data when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload data when app comes to foreground to get latest from shared storage
            self?.loadData()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload data when app becomes active
            self?.loadData()
        }
    }

    private func migrateOldDataToAppGroups() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Cannot migrate: App Groups not configured")
            return
        }

        let localDefaults = UserDefaults.standard
        let migrationKey = "didMigrateToAppGroups_v1"

        // Check if already migrated
        if sharedDefaults.bool(forKey: migrationKey) {
            print("✅ Data already migrated to App Groups")
            return
        }

        print("🔄 Migrating old data to App Groups...")

        var needsMigration = false

        // Migrate kicks
        if let oldKicksData = localDefaults.data(forKey: kicksKey),
           let oldKicks = try? JSONDecoder().decode([Kick].self, from: oldKicksData) {

            // Load existing kicks from shared storage (if any)
            var sharedKicks: [Kick] = []
            if let sharedData = sharedDefaults.data(forKey: kicksKey),
               let existingKicks = try? JSONDecoder().decode([Kick].self, from: sharedData) {
                sharedKicks = existingKicks
            }

            // Merge: add old kicks that don't already exist in shared storage
            let newKicks = oldKicks.filter { oldKick in
                !sharedKicks.contains(where: { $0.id == oldKick.id })
            }

            if !newKicks.isEmpty {
                sharedKicks.append(contentsOf: newKicks)
                if let encoded = try? JSONEncoder().encode(sharedKicks) {
                    sharedDefaults.set(encoded, forKey: kicksKey)
                    print("✅ Migrated \(newKicks.count) kicks (total now: \(sharedKicks.count))")
                    needsMigration = true
                }
            }
        }

        // Migrate sessions
        if let oldSessionsData = localDefaults.data(forKey: sessionsKey),
           let oldSessions = try? JSONDecoder().decode([MealSession].self, from: oldSessionsData) {

            var sharedSessions: [MealSession] = []
            if let sharedData = sharedDefaults.data(forKey: sessionsKey),
               let existingSessions = try? JSONDecoder().decode([MealSession].self, from: sharedData) {
                sharedSessions = existingSessions
            }

            let newSessions = oldSessions.filter { oldSession in
                !sharedSessions.contains(where: { $0.id == oldSession.id })
            }

            if !newSessions.isEmpty {
                sharedSessions.append(contentsOf: newSessions)
                if let encoded = try? JSONEncoder().encode(sharedSessions) {
                    sharedDefaults.set(encoded, forKey: sessionsKey)
                    print("✅ Migrated \(newSessions.count) sessions")
                    needsMigration = true
                }
            }
        }

        // Migrate baby name
        if let oldName = localDefaults.string(forKey: babyNameKey), !oldName.isEmpty {
            if sharedDefaults.string(forKey: babyNameKey)?.isEmpty ?? true {
                sharedDefaults.set(oldName, forKey: babyNameKey)
                print("✅ Migrated baby name")
                needsMigration = true
            }
        }

        // Mark migration as complete
        sharedDefaults.set(true, forKey: migrationKey)

        if needsMigration {
            print("🎉 Migration complete!")
        } else {
            print("✅ No old data to migrate")
        }
    }

    private func verifyAppGroupSetup() {
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("✅ App Groups configured correctly: \(appGroupIdentifier)")

            // Debug: Check what's actually in shared storage
            if let data = sharedDefaults.data(forKey: kicksKey),
               let kicks = try? JSONDecoder().decode([Kick].self, from: data) {
                print("📱 DEBUG: Shared storage has \(kicks.count) kicks")
            } else {
                print("📱 DEBUG: Shared storage has NO kicks data")
            }

            // Debug: Check local storage too
            if let localData = UserDefaults.standard.data(forKey: kicksKey),
               let localKicks = try? JSONDecoder().decode([Kick].self, from: localData) {
                print("📱 DEBUG: Local storage has \(localKicks.count) kicks")
            } else {
                print("📱 DEBUG: Local storage has NO kicks data")
            }
        } else {
            print("⚠️ WARNING: App Groups not configured! Using local storage only.")
            print("⚠️ Follow instructions in SYNC_SETUP.md to enable iPhone-Watch sync")
        }
    }

    func loadData() {
        // Always read fresh from shared storage (don't use cached data)
        // Get a fresh reference to shared defaults to ensure we read latest data
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ 📱: Cannot access shared storage, using local")
            return
        }
        
        // Load kicks
        if let data = sharedDefaults.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            kicks = decoded
            print("📱 Loaded \(kicks.count) total kicks from shared storage (group: \(appGroupIdentifier))")
        } else {
            print("📱 No kicks data found in shared storage")
            kicks = []
        }

        // Load sessions
        if let data = sharedDefaults.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([MealSession].self, from: data) {
            sessions = decoded
        } else {
            sessions = []
        }

        // Load baby name
        babyName = sharedDefaults.string(forKey: babyNameKey) ?? ""
    }

    func saveBabyName(_ name: String) {
        babyName = name
        defaults.set(name, forKey: babyNameKey)
    }

    func saveKick(_ kick: Kick, syncToWatch: Bool = true) {
        // Check if kick already exists (avoid duplicates)
        if !kicks.contains(where: { $0.id == kick.id }) {
            kicks.append(kick)
            if let encoded = try? JSONEncoder().encode(kicks) {
                defaults.set(encoded, forKey: kicksKey)
                // Note: synchronize() is deprecated and not needed for App Groups
                // Writes to App Groups are immediate and shared across processes
                print("📱 Saved \(kicks.count) kicks to shared storage")
            }

            // Add to active session if exists
            if let index = sessions.firstIndex(where: { $0.isActive && $0.id == kick.sessionId }) {
                sessions[index].kicks.append(kick)
                saveSessions()
            }

            // Notify objectWillChange for UI updates
            objectWillChange.send()

            // Sync to Watch (only if this kick originated on iPhone)
            if syncToWatch {
                sendKickToWatch(kick)
            }
        } else {
            print("📱 Kick already exists, skipping save")
        }
    }

    func startSession(mealTime: Date = Date()) -> MealSession {
        let session = MealSession(mealTime: mealTime)
        sessions.append(session)
        saveSessions()

        // Notify Watch about new session
        sendSessionUpdateToWatch()

        return session
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            defaults.set(encoded, forKey: sessionsKey)
            // Note: synchronize() is deprecated and not needed for App Groups
        }

        // Update watch when sessions change
        sendSessionUpdateToWatch()
    }

    var activeSession: MealSession? {
        sessions.first(where: { $0.isActive })
    }

    var todayKicks: [Kick] {
        let today = Calendar.current.startOfDay(for: Date())
        return kicks.filter { kick in
            Calendar.current.startOfDay(for: kick.timestamp) == today
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

    private func sendKickToWatch(_ kick: Kick) {
        guard WCSession.default.activationState == .activated else {
            print("⚠️ Watch Connectivity not activated")
            return
        }

        let kickData: [String: Any] = [
            "type": "newKick",
            "id": kick.id,
            "timestamp": kick.timestamp.timeIntervalSince1970,
            "sessionId": kick.sessionId ?? ""
        ]

        // Try to send immediately if watch is reachable
        if WCSession.default.isReachable {
            print("📱→⌚ Sending kick to Watch (reachable)")
            WCSession.default.sendMessage(kickData, replyHandler: { response in
                print("✅ Watch confirmed receipt")
            }) { error in
                print("❌ Error sending kick to watch: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ Watch not reachable, using background context")
        }

        // Also update context for background sync
        do {
            try WCSession.default.updateApplicationContext(kickData)
            print("✅ Updated application context for background sync")
        } catch {
            print("❌ Failed to update context: \(error.localizedDescription)")
        }
    }

    private func sendSessionUpdateToWatch() {
        guard WCSession.default.activationState == .activated else { return }

        if let session = activeSession {
            let sessionData: [String: Any] = [
                "type": "sessionUpdate",
                "sessionId": session.id,
                "kickCount": session.kicks.count,
                "endTime": session.endTime.timeIntervalSince1970
            ]

            if WCSession.default.isReachable {
                WCSession.default.sendMessage(sessionData, replyHandler: nil) { error in
                    print("Error sending session to watch: \(error.localizedDescription)")
                }
            }

            try? WCSession.default.updateApplicationContext(sessionData)
        } else {
            // Send session ended notification
            let endData: [String: Any] = ["type": "sessionEnded"]
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(endData, replyHandler: nil)
            }
            try? WCSession.default.updateApplicationContext(endData)
        }
    }

    // MARK: - Future CloudKit Integration
    // TODO: Add CloudKit sync for cloud backup and multi-device sync
    // 1. Enable CloudKit in Capabilities
    // 2. Create CKRecord types for Kick and MealSession
    // 3. Implement sync methods to upload/download from CloudKit
    // 4. Add conflict resolution logic
    // 5. Handle offline mode with local cache
}

// MARK: - WCSessionDelegate

extension KickStorage: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("iPhone WCSession activated: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📱 Received message from Watch (no reply)")
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 Received message from Watch (with reply)")
        handleIncomingMessage(message)
        replyHandler(["status": "received"])
    }

    private func handleIncomingMessage(_ message: [String : Any]) {
        // Handle kicks from Watch
        if let type = message["type"] as? String, type == "newKick",
           let id = message["id"] as? String,
           let timestampInterval = message["timestamp"] as? TimeInterval {
            
            print("📱 Received kick from Watch: \(id)")
            
            let sessionId = message["sessionId"] as? String
            let timestamp = Date(timeIntervalSince1970: timestampInterval)
            
            let kick = Kick(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId?.isEmpty == true ? nil : sessionId
            )
            
            // Update on main thread
            DispatchQueue.main.async {
                // Check if kick already exists (avoid duplicates)
                if !self.kicks.contains(where: { $0.id == kick.id }) {
                    print("📱 Merging kick from Watch: \(id)")
                    // Don't sync back to Watch - this kick came FROM Watch
                    self.saveKick(kick, syncToWatch: false)
                } else {
                    print("📱 Kick already exists, skipping")
                    // Still reload to ensure we have latest data
                    self.loadData()
                }
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context from Watch")
        
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
                // Check if kick already exists (avoid duplicates)
                if !self.kicks.contains(where: { $0.id == kick.id }) {
                    print("📱 Merging kick from Watch context: \(id)")
                    // Don't sync back to Watch - this kick came FROM Watch
                    self.saveKick(kick, syncToWatch: false)
                } else {
                    print("📱 Kick already exists in context, reloading")
                    self.loadData()
                }
            }
        } else {
            // If no kick data, just reload from shared storage
            DispatchQueue.main.async {
                self.loadData()
            }
        }
    }
}
