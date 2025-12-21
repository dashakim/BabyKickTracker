# Complete Xcode Setup Guide - Native iPhone + Watch App

Since you want a native app (not Expo Go) with Apple Watch support, here's the complete setup.

## Why This Approach?

- **No Expo Go needed** - Your own native app
- **Apple Watch integration** - Full Watch app support
- **One Xcode project** - Manages both iPhone and Watch apps
- **Can still use React Native code** - But wrapped in native

## Two Options

### Option 1: Pure Native (Recommended for Watch integration)

Build everything in Xcode with Swift + SwiftUI. Your React screens can be rebuilt in SwiftUI (it's actually quite similar to React!).

**Pros:**
- Best Watch integration
- Native performance
- No Expo complications
- SwiftUI is similar to React (components, state, etc.)

**Cons:**
- Need to learn Swift/SwiftUI basics
- More iOS-specific

### Option 2: React Native CLI + Watch App

Use React Native (without Expo) for iPhone, native Swift for Watch.

**Pros:**
- Keep using React/JavaScript
- Still get Watch app

**Cons:**
- More complex setup
- Two different codebases

---

## Let's Do Option 1: Full Native Setup

Since you already have the Watch app code ready, let's build it all in Xcode.

### Step 1: Create Xcode Project

1. **Open Xcode**

2. **Create New Project**:
   - File → New → Project
   - Select **"iOS App"**
   - Click Next

3. **Project Settings**:
   - Product Name: `BabyKickTracker`
   - Team: Select your Apple ID
   - Organization Identifier: `com.yourname` (or any reverse domain)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we'll use UserDefaults)
   - Click Next
   - Save Location: `/Users/dariatabala/nonproj/baby_kick/BabyKickTracker/`

### Step 2: Add Apple Watch Target

1. **Add Watch App**:
   - In Xcode, go to File → New → Target
   - Select **"Watch App"**
   - Product Name: `BabyKickWatch`
   - Click Finish
   - When prompted "Activate scheme?", click **Activate**

2. **File Structure** (Xcode will create):
   ```
   BabyKickTracker/
   ├── BabyKickTracker/          # iPhone app
   ├── BabyKickWatch Watch App/   # Watch app
   └── BabyKickTracker.xcodeproj
   ```

### Step 3: Build iPhone App (SwiftUI)

I'll create the SwiftUI versions of the screens for you. The good news: SwiftUI is very similar to React!

**Comparison:**
```javascript
// React
function HomeScreen() {
  const [count, setCount] = useState(0);
  return <Button onPress={() => setCount(count + 1)}>Tap</Button>;
}
```

```swift
// SwiftUI
struct HomeScreen: View {
  @State private var count = 0
  var body: some View {
    Button("Tap") { count += 1 }
  }
}
```

Let me create the complete iPhone app SwiftUI files...

### Step 4: Files to Create

#### iPhone App Files

**ContentView.swift** (Main Navigation):
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "timer")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
        }
        .accentColor(.pink)
    }
}
```

**Models.swift** (Data structures):
```swift
import Foundation

struct Kick: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let sessionId: String?

    init(timestamp: Date = Date(), sessionId: String? = nil) {
        self.id = UUID().uuidString
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
```

**KickStorage.swift** (Data persistence):
```swift
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
```

**HomeView.swift** (Main kick logging screen):
```swift
import SwiftUI

struct HomeView: View {
    @StateObject private var storage = KickStorage.shared
    @State private var justTapped = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Active session banner
                    if let session = storage.activeSession {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active 2-Hour Session")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\\(session.kicks.count) kicks in this session")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            Text("Ends at \\(session.endTime, style: .time)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Main tap button
                    Button(action: logKick) {
                        VStack(spacing: 8) {
                            Text("TAP")
                                .font(.system(size: 48, weight: .bold))
                            Text("when baby kicks")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(width: 200, height: 200)
                        .background(
                            Circle()
                                .fill(justTapped ? Color.green : Color.pink)
                        )
                        .scaleEffect(justTapped ? 1.1 : 1.0)
                        .shadow(radius: 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 30)

                    // Stats
                    HStack(spacing: 15) {
                        StatBox(number: storage.todayKicks.count, label: "Today")
                        StatBox(number: storage.kicks.count, label: "Total")
                    }
                    .padding(.horizontal)

                    // Recent kicks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Kicks")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if storage.kicks.isEmpty {
                            Text("No kicks logged yet")
                                .foregroundColor(.gray)
                                .italic()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(Array(storage.kicks.suffix(5).reversed())) { kick in
                                HStack {
                                    Text(kick.timestamp, style: .time)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(kick.timestamp, style: .date)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Baby Kick Tracker")
        }
    }

    private func logKick() {
        let kick = Kick(
            timestamp: Date(),
            sessionId: storage.activeSession?.id
        )
        storage.saveKick(kick)

        // Visual feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            justTapped = true
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                justTapped = false
            }
        }
    }
}

struct StatBox: View {
    let number: Int
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text("\\(number)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.pink)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 3)
    }
}
```

**SessionsView.swift** & **HistoryView.swift** - I can provide these too if you want!

### Step 5: Add Watch App Files

Use the 3 Swift files I already created:
- `BabyKickWatchApp.swift`
- `ContentView.swift` (for Watch)
- `KickManager.swift`

Just drag them into the `BabyKickWatch Watch App` folder in Xcode.

### Step 6: Enable Watch Connectivity

For iPhone and Watch to sync:

1. **iPhone Target**:
   - Select BabyKickTracker target
   - Signing & Capabilities
   - Add: Background Modes
   - Enable: Background fetch

2. **Watch Target**:
   - Select BabyKickWatch target
   - Signing & Capabilities
   - Add: Background Modes

### Step 7: Build and Run

1. **Connect your iPhone** (paired with Watch)
2. **Select target**: BabyKickWatch (should show iPhone + Watch)
3. **Click Run** (⌘R)
4. Apps install on both devices!

---

## Next Steps

Want me to:
1. Create ALL the SwiftUI files for you (complete iPhone app)?
2. Help set up the Xcode project now?
3. Create a simpler version to start with?

The full SwiftUI app will be ~300 lines total vs the React Native version which needs much more setup for Watch integration!
