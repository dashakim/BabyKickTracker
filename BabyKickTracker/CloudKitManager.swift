import Foundation
import CloudKit
import Combine

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    @Published var syncState: SyncState = .idle
    @Published var lastSyncDate: Date?
    @Published var isOnline: Bool = true

    private let container: CKContainer
    private let privateDB: CKDatabase

    enum SyncState {
        case idle
        case syncing
        case error(String)
    }

    private init() {
        self.container = CKContainer(identifier: "iCloud.com.daria.BabyKickTracker")
        self.privateDB = container.privateCloudDatabase

        // Check account status
        checkAccountStatus()
    }

    // MARK: - Account Status

    private func checkAccountStatus() {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("☁️ iCloud account available")
                    self.isOnline = true
                case .noAccount:
                    print("⚠️ No iCloud account")
                    self.syncState = .error("Please sign in to iCloud")
                    self.isOnline = false
                case .restricted:
                    print("⚠️ iCloud account restricted")
                    self.syncState = .error("iCloud access is restricted")
                    self.isOnline = false
                case .couldNotDetermine:
                    print("⚠️ Could not determine iCloud status")
                    self.isOnline = false
                case .temporarilyUnavailable:
                    print("⚠️ iCloud temporarily unavailable")
                    self.isOnline = false
                @unknown default:
                    print("⚠️ Unknown iCloud status")
                    self.isOnline = false
                }
            }
        }
    }

    // MARK: - Save Operations

    func saveKick(_ kick: Kick) async throws {
        guard isOnline else {
            print("☁️ Offline - kick will sync later")
            return
        }

        let record = CKRecord(recordType: "Kick", recordID: CKRecord.ID(recordName: kick.id))
        record["id"] = kick.id
        record["timestamp"] = kick.timestamp
        if let sessionId = kick.sessionId {
            record["sessionId"] = sessionId
        }

        do {
            _ = try await privateDB.save(record)
            print("☁️ Kick saved to CloudKit: \(kick.id)")
        } catch {
            print("❌ Failed to save kick to CloudKit: \(error.localizedDescription)")
            throw error
        }
    }

    func saveSession(_ session: MealSession) async throws {
        guard isOnline else {
            print("☁️ Offline - session will sync later")
            return
        }

        let record = CKRecord(recordType: "MealSession", recordID: CKRecord.ID(recordName: session.id))
        record["id"] = session.id
        record["mealTime"] = session.mealTime
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime

        do {
            _ = try await privateDB.save(record)
            print("☁️ Session saved to CloudKit: \(session.id)")
        } catch {
            print("❌ Failed to save session to CloudKit: \(error.localizedDescription)")
            throw error
        }
    }

    func saveBabyName(_ name: String) async throws {
        guard isOnline else {
            print("☁️ Offline - name will sync later")
            return
        }

        // Use a fixed record ID for user profile
        let recordID = CKRecord.ID(recordName: "UserProfile")

        do {
            // Try to fetch existing record first
            let existingRecord = try? await privateDB.record(for: recordID)
            let record = existingRecord ?? CKRecord(recordType: "UserProfile", recordID: recordID)
            record["babyName"] = name
            record["lastUpdated"] = Date()

            _ = try await privateDB.save(record)
            print("☁️ Baby name saved to CloudKit")
        } catch {
            print("❌ Failed to save baby name: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Fetch Operations

    func fetchAllKicks() async throws -> [Kick] {
        guard isOnline else {
            print("☁️ Offline - returning empty array")
            return []
        }

        let query = CKQuery(recordType: "Kick", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let result = try await privateDB.records(matching: query)
            let kicks = result.matchResults.compactMap { _, result -> Kick? in
                guard let record = try? result.get() else { return nil }
                return kickFromRecord(record)
            }
            print("☁️ Fetched \(kicks.count) kicks from CloudKit")
            return kicks
        } catch {
            print("❌ Failed to fetch kicks: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchAllSessions() async throws -> [MealSession] {
        guard isOnline else {
            print("☁️ Offline - returning empty array")
            return []
        }

        let query = CKQuery(recordType: "MealSession", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "mealTime", ascending: false)]

        do {
            let result = try await privateDB.records(matching: query)
            let sessions = result.matchResults.compactMap { _, result -> MealSession? in
                guard let record = try? result.get() else { return nil }
                return sessionFromRecord(record)
            }
            print("☁️ Fetched \(sessions.count) sessions from CloudKit")
            return sessions
        } catch {
            print("❌ Failed to fetch sessions: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchBabyName() async throws -> String? {
        guard isOnline else {
            print("☁️ Offline - returning nil")
            return nil
        }

        let recordID = CKRecord.ID(recordName: "UserProfile")

        do {
            let record = try await privateDB.record(for: recordID)
            return record["babyName"] as? String
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist yet - this is normal for new users
            print("☁️ No baby name in CloudKit yet")
            return nil
        } catch {
            print("❌ Failed to fetch baby name: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Batch Operations

    func saveMultipleKicks(_ kicks: [Kick]) async throws {
        guard isOnline else {
            print("☁️ Offline - kicks will sync later")
            return
        }

        let records = kicks.map { kick -> CKRecord in
            let record = CKRecord(recordType: "Kick", recordID: CKRecord.ID(recordName: kick.id))
            record["id"] = kick.id
            record["timestamp"] = kick.timestamp
            if let sessionId = kick.sessionId {
                record["sessionId"] = sessionId
            }
            return record
        }

        // Process in batches of 100 (CloudKit limit is 400)
        let batchSize = 100
        for i in stride(from: 0, to: records.count, by: batchSize) {
            let end = min(i + batchSize, records.count)
            let batch = Array(records[i..<end])

            do {
                _ = try await privateDB.modifyRecords(saving: batch, deleting: [])
                print("☁️ Saved batch \(i/batchSize + 1): \(batch.count) kicks")
            } catch {
                print("❌ Failed to save batch: \(error.localizedDescription)")
                throw error
            }
        }

        print("☁️ Saved \(records.count) kicks to CloudKit")
    }

    // MARK: - Helper Methods

    private func kickFromRecord(_ record: CKRecord) -> Kick? {
        guard let id = record["id"] as? String,
              let timestamp = record["timestamp"] as? Date else {
            return nil
        }

        let sessionId = record["sessionId"] as? String
        return Kick(id: id, timestamp: timestamp, sessionId: sessionId)
    }

    private func sessionFromRecord(_ record: CKRecord) -> MealSession? {
        guard let id = record["id"] as? String,
              let mealTime = record["mealTime"] as? Date,
              let startTime = record["startTime"] as? Date,
              let endTime = record["endTime"] as? Date else {
            return nil
        }

        // Create session with existing data
        var session = MealSession(mealTime: mealTime)
        // Note: MealSession doesn't allow modifying these properties after init
        // This is a limitation we'll need to handle
        return session
    }

    // MARK: - Sync

    func syncAll() async {
        guard isOnline else {
            print("☁️ Offline - skipping sync")
            return
        }

        await MainActor.run {
            syncState = .syncing
        }

        do {
            // This will be called by KickStorage after migration
            print("☁️ Sync started")

            await MainActor.run {
                syncState = .idle
                lastSyncDate = Date()
            }
        } catch {
            await MainActor.run {
                syncState = .error(error.localizedDescription)
            }
        }
    }
}
