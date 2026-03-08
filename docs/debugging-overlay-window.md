# Debugging: Overlay Window Not Visible

## Status
The app builds, runs, shows a menu bar icon with working presets — but the overlay bar window never appears on screen.

## What Works
- Swift Package builds cleanly (`swift build -c release`)
- App bundle assembled via `scripts/build-app.sh`
- Menu bar icon appears (must launch via `build/Brim.app/Contents/MacOS/Brim &`, NOT `open Brim.app`)
- MenuBarView renders correctly with preset buttons
- TimerEngine starts/stops correctly (menu UI updates)
- `applicationDidFinishLaunching` fires (confirmed via file write to /tmp)
- OverlayController is created (confirmed via file write to /tmp)
- A raw NSWindow test (no SwiftUI, just `NSApplication.shared` + `app.run()`) DOES display a window

## What Doesn't Work
- BarOverlayWindow never appears visually, even when:
  - Made 50px tall + bright red for visibility
  - Set to `orderFrontRegardless()` immediately in OverlayController init
  - Window level set to `.floating` (modest level)
  - Window level set to `CGWindowLevelForKey(.maximumWindow)` (high level)
  - Window level set to `CGShieldingWindowLevel()` (highest level)

## Key Findings

### Raw NSWindow test worked but with caveats
A minimal test (`/tmp/WindowTest.swift`) using `NSApplication.shared` directly + `app.run()` DID show a red bar — but only on ONE workspace, not all. This suggests:
1. NSWindow rendering works fine on this system
2. The issue is specific to how SwiftUI App protocol manages windows
3. `collectionBehavior = .canJoinAllSpaces` may need the app to be properly activated

### SwiftUI App lifecycle complications
- `@NSApplicationDelegateAdaptor` creates the delegate and `applicationDidFinishLaunching` fires
- But windows created in `applicationDidFinishLaunching` may not display when SwiftUI owns the app lifecycle
- SwiftUI's `MenuBarExtra` `onAppear` only fires when the user opens the menu (not on app launch)
- `.task` modifier on MenuBarExtra content also unreliable for setup

### Wiring attempts that failed
1. **AppDelegate owns TimerEngine, creates OverlayController in didFinishLaunching** — controller created but window invisible
2. **SwiftUI owns TimerEngine via @StateObject, passes to AppDelegate via onAppear** — onAppear never fired (or fired too late)
3. **Singleton TimerEngine.shared** — same result, controller created but window invisible
4. **Show window immediately in OverlayController init** — still invisible

## Hypotheses for Next Attempt

### Most likely: SwiftUI app lifecycle suppresses non-SwiftUI windows
SwiftUI's App protocol may manage the NSApplication in a way that prevents independently-created NSWindows from displaying. The raw test worked because it used `NSApplication.shared` directly.

**Possible fixes:**
1. **Use a SwiftUI Window instead of NSWindow** — Use SwiftUI's `Window` scene type with custom styling, or embed NSView via NSViewRepresentable
2. **Drop SwiftUI App protocol entirely** — Use traditional AppDelegate-based app with `NSApplication.shared.run()`, create MenuBarExtra via NSStatusBar/NSStatusItem instead of SwiftUI MenuBarExtra
3. **Activate the app before showing the window** — Try `NSApp.activate(ignoringOtherApps: true)` or `NSApp.setActivationPolicy(.accessory)` before `orderFrontRegardless()`
4. **Use NSPanel instead of NSWindow** — NSPanel has different visibility rules and may work better as an overlay

### Worth investigating
- Does `NSApp.setActivationPolicy(.accessory)` before window creation help?
- Does the window exist but at the wrong coordinates? (macOS coordinate system: origin is bottom-left, y increases upward)
- Is the window being created on a different screen than expected?
- Could `LSUIElement = true` in Info.plist affect window visibility?

## Current Architecture
```
BrimApp (@main SwiftUI App)
  └─ @NSApplicationDelegateAdaptor → BrimAppDelegate
       └─ applicationDidFinishLaunching creates OverlayController
            └─ OverlayController creates BarOverlayWindow + BarOverlayView
                 └─ Subscribes to TimerEngine.shared via Combine

TimerEngine.shared (singleton, @MainActor ObservableObject)
  └─ Used by both SwiftUI (MenuBarView) and AppKit (OverlayController)
```

## Current State of Files
- Debug artifacts still present: bar height = 50px, color = red, show-on-init in OverlayController
- Debug file writes in AppDelegate (write to /tmp/brim-debug*.txt)
- These should be cleaned up when the window issue is resolved

## Build & Run
```bash
swift build -c release
./scripts/build-app.sh
build/Brim.app/Contents/MacOS/Brim &   # NOT `open Brim.app`
```
