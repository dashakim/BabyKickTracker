# Quick Start Guide

## Try the iPhone App Right Now

1. **Start the app**:
   ```bash
   cd BabyKickTracker
   npm start
   ```

2. **Run on iOS Simulator** (if you have Xcode):
   - Press `i` in the terminal
   - Or run: `npm run ios`

3. **Run on your iPhone**:
   - Install "Expo Go" from the App Store
   - Scan the QR code shown in the terminal with your camera
   - The app will open in Expo Go

## What You Can Do Immediately

- Tap the big pink button to log kicks
- View your kick history in the History tab
- Start a 2-hour meal session in the Sessions tab

## Setting Up the Apple Watch App

The Watch app requires more setup since it's native Swift code. Here's what you need to do:

### Prerequisites
- macOS with Xcode 14+ installed
- iPhone and Apple Watch paired and connected
- Apple Developer account (free tier works)

### Steps

1. **Open Xcode**

2. **Create a new Xcode Project**:
   - File → New → Project
   - Choose "iOS App"
   - Product Name: "BabyKickTracker"
   - Interface: SwiftUI
   - Language: Swift
   - Save in: `BabyKickTracker/ios/`

3. **Add Watch App Target**:
   - In Xcode, File → New → Target
   - Select "Watch App"
   - Product Name: "BabyKickWatch"
   - Interface: SwiftUI
   - Click Finish

4. **Replace Watch App Files**:
   - Delete the generated files in BabyKickWatch folder
   - Add your 3 Swift files:
     - `ios/BabyKickWatch/BabyKickWatchApp.swift`
     - `ios/BabyKickWatch/ContentView.swift`
     - `ios/BabyKickWatch/KickManager.swift`

5. **Enable Watch Connectivity**:
   - Select the BabyKickWatch target
   - Go to "Signing & Capabilities"
   - Add capability: "Background Modes"
   - Check: "Remote notifications"

6. **Build and Run**:
   - Connect your iPhone (must be paired with Watch)
   - Select "BabyKickWatch" scheme
   - Select your iPhone as destination
   - Click Run (⌘R)

## Alternative: Start with iPhone Only

The iPhone app works perfectly on its own. You can:
- Add the Watch app later when ready
- Focus on getting comfortable with the iPhone app first
- Test all features without needing Xcode

The Swift Watch app files are ready - you just need to integrate them into an Xcode project when you're ready!

## Troubleshooting

### "npm: command not found"
Install Node.js from https://nodejs.org/

### "Expo Go won't connect"
Make sure your phone and computer are on the same WiFi network

### "Can't run on iOS Simulator"
You need Xcode installed. Download from the Mac App Store.

## Next Steps After Setup

1. Customize the colors/theme if you want
2. Test logging kicks throughout the day
3. Try a 2-hour meal session
4. Check the history view
5. If you have a Watch, set up the native Watch app for ultimate convenience!
