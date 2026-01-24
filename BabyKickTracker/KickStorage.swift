import Foundation
import Combine
import WatchConnectivity
import UIKit
import os.log

private let logger = Logger(subsystem: "com.daria.BabyKickTracker", category: "KickStorage")

class KickStorage: NSObject, ObservableObject {
    static let shared = KickStorage()

    @Published var kicks: [Kick] = []
    @Published var sessions: [MealSession] = []
    @Published var babyName: String = ""

    private var midnightTimer: Timer?

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
        setupMidnightTimer() // Schedule automatic reload at midnight

        // Migrate to CloudKit in background
        Task {
            do {
                try await CloudKitMigrator.shared.migrateToCloudKitIfNeeded()
                #if DEBUG
                logger.debug("CloudKit migration check complete")
                #endif
            } catch {
                #if DEBUG
                logger.error("CloudKit migration failed: \(error.localizedDescription)")
                #endif
                // Continue with local storage - app works offline
            }
        }

        // Observe app lifecycle to reload data when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload data when app comes to foreground to get latest from shared storage
            // This is especially important after midnight when day changes
            #if DEBUG
            logger.debug("App entering foreground - reloading all data and pushing to Watch")
            #endif
            self?.loadData()
            self?.sendFullSyncToWatch()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload data when app becomes active
            // Force a full reload from shared storage to ensure sync after midnight
            #if DEBUG
            logger.debug("App became active - reloading all data from shared storage")
            #endif
            self?.loadData()
        }

        // Add scene phase notification for iOS 13+
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            #if DEBUG
            logger.debug("Scene activated - reloading all data")
            #endif
            self?.loadData()
        }
    }

    deinit {
        midnightTimer?.invalidate()
        midnightTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func migrateOldDataToAppGroups() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            logger.warning("Cannot migrate: App Groups not configured")
            #endif
            return
        }

        let localDefaults = UserDefaults.standard
        let migrationKey = "didMigrateToAppGroups_v1"

        // Check if already migrated
        if sharedDefaults.bool(forKey: migrationKey) {
            #if DEBUG
            logger.debug("Data already migrated to App Groups")
            #endif
            return
        }

        #if DEBUG
        logger.debug("Migrating old data to App Groups...")
        #endif

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
                    #if DEBUG
                    logger.debug("Migrated \(newKicks.count) kicks (total now: \(sharedKicks.count))")
                    #endif
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
                    #if DEBUG
                    logger.debug("Migrated \(newSessions.count) sessions")
                    #endif
                    needsMigration = true
                }
            }
        }

        // Migrate baby name
        if let oldName = localDefaults.string(forKey: babyNameKey), !oldName.isEmpty {
            if sharedDefaults.string(forKey: babyNameKey)?.isEmpty ?? true {
                sharedDefaults.set(oldName, forKey: babyNameKey)
                #if DEBUG
                logger.debug("Migrated baby name")
                #endif
                needsMigration = true
            }
        }

        // Mark migration as complete
        sharedDefaults.set(true, forKey: migrationKey)

        #if DEBUG
        if needsMigration {
            logger.debug("Migration complete!")
        } else {
            logger.debug("No old data to migrate")
        }
        #endif
    }

    private func verifyAppGroupSetup() {
        #if DEBUG
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            logger.debug("App Groups configured correctly")

            // Debug: Check what's actually in shared storage
            if let data = sharedDefaults.data(forKey: kicksKey),
               let decodedKicks = try? JSONDecoder().decode([Kick].self, from: data) {
                logger.debug("Shared storage has \(decodedKicks.count) kicks")
            } else {
                logger.debug("Shared storage has NO kicks data")
            }

            // Debug: Check local storage too
            if let localData = UserDefaults.standard.data(forKey: kicksKey),
               let localKicks = try? JSONDecoder().decode([Kick].self, from: localData) {
                logger.debug("Local storage has \(localKicks.count) kicks")
            } else {
                logger.debug("Local storage has NO kicks data")
            }
        } else {
            logger.warning("App Groups not configured! Using local storage only.")
        }
        #endif
    }

    private func setupMidnightTimer() {
        let calendar = Calendar.current
        let now = Date()

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return
        }

        let secondsUntilMidnight = tomorrow.timeIntervalSince(now)

        midnightTimer = Timer.scheduledTimer(withTimeInterval: secondsUntilMidnight, repeats: false) { [weak self] _ in
            #if DEBUG
            logger.debug("MIDNIGHT DETECTED - Reloading data")
            #endif
            DispatchQueue.main.async {
                self?.loadData()
                self?.setupMidnightTimer() // Reschedule for next midnight
            }
        }

        #if DEBUG
        logger.debug("Scheduled midnight reload in \(Int(secondsUntilMidnight)) seconds")
        #endif
    }

    func loadData() {
        // Always read fresh from shared storage (don't use cached data)
        // Get a fresh reference to shared defaults to ensure we read latest data
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            logger.warning("Cannot access shared storage, using local")
            #endif
            return
        }

        // Load kicks
        if let data = sharedDefaults.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            kicks = decoded
            #if DEBUG
            logger.debug("Loaded \(self.kicks.count) total kicks from shared storage")
            #endif
        } else {
            #if DEBUG
            logger.debug("No kicks data found in shared storage")
            #endif
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

        // Save to CloudKit in background
        Task {
            do {
                try await CloudKitManager.shared.saveBabyName(name)
            } catch {
                #if DEBUG
                logger.error("Failed to save baby name to CloudKit: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func saveKick(_ kick: Kick, syncToWatch: Bool = true) {
        // Always read fresh from shared storage first to ensure we have latest data
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            logger.warning("Cannot access shared storage for save")
            #endif
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

            // Save to shared storage
            if let encoded = try? JSONEncoder().encode(allKicks) {
                sharedDefaults.set(encoded, forKey: kicksKey)
                #if DEBUG
                logger.debug("Saved \(allKicks.count) kicks to shared storage")
                #endif
            }

            // Update in-memory array
            kicks = allKicks

            // Add to active session if exists
            if let index = sessions.firstIndex(where: { $0.isActive && $0.id == kick.sessionId }) {
                sessions[index].kicks.append(kick)
                saveSessions()
            }

            // Notify objectWillChange for UI updates
            objectWillChange.send()

            // Save to CloudKit in background
            Task {
                do {
                    try await CloudKitManager.shared.saveKick(kick)
                } catch {
                    #if DEBUG
                    logger.error("Failed to save kick to CloudKit: \(error.localizedDescription)")
                    #endif
                    // Continue - local storage is primary
                }
            }

            // Sync to Watch (only if this kick originated on iPhone)
            if syncToWatch {
                sendKickToWatch(kick)
            }
        } else {
            #if DEBUG
            logger.debug("Kick already exists, skipping save")
            #endif
            // Still reload to ensure we have latest data
            loadData()
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
        // Use calendar with explicit comparison to ensure consistent date matching
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let filtered = kicks.filter { kick in
            let kickDay = calendar.startOfDay(for: kick.timestamp)
            return calendar.isDate(kickDay, inSameDayAs: today)
        }
        return filtered
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
            #if DEBUG
            logger.warning("Watch Connectivity not activated")
            #endif
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
            #if DEBUG
            logger.debug("Sending kick to Watch (reachable)")
            #endif
            WCSession.default.sendMessage(kickData, replyHandler: { response in
                #if DEBUG
                logger.debug("Watch confirmed receipt")
                #endif
            }) { error in
                #if DEBUG
                logger.error("Error sending kick to watch: \(error.localizedDescription)")
                #endif
            }
        } else {
            #if DEBUG
            logger.debug("Watch not reachable, will use application context")
            #endif
        }

        // ALWAYS send fullSync via application context
        // This ensures Watch gets ALL kicks when it wakes up, even if iPhone app isn't running
        // Application context persists and is delivered when Watch activates
        if let data = try? JSONEncoder().encode(kicks) {
            let syncData: [String: Any] = [
                "type": "fullSync",
                "kicks": data,
                "totalCount": kicks.count,
                "timestamp": Date().timeIntervalSince1970
            ]
            do {
                try WCSession.default.updateApplicationContext(syncData)
                #if DEBUG
                logger.debug("Updated application context with fullSync: \(self.kicks.count) kicks")
                #endif
            } catch {
                #if DEBUG
                logger.error("Failed to update context: \(error.localizedDescription)")
                #endif
            }
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
                    #if DEBUG
                    logger.error("Error sending session to watch: \(error.localizedDescription)")
                    #endif
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
            #if DEBUG
            logger.error("WCSession activation failed: \(error.localizedDescription)")
            #endif
        } else {
            #if DEBUG
            logger.debug("iPhone WCSession activated: \(activationState.rawValue), reachable: \(session.isReachable)")
            #endif

            // ALWAYS send fullSync via application context on activation
            // This ensures Watch gets latest data when it wakes up, even if iPhone app closes
            if activationState == .activated {
                // Send via application context (persists even when not reachable)
                if let data = try? JSONEncoder().encode(kicks) {
                    let syncData: [String: Any] = [
                        "type": "fullSync",
                        "kicks": data,
                        "totalCount": kicks.count,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    do {
                        try WCSession.default.updateApplicationContext(syncData)
                        #if DEBUG
                        logger.debug("Sent fullSync via application context on activation: \(self.kicks.count) kicks")
                        #endif
                    } catch {
                        #if DEBUG
                        logger.error("Failed to update context on activation: \(error.localizedDescription)")
                        #endif
                    }
                }

                // Also send directly if reachable (faster)
                if session.isReachable {
                    #if DEBUG
                    logger.debug("Watch is reachable - sending full sync directly")
                    #endif
                    sendFullSyncToWatch()
                }
            }
        }
    }

    private func sendFullSyncToWatch() {
        guard WCSession.default.activationState == .activated else {
            #if DEBUG
            logger.debug("WCSession not activated, cannot send sync")
            #endif
            return
        }

        // Send all kicks to Watch
        if let data = try? JSONEncoder().encode(kicks) {
            let syncData: [String: Any] = [
                "type": "fullSync",
                "kicks": data,
                "totalCount": kicks.count,
                "timestamp": Date().timeIntervalSince1970
            ]

            // Try direct message if reachable
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(syncData, replyHandler: { response in
                    #if DEBUG
                    logger.debug("Watch confirmed full sync receipt")
                    #endif
                }) { error in
                    #if DEBUG
                    logger.error("Error sending full sync: \(error.localizedDescription)")
                    #endif
                }
            }

            // Always update application context (persists even when not reachable)
            try? WCSession.default.updateApplicationContext(syncData)
            #if DEBUG
            logger.debug("Sent full sync to Watch: \(self.kicks.count) kicks")
            #endif
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        logger.debug("WCSession became inactive")
        #endif
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        #if DEBUG
        logger.debug("Received message from Watch (no reply)")
        #endif
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        #if DEBUG
        logger.debug("Received message from Watch (with reply)")
        #endif

        // Handle sync request from Watch
        if let type = message["type"] as? String, type == "requestSync" {
            #if DEBUG
            logger.debug("Watch requested full sync")
            #endif

            // Read current kicks from shared storage
            guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                replyHandler(["status": "error"])
                return
            }

            var allKicks: [Kick] = []
            if let data = sharedDefaults.data(forKey: self.kicksKey),
               let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                allKicks = decoded
            }

            // Merge any kicks Watch sent us
            if let watchKicksData = message["watchKicks"] as? Data,
               let watchKicks = try? JSONDecoder().decode([Kick].self, from: watchKicksData) {
                #if DEBUG
                logger.debug("Watch sent \(watchKicks.count) kicks to merge")
                #endif

                // Merge by ID - combine all unique kicks
                var mergedKicksDict: [String: Kick] = [:]
                for kick in allKicks {
                    mergedKicksDict[kick.id] = kick
                }
                for kick in watchKicks {
                    // Always add Watch kicks that don't exist
                    if mergedKicksDict[kick.id] == nil {
                        mergedKicksDict[kick.id] = kick
                    }
                }
                // Sort by timestamp for consistent ordering
                allKicks = Array(mergedKicksDict.values).sorted { $0.timestamp < $1.timestamp }

                // Save merged kicks to shared storage
                if let data = try? JSONEncoder().encode(allKicks) {
                    sharedDefaults.set(data, forKey: self.kicksKey)
                    #if DEBUG
                    logger.debug("Merged to \(allKicks.count) total kicks")
                    #endif
                }

                // Update in-memory array on main thread
                DispatchQueue.main.async {
                    self.kicks = allKicks
                    self.objectWillChange.send()
                }
            }

            // Send all kicks (including merged) to Watch
            if let data = try? JSONEncoder().encode(allKicks) {
                replyHandler(["kicks": data, "status": "synced"])
                #if DEBUG
                logger.debug("Sent \(allKicks.count) kicks to Watch")
                #endif
            } else {
                replyHandler(["status": "error"])
            }
            return
        }

        handleIncomingMessage(message)
        replyHandler(["status": "received"])
    }

    private func handleIncomingMessage(_ message: [String : Any]) {
        // Handle kicks from Watch
        if let type = message["type"] as? String, type == "newKick",
           let id = message["id"] as? String,
           let timestampInterval = message["timestamp"] as? TimeInterval {

            #if DEBUG
            logger.debug("Received kick from Watch")
            #endif

            let sessionId = message["sessionId"] as? String
            let timestamp = Date(timeIntervalSince1970: timestampInterval)

            let kick = Kick(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId?.isEmpty == true ? nil : sessionId
            )

            // Update on main thread
            DispatchQueue.main.async {
                // Always read fresh from shared storage to ensure we have latest data
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                    #if DEBUG
                    logger.warning("Cannot access shared storage for merge")
                    #endif
                    return
                }

                var allKicks: [Kick] = []
                if let data = sharedDefaults.data(forKey: self.kicksKey),
                   let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                    allKicks = decoded
                }

                // Check if kick already exists (avoid duplicates)
                if !allKicks.contains(where: { $0.id == kick.id }) {
                    allKicks.append(kick)
                    // Sort by timestamp for consistent ordering
                    allKicks.sort { $0.timestamp < $1.timestamp }
                    // Save back to shared storage
                    if let data = try? JSONEncoder().encode(allKicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        #if DEBUG
                        logger.debug("Merged kick from Watch, total now: \(allKicks.count)")
                        #endif
                    }
                    // Update in-memory array
                    self.kicks = allKicks
                    self.objectWillChange.send()
                } else {
                    #if DEBUG
                    logger.debug("Kick already exists, skipping")
                    #endif
                }
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        #if DEBUG
        logger.debug("Received application context from Watch")
        #endif

        guard let type = applicationContext["type"] as? String else {
            #if DEBUG
            logger.warning("Received context without type field")
            #endif
            return
        }

        // Handle fullSync from Watch - merge all kicks
        if type == "fullSync",
           let kicksData = applicationContext["kicks"] as? Data,
           let watchKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) {
            #if DEBUG
            logger.debug("Received fullSync from Watch context: \(watchKicks.count) kicks")
            #endif

            DispatchQueue.main.async {
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }

                var allKicks: [Kick] = []
                if let data = sharedDefaults.data(forKey: self.kicksKey),
                   let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                    allKicks = decoded
                }

                // Merge by ID
                var mergedKicksDict: [String: Kick] = [:]
                for kick in allKicks {
                    mergedKicksDict[kick.id] = kick
                }
                for kick in watchKicks {
                    if mergedKicksDict[kick.id] == nil {
                        mergedKicksDict[kick.id] = kick
                    }
                }
                // Sort by timestamp for consistent ordering
                let mergedKicks = Array(mergedKicksDict.values).sorted { $0.timestamp < $1.timestamp }

                if let data = try? JSONEncoder().encode(mergedKicks) {
                    sharedDefaults.set(data, forKey: self.kicksKey)
                    #if DEBUG
                    logger.debug("Merged Watch context fullSync to \(mergedKicks.count) total kicks")
                    #endif
                }
                self.kicks = mergedKicks
                self.objectWillChange.send()
            }
            return
        }

        // Handle single kick from context
        if type == "newKick",
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
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                    #if DEBUG
                    logger.warning("Cannot access shared storage for context merge")
                    #endif
                    return
                }

                var allKicks: [Kick] = []
                if let data = sharedDefaults.data(forKey: self.kicksKey),
                   let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                    allKicks = decoded
                }

                // Check if kick already exists (avoid duplicates)
                if !allKicks.contains(where: { $0.id == kick.id }) {
                    allKicks.append(kick)
                    // Sort by timestamp for consistent ordering
                    allKicks.sort { $0.timestamp < $1.timestamp }
                    // Save back to shared storage
                    if let data = try? JSONEncoder().encode(allKicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        #if DEBUG
                        logger.debug("Merged kick from Watch context, total now: \(allKicks.count)")
                        #endif
                    }
                    // Update in-memory array
                    self.kicks = allKicks
                    self.objectWillChange.send()
                } else {
                    #if DEBUG
                    logger.debug("Kick already exists in context, skipping")
                    #endif
                }
            }
        }
    }
}
