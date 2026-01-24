import Foundation
import WatchConnectivity
import Combine
import os.log

private let logger = Logger(subsystem: "com.daria.BabyKickTracker.watchkitapp", category: "KickManager")

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
    @Published var isSyncing: Bool = false  // Shows loading spinner in UI
    @Published var isLoadingInitialData: Bool = false  // Blocks UI until fresh data ready
    @Published var lastSyncStatus: String = "Not synced"  // Debug: shows sync status

    private var lastSuccessfulSyncTime: Date?
    private var midnightTimer: Timer?
    private var lastKickLoggedAt: Date?
    private var isSyncingFromPhone: Bool = false  // Prevent sync loops

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
        // DON'T load data here - wait for forceRefresh() to sync with iPhone first
        // This prevents showing stale local data before sync completes
        setupMidnightTimer() // Schedule automatic reload at midnight

        // Observe shared storage changes for App Groups sync
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Skip if we're currently syncing from iPhone (prevents loop)
            guard !self.isSyncingFromPhone else {
                return
            }
            // Skip if we're loading initial data (sync in progress)
            guard !self.isLoadingInitialData else {
                return
            }
            // Reload data when shared storage changes
            self.loadData()
        }
    }

    deinit {
        midnightTimer?.invalidate()
        midnightTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func verifyAppGroupSetup() {
        #if DEBUG
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            logger.debug("App Groups configured correctly")

            // Debug: Check what's actually in shared storage
            if let data = sharedDefaults.data(forKey: kicksKey),
               let kicks = try? JSONDecoder().decode([Kick].self, from: data) {
                logger.debug("Shared storage has \(kicks.count) kicks")
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
        // Skip reload if we just logged a kick (prevent blinking)
        if let lastLogged = lastKickLoggedAt, Date().timeIntervalSince(lastLogged) < 0.5 {
            #if DEBUG
            logger.debug("Skipping reload - just logged a kick")
            #endif
            return
        }

        // Always read fresh from shared storage
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            logger.warning("Cannot access shared storage")
            #endif
            return
        }

        // Note: synchronize() is deprecated and not needed - removed

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

        #if DEBUG
        logger.debug("Loaded \(kicks.count) total, \(self.todayKickCount) today")
        #endif

        // Load active session if exists
        if let sessionData = sharedDefaults.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: sessionData) {
            if session.endTime > Date() {
                activeSession = session
                #if DEBUG
                logger.debug("Active session found: \(session.kickCount) kicks")
                #endif
            }
        }

        // Don't auto-request sync here - it causes infinite loops
        // Sync is requested only on activation or manual refresh
    }

    func logKick() {
        let kick = Kick(
            timestamp: Date(),
            sessionId: activeSession?.id
        )

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
            // Sort by timestamp for consistent ordering
            allKicks.sort { $0.timestamp < $1.timestamp }
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
            #if DEBUG
            logger.debug("Kick already exists, reloading data")
            #endif
            loadData()
        }
    }

    func manualRefresh() {
        #if DEBUG
        logger.debug("Manual refresh triggered")
        #endif
        loadData()

        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            requestFullSyncFromiPhone()
        }
    }

    /// Force refresh - bypasses debounce, always reloads and syncs
    /// Called when Watch becomes active (wrist raise)
    /// Uses blocking pattern: shows loading UI until sync completes or times out
    func forceRefresh() {
        // Must run on main thread for thread safety
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.forceRefresh() }
            return
        }

        #if DEBUG
        logger.debug("Force refresh triggered - isSyncing:\(self.isSyncingFromPhone) isLoading:\(self.isLoadingInitialData)")
        #endif

        // Skip if already syncing to avoid duplicate requests
        if isSyncingFromPhone || isLoadingInitialData {
            #if DEBUG
            logger.debug("Already syncing, skipping duplicate forceRefresh")
            #endif
            return
        }

        // Clear the debounce flag so loadData actually runs
        lastKickLoggedAt = nil

        // Set blocking state SYNCHRONOUSLY - prevents race conditions
        isLoadingInitialData = true
        isSyncing = true

        // Failsafe: auto-unblock after 3 seconds to prevent stuck UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.isLoadingInitialData == true {
                #if DEBUG
                logger.debug("Failsafe timeout (3s) - unblocking UI")
                #endif
                self?.isLoadingInitialData = false
                self?.isSyncing = false
            }
        }

        // Try iPhone sync first if reachable - this is the authoritative source
        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            #if DEBUG
            logger.debug("iPhone reachable - requesting sync")
            #endif
            lastSyncStatus = "Syncing..."
            requestFullSyncFromiPhone()
        } else if WCSession.default.activationState == .activated {
            // iPhone not reachable but WCSession is active - check receivedApplicationContext
            let receivedContext = WCSession.default.receivedApplicationContext
            #if DEBUG
            logger.debug("iPhone not reachable, checking application context (has \(receivedContext.count) keys)")
            #endif

            if let type = receivedContext["type"] as? String, type == "fullSync",
               let kicksData = receivedContext["kicks"] as? Data,
               let iPhoneKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) {
                // We have fullSync data from iPhone in the context - use it
                #if DEBUG
                logger.debug("Using cached application context: \(iPhoneKicks.count) kicks")
                #endif
                lastSyncStatus = "From context"

                DispatchQueue.main.async {
                    guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                        self.loadLocalDataAndUnblock()
                        return
                    }

                    // MERGE by kick ID - preserve local kicks that aren't on iPhone
                    var localKicks: [Kick] = []
                    if let data = sharedDefaults.data(forKey: self.kicksKey),
                       let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                        localKicks = decoded
                    }

                    // Merge: iPhone kicks first, then local (local overwrites duplicates)
                    var mergedDict: [String: Kick] = [:]
                    for kick in iPhoneKicks { mergedDict[kick.id] = kick }
                    for kick in localKicks { mergedDict[kick.id] = kick }
                    let finalKicks = Array(mergedDict.values).sorted { $0.timestamp < $1.timestamp }

                    if let data = try? JSONEncoder().encode(finalKicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                    }

                    self.updateTodayCount(from: finalKicks)
                    self.lastSyncStatus = "Context: \(self.todayKickCount) today"
                    self.isLoadingInitialData = false
                    self.isSyncing = false
                }
            } else {
                // No valid context data - fall back to local
                #if DEBUG
                logger.debug("No valid context data - loading local")
                #endif
                lastSyncStatus = "No context - local"
                loadLocalDataAndUnblock()
            }
        } else {
            // WCSession not activated yet
            #if DEBUG
            logger.debug("WCSession not activated - loading local data")
            #endif
            lastSyncStatus = "Not activated"
            loadLocalDataAndUnblock()
        }
    }

    /// Loads data from App Groups and clears the blocking state
    /// Called after sync completes/fails or when iPhone is not reachable
    private func loadLocalDataAndUnblock() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            logger.warning("Cannot access shared storage for local load")
            #endif
            DispatchQueue.main.async {
                self.isLoadingInitialData = false
                self.isSyncing = false
            }
            return
        }

        // Read kicks from shared storage
        var kicks: [Kick] = []
        if let data = sharedDefaults.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            kicks = decoded
        }

        // Calculate today's kicks
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayKicks = kicks.filter { kick in
            let kickDay = calendar.startOfDay(for: kick.timestamp)
            return calendar.isDate(kickDay, inSameDayAs: today)
        }

        // Load active session
        var session: ActiveSession? = nil
        if let sessionData = sharedDefaults.data(forKey: "activeSession"),
           let decoded = try? JSONDecoder().decode(ActiveSession.self, from: sessionData) {
            if decoded.endTime > Date() {
                session = decoded
            }
        }

        // Update UI and clear blocking state
        DispatchQueue.main.async {
            self.todayKickCount = todayKicks.count
            self.activeSession = session
            self.isLoadingInitialData = false
            self.isSyncing = false
            // Only update status if it wasn't set by sync success/failure
            if !self.lastSyncStatus.starts(with: "Synced") {
                self.lastSyncStatus = "Local: \(todayKicks.count) today"
            }
            self.objectWillChange.send()
            #if DEBUG
            logger.debug("Local data loaded and unblocked: \(todayKicks.count) kicks today")
            #endif
        }
    }

    /// Called when day changes (midnight crossed while in background)
    /// Forces a full reload to reset the count
    func handleDayChange() {
        #if DEBUG
        logger.debug("Day change detected - forcing full reload")
        #endif
        // Clear debounce
        lastKickLoggedAt = nil
        // Reschedule midnight timer for next midnight
        setupMidnightTimer()
        // Force refresh to reload data
        forceRefresh()
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
            #if DEBUG
            logger.debug("Saved \(kicks.count) kicks to shared storage")
            #endif
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
            #if DEBUG
            logger.warning("Watch Connectivity not activated, kick saved to shared storage only")
            #endif
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
            #if DEBUG
            logger.debug("Sending kick to iPhone (reachable)")
            #endif
            WCSession.default.sendMessage(kickData, replyHandler: { response in
                #if DEBUG
                logger.debug("iPhone confirmed kick receipt")
                #endif
            }) { error in
                #if DEBUG
                logger.error("Error sending kick to iPhone: \(error.localizedDescription)")
                #endif
            }
        } else {
            #if DEBUG
            logger.debug("Phone not reachable, will sync all kicks via background context")
            #endif
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
                #if DEBUG
                logger.debug("Updated application context with \(allKicks.count) total kicks")
                #endif
            } catch {
                #if DEBUG
                logger.error("Failed to update context: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension KickManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            #if DEBUG
            logger.error("WCSession activation failed: \(error.localizedDescription)")
            #endif
            DispatchQueue.main.async {
                self.lastSyncStatus = "WC activation failed"
            }
        } else {
            #if DEBUG
            logger.debug("WCSession activated with state: \(activationState.rawValue), reachable: \(session.isReachable)")
            #endif

            // Check if there's received application context from iPhone we haven't processed
            let receivedContext = session.receivedApplicationContext
            if !receivedContext.isEmpty {
                #if DEBUG
                logger.debug("Found received application context on activation")
                #endif
                // Process it as if we just received it
                self.session(session, didReceiveApplicationContext: receivedContext)
            }

            // Note: Don't trigger sync here - let forceRefresh() handle it when view appears
            // This prevents race conditions with the UI lifecycle
        }
    }

    private func requestFullSyncFromiPhone() {
        guard WCSession.default.isReachable else {
            #if DEBUG
            logger.debug("iPhone not reachable, loading from shared storage")
            #endif
            loadLocalDataAndUnblock()
            return
        }

        guard !isSyncingFromPhone else {
            #if DEBUG
            logger.debug("Already syncing, skipping request")
            #endif
            return
        }

        isSyncingFromPhone = true
        DispatchQueue.main.async {
            self.isSyncing = true
        }

        // Timeout: load local data after 5 seconds if sync doesn't complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.isSyncingFromPhone || self.isLoadingInitialData {
                #if DEBUG
                logger.debug("Sync timeout (5s) - loading local data as fallback")
                #endif
                self.lastSyncStatus = "Timeout - local data"
                self.isSyncingFromPhone = false
                self.loadLocalDataAndUnblock()
            }
        }

        #if DEBUG
        logger.debug("Requesting full sync from iPhone")
        #endif

        // Request sync from iPhone - also send our kicks so iPhone can merge
        var request: [String: Any] = ["type": "requestSync"]

        // Include Watch's kicks so iPhone can merge them
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let kicksData = sharedDefaults.data(forKey: kicksKey) {
            request["watchKicks"] = kicksData
        }

        WCSession.default.sendMessage(request, replyHandler: { [weak self] response in
            guard let self = self else { return }
            if let kicksData = response["kicks"] as? Data,
               let iPhoneKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) {
                #if DEBUG
                logger.debug("Received \(iPhoneKicks.count) kicks from iPhone sync")
                #endif
                DispatchQueue.main.async {
                    guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                        self.isSyncingFromPhone = false
                        self.loadLocalDataAndUnblock()
                        return
                    }

                    // MERGE by kick ID - preserve local kicks that aren't on iPhone yet
                    var localKicks: [Kick] = []
                    if let data = sharedDefaults.data(forKey: self.kicksKey),
                       let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                        localKicks = decoded
                    }

                    // Merge: iPhone kicks first, then local (local overwrites duplicates)
                    var mergedDict: [String: Kick] = [:]
                    for kick in iPhoneKicks { mergedDict[kick.id] = kick }
                    for kick in localKicks { mergedDict[kick.id] = kick }
                    let finalKicks = Array(mergedDict.values).sorted { $0.timestamp < $1.timestamp }

                    if let data = try? JSONEncoder().encode(finalKicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        #if DEBUG
                        logger.debug("Merged iPhone data with local: \(finalKicks.count) kicks")
                        #endif
                    }

                    // Load active session
                    if let sessionData = sharedDefaults.data(forKey: "activeSession"),
                       let session = try? JSONDecoder().decode(ActiveSession.self, from: sessionData) {
                        if session.endTime > Date() {
                            self.activeSession = session
                        }
                    }

                    self.updateTodayCount(from: finalKicks)
                    self.lastSuccessfulSyncTime = Date()
                    self.lastSyncStatus = "Synced: \(self.todayKickCount) today"
                    self.isSyncingFromPhone = false
                    self.isSyncing = false
                    self.isLoadingInitialData = false
                    #if DEBUG
                    logger.debug("Sync complete - UI unblocked with \(finalKicks.count) kicks, today: \(self.todayKickCount)")
                    #endif
                }
            } else {
                DispatchQueue.main.async {
                    self.lastSyncStatus = "No data from iPhone"
                    self.isSyncingFromPhone = false
                    // No valid data from iPhone - load local as fallback
                    self.loadLocalDataAndUnblock()
                }
            }
        }) { [weak self] error in
            #if DEBUG
            logger.error("Error requesting sync: \(error.localizedDescription)")
            #endif
            DispatchQueue.main.async {
                self?.lastSyncStatus = "Error: \(error.localizedDescription)"
                self?.isSyncingFromPhone = false
                // Sync failed - load local data as fallback
                self?.loadLocalDataAndUnblock()
            }
        }
    }

    private func updateTodayCount(from kicks: [Kick]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let count = kicks.filter { kick in
            let kickDay = calendar.startOfDay(for: kick.timestamp)
            return calendar.isDate(kickDay, inSameDayAs: today)
        }.count
        todayKickCount = count
        #if DEBUG
        logger.debug("Updated count: \(count) today")
        #endif
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone with validation
        guard let type = message["type"] as? String else {
            #if DEBUG
            logger.warning("Received message without type field")
            #endif
            return
        }

        #if DEBUG
        logger.debug("Received message from iPhone: \(type)")
        #endif

        switch type {
        case "fullSync":
            // iPhone sent all kicks - merge with local to preserve unsent Watch kicks
            guard let kicksData = message["kicks"] as? Data else {
                #if DEBUG
                logger.warning("fullSync message missing kicks data")
                #endif
                return
            }
            guard let iPhoneKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) else {
                #if DEBUG
                logger.warning("Failed to decode kicks from fullSync message")
                #endif
                return
            }
            #if DEBUG
            logger.debug("Received full sync from iPhone: \(iPhoneKicks.count) kicks")
            #endif
            DispatchQueue.main.async {
                self.isSyncingFromPhone = true
                defer { self.isSyncingFromPhone = false }
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }

                // MERGE by kick ID - preserve local kicks that aren't on iPhone yet
                var localKicks: [Kick] = []
                if let data = sharedDefaults.data(forKey: self.kicksKey),
                   let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                    localKicks = decoded
                }

                // Merge: iPhone kicks first, then local (local overwrites duplicates)
                var mergedDict: [String: Kick] = [:]
                for kick in iPhoneKicks { mergedDict[kick.id] = kick }
                for kick in localKicks { mergedDict[kick.id] = kick }
                let finalKicks = Array(mergedDict.values).sorted { $0.timestamp < $1.timestamp }

                if let data = try? JSONEncoder().encode(finalKicks) {
                    sharedDefaults.set(data, forKey: self.kicksKey)
                    #if DEBUG
                    logger.debug("Merged iPhone fullSync with local: \(finalKicks.count) kicks")
                    #endif
                }
                self.updateTodayCount(from: finalKicks)
                self.isLoadingInitialData = false
                self.isSyncing = false
            }
        case "newKick":
            // iPhone logged a kick - merge it directly from the message
            // Validate required fields
            guard let id = message["id"] as? String,
                  let timestampInterval = message["timestamp"] as? TimeInterval else {
                #if DEBUG
                logger.warning("newKick message missing required fields")
                #endif
                return
            }

            // Validate timestamp is reasonable (not in far future or past)
            let timestamp = Date(timeIntervalSince1970: timestampInterval)
            let now = Date()
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
            let oneDayFromNow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

            guard timestamp > oneYearAgo && timestamp < oneDayFromNow else {
                #if DEBUG
                logger.warning("newKick has invalid timestamp")
                #endif
                return
            }

            let sessionId = message["sessionId"] as? String
            let kick = Kick(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId?.isEmpty == true ? nil : sessionId
            )

            DispatchQueue.main.async {
                // Load current kicks from shared storage
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                    #if DEBUG
                    logger.warning("Cannot access shared storage for merge")
                    #endif
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
                    // Sort by timestamp for consistent ordering
                    kicks.sort { $0.timestamp < $1.timestamp }
                    // Save back to shared storage
                    if let data = try? JSONEncoder().encode(kicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        #if DEBUG
                        logger.debug("Merged kick from iPhone message, total now: \(kicks.count)")
                        #endif
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
                    #if DEBUG
                    logger.debug("UI update triggered - count: \(self.todayKickCount)")
                    #endif
                } else {
                    #if DEBUG
                    logger.debug("Kick already exists, skipping")
                    #endif
                }
            }
        case "sessionUpdate":
            guard let sessionId = message["sessionId"] as? String,
                  let kickCount = message["kickCount"] as? Int,
                  let endTimeInterval = message["endTime"] as? TimeInterval else {
                #if DEBUG
                logger.warning("sessionUpdate message missing required fields")
                #endif
                return
            }
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
        case "sessionEnded":
            DispatchQueue.main.async {
                self.activeSession = nil
                self.defaults.removeObject(forKey: "activeSession")
                // Reload data to ensure sync
                self.loadData()
            }
        default:
            #if DEBUG
            logger.debug("Unknown message type: \(type)")
            #endif
            break
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Handle background updates from iPhone with validation
        #if DEBUG
        logger.debug("Received application context from iPhone")
        #endif

        guard let type = applicationContext["type"] as? String else {
            #if DEBUG
            logger.warning("Received context without type field")
            #endif
            return
        }

        // Handle full sync from context
        if type == "fullSync" {
            guard let kicksData = applicationContext["kicks"] as? Data,
                  let iPhoneKicks = try? JSONDecoder().decode([Kick].self, from: kicksData) else {
                #if DEBUG
                logger.warning("Failed to decode kicks from context fullSync")
                #endif
                return
            }

            // Check timestamp - if context is older than 24 hours, prefer local data
            if let timestamp = applicationContext["timestamp"] as? TimeInterval {
                let contextDate = Date(timeIntervalSince1970: timestamp)
                let hoursOld = Date().timeIntervalSince(contextDate) / 3600
                if hoursOld > 24 {
                    #if DEBUG
                    logger.debug("Context is \(Int(hoursOld)) hours old - preferring local data")
                    #endif
                    return
                }
            }

            #if DEBUG
            logger.debug("Received full sync from iPhone context: \(iPhoneKicks.count) kicks")
            #endif
            DispatchQueue.main.async {
                self.isSyncingFromPhone = true
                defer { self.isSyncingFromPhone = false }
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }

                // MERGE by kick ID - preserve local kicks that aren't on iPhone yet
                var localKicks: [Kick] = []
                if let data = sharedDefaults.data(forKey: self.kicksKey),
                   let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
                    localKicks = decoded
                }

                // Merge: iPhone kicks first, then local (local overwrites duplicates)
                var mergedDict: [String: Kick] = [:]
                for kick in iPhoneKicks { mergedDict[kick.id] = kick }
                for kick in localKicks { mergedDict[kick.id] = kick }
                let finalKicks = Array(mergedDict.values).sorted { $0.timestamp < $1.timestamp }

                if let data = try? JSONEncoder().encode(finalKicks) {
                    sharedDefaults.set(data, forKey: self.kicksKey)
                    #if DEBUG
                    logger.debug("Merged iPhone context fullSync with local: \(finalKicks.count) kicks")
                    #endif
                }
                self.updateTodayCount(from: finalKicks)
                self.isLoadingInitialData = false
                self.isSyncing = false
            }
            return
        }

        // Handle kick from context - merge directly to avoid App Groups delays
        if type == "newKick" {
            guard let id = applicationContext["id"] as? String,
                  let timestampInterval = applicationContext["timestamp"] as? TimeInterval else {
                #if DEBUG
                logger.warning("newKick context missing required fields")
                #endif
                return
            }

            // Validate timestamp is reasonable
            let timestamp = Date(timeIntervalSince1970: timestampInterval)
            let now = Date()
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
            let oneDayFromNow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

            guard timestamp > oneYearAgo && timestamp < oneDayFromNow else {
                #if DEBUG
                logger.warning("newKick context has invalid timestamp")
                #endif
                return
            }

            let sessionId = applicationContext["sessionId"] as? String
            let kick = Kick(
                id: id,
                timestamp: timestamp,
                sessionId: sessionId?.isEmpty == true ? nil : sessionId
            )

            DispatchQueue.main.async {
                // Load current kicks from shared storage
                guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                    #if DEBUG
                    logger.warning("Cannot access shared storage for context merge")
                    #endif
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
                    // Sort by timestamp for consistent ordering
                    kicks.sort { $0.timestamp < $1.timestamp }
                    // Save back to shared storage
                    if let data = try? JSONEncoder().encode(kicks) {
                        sharedDefaults.set(data, forKey: self.kicksKey)
                        #if DEBUG
                        logger.debug("Merged kick from iPhone context, total now: \(kicks.count)")
                        #endif
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
                    #if DEBUG
                    logger.debug("UI update triggered from context - count: \(self.todayKickCount)")
                    #endif
                } else {
                    #if DEBUG
                    logger.debug("Kick already exists in context, skipping")
                    #endif
                }
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
