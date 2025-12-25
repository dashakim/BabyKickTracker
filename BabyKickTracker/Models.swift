import Foundation

struct Kick: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let sessionId: String?

    init(id: String = UUID().uuidString, timestamp: Date = Date(), sessionId: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
    }
}

struct MealSession: Identifiable, Codable {
    let id: String
    let mealTime: Date
    let startTime: Date
    let endTime: Date
    var kicks: [Kick]

    init(mealTime: Date = Date()) {
        self.id = UUID().uuidString
        self.mealTime = mealTime
        self.startTime = mealTime
        self.endTime = mealTime.addingTimeInterval(2 * 60 * 60) // 2 hours
        self.kicks = []
    }

    var isActive: Bool {
        return endTime > Date()
    }
}
