import Foundation
import WatchConnectivity
import Combine

struct Kick: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let sessionId: String?
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

    private let defaults = UserDefaults.standard
    private let kicksKey = "watch_kicks"

    override private init() {
        super.init()
        setupWatchConnectivity()
    }

    func loadData() {
        // Load today's kick count
        let kicks = loadKicks()
        let today = Calendar.current.startOfDay(for: Date())
        todayKickCount = kicks.filter { kick in
            Calendar.current.startOfDay(for: kick.timestamp) == today
        }.count

        // Load active session from defaults (synced from phone)
        if let sessionData = defaults.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: sessionData) {
            // Check if session is still active
            if session.endTime > Date() {
                activeSession = session
            }
        }
    }

    func logKick() {
        let kick = Kick(
            id: UUID().uuidString,
            timestamp: Date(),
            sessionId: activeSession?.id
        )

        // Save locally
        var kicks = loadKicks()
        kicks.append(kick)
        saveKicks(kicks)

        // Update today's count
        todayKickCount += 1

        // Send to iPhone
        sendKickToPhone(kick)
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
        guard WCSession.default.isReachable else {
            print("Phone not reachable, kick saved locally")
            return
        }

        let kickData: [String: Any] = [
            "type": "newKick",
            "id": kick.id,
            "timestamp": kick.timestamp.timeIntervalSince1970,
            "sessionId": kick.sessionId ?? ""
        ]

        WCSession.default.sendMessage(kickData, replyHandler: nil) { error in
            print("Error sending kick to phone: \(error.localizedDescription)")
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
        // Handle messages from iPhone (like active session updates)
        if let type = message["type"] as? String {
            switch type {
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
                    }
                }
            case "sessionEnded":
                DispatchQueue.main.async {
                    self.activeSession = nil
                    self.defaults.removeObject(forKey: "activeSession")
                }
            default:
                break
            }
        }
    }
}
