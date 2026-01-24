import Foundation
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.daria.BabyKickTracker", category: "CloudKitMigrator")

class CloudKitMigrator {
    static let shared = CloudKitMigrator()

    private let migrationKey = "didMigrateToCloudKit_v1"
    private let appGroupIdentifier = "group.com.daria.BabyKickTracker"

    private init() {}

    func migrateToCloudKitIfNeeded() async throws {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            logger.warning("Cannot access App Groups for migration")
            #endif
            return
        }

        // Check if already migrated
        guard !defaults.bool(forKey: migrationKey) else {
            #if DEBUG
            logger.debug("Already migrated to CloudKit")
            #endif
            return
        }

        #if DEBUG
        logger.debug("Starting CloudKit migration...")
        #endif

        // Check if user is signed in to iCloud
        guard CloudKitManager.shared.isOnline else {
            #if DEBUG
            logger.warning("Cannot migrate - not signed in to iCloud")
            #endif
            return
        }

        // Load existing data from App Groups
        let kicks = loadKicksFromAppGroups(defaults)
        let sessions = loadSessionsFromAppGroups(defaults)
        let babyName = defaults.string(forKey: "baby_name") ?? ""

        #if DEBUG
        logger.debug("Found \(kicks.count) kicks, \(sessions.count) sessions to migrate")
        #endif

        // Upload to CloudKit
        if !kicks.isEmpty {
            try await CloudKitManager.shared.saveMultipleKicks(kicks)
        }

        if !sessions.isEmpty {
            for session in sessions {
                try await CloudKitManager.shared.saveSession(session)
            }
        }

        if !babyName.isEmpty {
            try await CloudKitManager.shared.saveBabyName(babyName)
        }

        // Mark migration as complete
        defaults.set(true, forKey: migrationKey)
        #if DEBUG
        logger.debug("Migration complete!")
        #endif
    }

    private func loadKicksFromAppGroups(_ defaults: UserDefaults) -> [Kick] {
        guard let data = defaults.data(forKey: "baby_kicks"),
              let kicks = try? JSONDecoder().decode([Kick].self, from: data) else {
            return []
        }
        return kicks
    }

    private func loadSessionsFromAppGroups(_ defaults: UserDefaults) -> [MealSession] {
        guard let data = defaults.data(forKey: "meal_sessions"),
              let sessions = try? JSONDecoder().decode([MealSession].self, from: data) else {
            return []
        }
        return sessions
    }

    #if DEBUG
    // Reset migration (for testing purposes only - not available in production)
    func resetMigration() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: migrationKey)
        logger.debug("Migration reset")
    }
    #endif
}
