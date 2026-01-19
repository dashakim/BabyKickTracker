import Foundation
import CloudKit

class CloudKitMigrator {
    static let shared = CloudKitMigrator()

    private let migrationKey = "didMigrateToCloudKit_v1"
    private let appGroupIdentifier = "group.com.daria.BabyKickTracker"

    private init() {}

    func migrateToCloudKitIfNeeded() async throws {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("☁️ Cannot access App Groups for migration")
            return
        }

        // Check if already migrated
        guard !defaults.bool(forKey: migrationKey) else {
            print("☁️ Already migrated to CloudKit")
            return
        }

        print("☁️ Starting CloudKit migration...")

        // Check if user is signed in to iCloud
        guard CloudKitManager.shared.isOnline else {
            print("⚠️ Cannot migrate - not signed in to iCloud")
            return
        }

        // Load existing data from App Groups
        let kicks = loadKicksFromAppGroups(defaults)
        let sessions = loadSessionsFromAppGroups(defaults)
        let babyName = defaults.string(forKey: "baby_name") ?? ""

        print("☁️ Found \(kicks.count) kicks, \(sessions.count) sessions to migrate")

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
        print("☁️ Migration complete!")
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

    // Reset migration (for testing purposes)
    func resetMigration() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: migrationKey)
        print("☁️ Migration reset")
    }
}
