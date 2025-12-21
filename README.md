# Baby Kick Tracker

A pregnancy tracking app to monitor baby kicks with both iPhone and Apple Watch support.

## Features

### iPhone App (React Native + Expo)
- **Quick Kick Logging**: Large tap button to instantly record kicks
- **2-Hour Meal Sessions**: Track kicks within 2-hour windows after meals
- **History & Patterns**: View all kicks grouped by day, or view meal sessions
- **Statistics**: See today's kicks, total kicks, and patterns over time
- **Beautiful UI**: Pink-themed, pregnancy-friendly interface

### Apple Watch App (Native SwiftUI)
- **One-Tap Logging**: Big button on your wrist - tap when baby kicks
- **Active Session Indicator**: See when you're in a 2-hour tracking session
- **Today's Count**: Quick glance at kicks logged today
- **Haptic Feedback**: Tactile confirmation when you log a kick
- **Auto-Sync**: Kicks sync automatically to your iPhone

## Project Structure

```
BabyKickTracker/
├── App.tsx                     # Main app with navigation
├── src/
│   ├── screens/
│   │   ├── HomeScreen.tsx      # Main kick logging screen
│   │   ├── HistoryScreen.tsx   # View past kicks and sessions
│   │   └── SessionsScreen.tsx  # Manage 2-hour meal sessions
│   ├── storage/
│   │   └── kickStorage.ts      # AsyncStorage data layer
│   └── types/
│       └── index.ts            # TypeScript type definitions
├── ios/
│   └── BabyKickWatch/          # Apple Watch app
│       ├── BabyKickWatchApp.swift
│       ├── ContentView.swift
│       └── KickManager.swift
└── package.json
```

## Getting Started

### iPhone App

1. **Install dependencies**:
   ```bash
   cd BabyKickTracker
   npm install
   ```

2. **Run on iOS Simulator**:
   ```bash
   npm run ios
   ```

3. **Run on your iPhone**:
   - Install the Expo Go app from the App Store
   - Run: `npm start`
   - Scan the QR code with your iPhone camera

### Apple Watch App Setup

The Watch app requires Xcode to build and deploy. Here's how to set it up:

1. **Open Xcode** (must have Xcode 14+ installed)

2. **Create Watch App in Xcode**:
   - Open Xcode
   - File → New → Target
   - Select "Watch App"
   - Product Name: "BabyKickWatch"
   - Interface: SwiftUI
   - Language: Swift
   - Click Finish

3. **Copy Watch App Files**:
   - Replace the generated files in the Watch target with:
     - `ios/BabyKickWatch/BabyKickWatchApp.swift`
     - `ios/BabyKickWatch/ContentView.swift`
     - `ios/BabyKickWatch/KickManager.swift`

4. **Build and Run**:
   - Select your iPhone + Watch as the target
   - Click Run (⌘R)
   - The Watch app will install on your Watch

## How It Works

### Data Flow

1. **Logging a Kick**:
   - Tap button on iPhone or Watch
   - Kick is saved with timestamp
   - If there's an active 2-hour session, kick is associated with it
   - Watch sends kick to iPhone via Watch Connectivity

2. **2-Hour Meal Sessions**:
   - Start a session after eating
   - All kicks for the next 2 hours are tracked together
   - Session info syncs to Watch so it knows to associate kicks
   - After 2 hours, session ends automatically

3. **Data Persistence**:
   - iPhone: AsyncStorage (React Native)
   - Watch: UserDefaults
   - Sync: Watch Connectivity framework

### Watch ↔ iPhone Sync

The apps communicate using Apple's Watch Connectivity framework:

- **Watch → iPhone**: Sends kick data immediately when logged
- **iPhone → Watch**: Sends active session updates when sessions start/end

## Next Steps

### Required for Full Watch Integration:

1. **Set up Xcode Project**:
   - You'll need to create the Watch app target in Xcode
   - The Swift files are ready, but need to be added to an Xcode project

2. **Enable Watch Connectivity on iPhone**:
   - Currently, the iPhone app doesn't have Watch Connectivity set up
   - This requires adding a native module or using Expo's native capabilities

3. **Testing**:
   - Test on actual iPhone + Watch (simulator has limited WatchConnectivity)
   - Verify kicks sync from Watch to iPhone
   - Test session start/end sync

### Optional Enhancements:

- **Notifications**: Remind to track kicks if baby hasn't moved in a while
- **Complications**: Show today's kick count on Watch face
- **Charts**: Visualize kick patterns over days/weeks
- **Export**: Generate PDF reports for doctor visits
- **iCloud Sync**: Sync data across devices

## Development Commands

```bash
# Install dependencies
npm install

# Start development server
npm start

# Run on iOS
npm run ios

# Run on Android (if needed)
npm run android

# Run on web
npm run web
```

## Tech Stack

- **iPhone**: React Native, Expo, TypeScript
- **Watch**: SwiftUI, Swift, WatchKit
- **Storage**: AsyncStorage (iPhone), UserDefaults (Watch)
- **Sync**: Watch Connectivity Framework
- **Navigation**: React Navigation
- **UI**: React Native components, custom styling

## Troubleshooting

### iPhone App

- **App won't start**: Try `rm -rf node_modules && npm install`
- **AsyncStorage errors**: Make sure `@react-native-async-storage/async-storage` is installed

### Watch App

- **Watch app not appearing**: Make sure Watch is paired and unlocked
- **Sync not working**: Check both apps are running and Watch Connectivity is active
- **Build errors**: Ensure Xcode 14+ and watchOS 9+ deployment target

## Notes

- The iPhone app works standalone without the Watch app
- The Watch app requires the iPhone app to view full history
- Kicks logged on Watch are cached locally if iPhone isn't reachable
- All timestamps use the device's local time zone

---

Built with ❤️ for expecting parents
