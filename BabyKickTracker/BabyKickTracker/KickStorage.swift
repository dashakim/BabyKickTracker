import Foundation
import Combine

class KickStorage: ObservableObject {
    static let shared = KickStorage()

    @Published var kicks: [Kick] = []
    @Published var sessions: [MealSession] = []

    private let kicksKey = "baby_kicks"
    private let sessionsKey = "meal_sessions"

    private init() {
        loadData()
    }

    func loadData() {
        // Load kicks
        if let data = UserDefaults.standard.data(forKey: kicksKey),
           let decoded = try? JSONDecoder().decode([Kick].self, from: data) {
            kicks = decoded
        }

        // Load sessions
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([MealSession].self, from: data) {
            sessions = decoded
        }
    }

    func saveKick(_ kick: Kick) {
        kicks.append(kick)
        if let encoded = try? JSONEncoder().encode(kicks) {
            UserDefaults.standard.set(encoded, forKey: kicksKey)
        }

        // Add to active session if exists
        if let index = sessions.firstIndex(where: { $0.isActive && $0.id == kick.sessionId }) {
            sessions[index].kicks.append(kick)
            saveSessions()
        }

        // Notify objectWillChange for UI updates
        objectWillChange.send()
    }

    func startSession(mealTime: Date = Date()) -> MealSession {
        let session = MealSession(mealTime: mealTime)
        sessions.append(session)
        saveSessions()
        return session
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
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
}
