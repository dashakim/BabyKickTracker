# Quick Xcode Setup - 5 Minutes to Working App!

## What You'll Get
- Native iPhone app with baby kick tracking
- Apple Watch app that syncs to iPhone
- NO Expo Go required

## Setup Steps

### 1. Create Project (2 minutes)

Open Xcode and:
```
File → New → Project
  → iOS → App
  → Product Name: "BabyKickTracker"
  → Interface: SwiftUI
  → Language: Swift
  → Save to: /Users/dariatabala/nonproj/baby_kick/BabyKickTracker/
```

### 2. Add iPhone App Files (1 minute)

Drag ALL 7 files from `SwiftUI_Files/` folder into Xcode's `BabyKickTracker` group:
- ✅ BabyKickTrackerApp.swift
- ✅ ContentView.swift
- ✅ HomeView.swift
- ✅ SessionsView.swift
- ✅ HistoryView.swift
- ✅ Models.swift
- ✅ KickStorage.swift

Make sure "Copy items if needed" is checked!

### 3. Add Watch App (2 minutes)

```
File → New → Target
  → Watch App
  → Product Name: "BabyKickWatch"
  → Finish
```

Delete the auto-generated Watch files, then drag these 3 files from `ios/BabyKickWatch/`:
- ✅ BabyKickWatchApp.swift
- ✅ ContentView.swift
- ✅ KickManager.swift

### 4. Run It!

```
1. Connect your iPhone
2. Select "BabyKickTracker" scheme at the top
3. Click the Play button (or press ⌘R)
```

App installs on your iPhone in ~30 seconds!

For Watch app:
```
1. Select "BabyKickWatch" scheme
2. Make sure iPhone is paired with Watch
3. Click Play (⌘R)
```

## That's It!

You now have:
- ✅ Native iPhone app
- ✅ Apple Watch app
- ✅ Both apps syncing data
- ✅ NO Expo Go needed

## Test It

1. **On iPhone**: Tap the pink button → kick is logged
2. **On Watch**: Tap the button on your wrist → kick syncs to iPhone
3. **Start a session**: Go to Sessions tab → Start Session
4. **View history**: Go to History tab → See all kicks

## Troubleshooting

**"Cannot run on device"**
- Select your Apple ID in Xcode → Preferences → Accounts
- Select your device from the device dropdown

**"Watch app won't install"**
- Make sure Watch is paired and unlocked
- Make sure both devices have Bluetooth on

**"Files not found"**
- Make sure you saved the Xcode project in the correct folder
- Check that all files are added to the target (check boxes in File Inspector)

## Optional: Enable Watch Connectivity

For full sync between iPhone and Watch, add these capabilities:

**iPhone Target**:
```
Target → Signing & Capabilities
  → + Capability → Background Modes
  → Check: Background fetch
```

**Watch Target**:
```
Target → Signing & Capabilities
  → + Capability → Background Modes
```

---

**Need help?** Check `XCODE_SETUP_GUIDE.md` for detailed instructions or `SUMMARY.md` for all options!
