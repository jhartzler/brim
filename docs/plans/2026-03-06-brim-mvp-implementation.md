# Brim MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that shows a depleting timer bar at the top of the screen.

**Architecture:** Native Swift app using SwiftUI `MenuBarExtra` for the menu bar UI and a custom `NSWindow` subclass for the always-on-top overlay bar. A shared `TimerEngine` (ObservableObject) drives both views reactively via Combine. No external dependencies.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Combine, UserNotifications, macOS 14+

**Prerequisites:** Xcode installed (`xcode-select --install` at minimum, full Xcode recommended for asset catalogs and debugging).

---

### Task 1: Create the Swift Package project

We use Swift Package Manager (not an Xcode project) so the project is fully defined in code — no opaque `.xcodeproj` files. We'll generate the Xcode project from it when needed.

**Files:**
- Create: `Package.swift`
- Create: `Sources/Brim/BrimApp.swift` (minimal entry point)
- Create: `Sources/Brim/Info.plist`
- Create: `Sources/Brim/Resources/Assets.xcassets/Contents.json`
- Create: `Sources/Brim/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brim",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Brim",
            path: "Sources/Brim",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
```

**Step 2: Create minimal app entry point**

`Sources/Brim/BrimApp.swift`:
```swift
import SwiftUI

@main
struct BrimApp: App {
    var body: some Scene {
        MenuBarExtra("Brim", systemImage: "timer") {
            Text("Brim Timer")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

**Step 3: Create Info.plist**

`Sources/Brim/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.org/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.brim.timer</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>brim</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Step 4: Create asset catalog stubs**

`Sources/Brim/Resources/Assets.xcassets/Contents.json`:
```json
{
  "info": { "version": 1, "author": "xcode" }
}
```

`Sources/Brim/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "idiom": "mac", "scale": "2x", "size": "256x256" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

**Step 5: Create .gitignore**

```
.DS_Store
.build/
.swiftpm/
*.xcodeproj
xcuserdata/
DerivedData/
```

**Step 6: Build and verify**

Run: `cd /Users/jackhartzler/projects/brim && swift build 2>&1`
Expected: Build succeeds

**Step 7: Run the app briefly to verify it launches**

Run: `swift run Brim &` then check for a menu bar icon, then kill it.
Note: This may require running from Xcode or with special permissions. If `swift run` doesn't show the menu bar icon, that's okay — we'll test via Xcode later.

**Step 8: Commit**

```bash
git add Package.swift Sources/ .gitignore
git commit -m "feat: scaffold Swift package with minimal menu bar app"
```

---

### Task 2: Implement TimerEngine

The core timer logic, decoupled from any UI. This is an ObservableObject that publishes progress so SwiftUI and AppKit views react automatically.

**Files:**
- Create: `Sources/Brim/TimerEngine.swift`

**Step 1: Create TimerEngine**

`Sources/Brim/TimerEngine.swift`:
```swift
import Foundation
import Combine

@MainActor
final class TimerEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var progress: Double = 1.0  // 1.0 = full, 0.0 = done

    private var startDate: Date?
    private var duration: TimeInterval = 0
    private var displayLink: CVDisplayLink?
    private var timer: Timer?

    var isRunning: Bool { state == .running }

    func start(minutes: Double) {
        stop()
        duration = minutes * 60
        startDate = Date()
        state = .running
        progress = 1.0

        // Use a Timer on the main run loop for UI updates (~60fps is fine)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        state = .idle
        progress = 1.0
    }

    private func tick() {
        guard let startDate, state == .running else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        let remaining = max(0, duration - elapsed)
        progress = remaining / duration

        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
            state = .finished
        }
    }

    /// Call after handling the finished state to reset
    func acknowledge() {
        state = .idle
        progress = 1.0
    }
}
```

**Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Brim/TimerEngine.swift
git commit -m "feat: add TimerEngine with progress tracking"
```

---

### Task 3: Implement BarOverlayWindow

The always-on-top, click-through window that hosts the timer bar.

**Files:**
- Create: `Sources/Brim/BarOverlayWindow.swift`

**Step 1: Create BarOverlayWindow**

`Sources/Brim/BarOverlayWindow.swift`:
```swift
import AppKit

final class BarOverlayWindow: NSWindow {
    static let barHeight: CGFloat = 4

    init() {
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            return
        }

        let frame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - Self.barHeight,
            width: screen.frame.width,
            height: Self.barHeight
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }

    /// Reposition to current main screen (handles screen changes, notch geometry)
    func reposition() {
        guard let screen = NSScreen.main else { return }
        let frame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - Self.barHeight,
            width: screen.frame.width,
            height: Self.barHeight
        )
        setFrame(frame, display: true)
    }
}
```

**Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Brim/BarOverlayWindow.swift
git commit -m "feat: add BarOverlayWindow with click-through overlay"
```

---

### Task 4: Implement BarOverlayView

The NSView that renders the actual colored bar, handling notch detection.

**Files:**
- Create: `Sources/Brim/BarOverlayView.swift`

**Step 1: Create BarOverlayView**

`Sources/Brim/BarOverlayView.swift`:
```swift
import AppKit
import Combine

final class BarOverlayView: NSView {
    var progress: Double = 1.0 {
        didSet { needsDisplay = true }
    }

    var barColor: NSColor = .systemBlue {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard progress > 0 else { return }

        let screen = NSScreen.main
        let safeAreaInsets = screen?.safeAreaInsets ?? NSEdgeInsets()

        barColor.setFill()

        // If there's a notch (top safe area inset > 0), draw two segments
        if safeAreaInsets.top > 0, let screen {
            let notchWidth = screen.frame.width - safeAreaInsets.left - safeAreaInsets.right
            let notchLeft = safeAreaInsets.left
            let notchRight = notchLeft + notchWidth
            let totalDrawableWidth = safeAreaInsets.left + (screen.frame.width - notchRight)
            let fillWidth = totalDrawableWidth * progress

            // Left segment
            let leftSegmentWidth = min(fillWidth, safeAreaInsets.left)
            if leftSegmentWidth > 0 {
                let leftRect = NSRect(x: 0, y: 0, width: leftSegmentWidth, height: bounds.height)
                leftRect.fill()
            }

            // Right segment
            let remainingFill = fillWidth - safeAreaInsets.left
            if remainingFill > 0 {
                let rightStart = notchRight
                let rightRect = NSRect(x: rightStart, y: 0, width: remainingFill, height: bounds.height)
                rightRect.fill()
            }
        } else {
            // No notch — single bar across full width
            let fillWidth = bounds.width * progress
            let barRect = NSRect(x: 0, y: 0, width: fillWidth, height: bounds.height)
            barRect.fill()
        }
    }
}
```

**Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Brim/BarOverlayView.swift
git commit -m "feat: add BarOverlayView with notch-aware rendering"
```

---

### Task 5: Wire up the overlay to TimerEngine

Connect the overlay window/view to the timer engine so it shows/hides and updates in real time.

**Files:**
- Create: `Sources/Brim/OverlayController.swift`

**Step 1: Create OverlayController**

`Sources/Brim/OverlayController.swift`:
```swift
import AppKit
import Combine

@MainActor
final class OverlayController {
    private let window: BarOverlayWindow
    private let barView: BarOverlayView
    private var cancellables = Set<AnyCancellable>()

    init(timerEngine: TimerEngine) {
        window = BarOverlayWindow()
        barView = BarOverlayView(frame: window.contentView!.bounds)
        barView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(barView)

        // Observe timer progress
        timerEngine.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.barView.progress = progress
            }
            .store(in: &cancellables)

        // Observe timer state for show/hide and completion flash
        timerEngine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .idle:
                    self.hide()
                case .running:
                    self.show()
                case .finished:
                    self.flashAndHide(timerEngine: timerEngine)
                }
            }
            .store(in: &cancellables)

        // Reposition on screen changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.window.reposition()
            }
            .store(in: &cancellables)
    }

    private func show() {
        window.reposition()
        window.orderFrontRegardless()
    }

    private func hide() {
        window.orderOut(nil)
    }

    private func flashAndHide(timerEngine: TimerEngine) {
        // Flash 3 times then fade out
        let flashDuration = 0.15
        var delay = 0.0

        for _ in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.barView.barColor = .white
            }
            delay += flashDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.barView.barColor = .systemBlue
            }
            delay += flashDuration
        }

        // Fade out after flashing
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                self?.window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.hide()
                self?.window.alphaValue = 1 // Reset for next time
                timerEngine.acknowledge()
            })
        }
    }
}
```

**Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Brim/OverlayController.swift
git commit -m "feat: add OverlayController wiring timer to overlay"
```

---

### Task 6: Build the MenuBarView

The SwiftUI menu bar UI with timer presets and custom input.

**Files:**
- Create: `Sources/Brim/MenuBarView.swift`
- Modify: `Sources/Brim/BrimApp.swift`

**Step 1: Create MenuBarView**

`Sources/Brim/MenuBarView.swift`:
```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine
    @State private var customMinutes: String = ""

    var body: some View {
        Group {
            if timerEngine.isRunning {
                let remaining = Int(timerEngine.progress * 100)
                Text("Timer: \(remaining)% remaining")
                    .font(.caption)
                Divider()
                Button("Stop Timer") {
                    timerEngine.stop()
                }
            } else {
                Text("Start Timer")
                    .font(.caption)
                Divider()
                Button("5 minutes") { timerEngine.start(minutes: 5) }
                Button("15 minutes") { timerEngine.start(minutes: 15) }
                Button("25 minutes") { timerEngine.start(minutes: 25) }
                Button("45 minutes") { timerEngine.start(minutes: 45) }
                Divider()
                HStack {
                    TextField("Minutes", text: $customMinutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Button("Start") {
                        if let mins = Double(customMinutes), mins > 0 {
                            timerEngine.start(minutes: mins)
                            customMinutes = ""
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

**Step 2: Update BrimApp.swift to wire everything together**

`Sources/Brim/BrimApp.swift`:
```swift
import SwiftUI
import UserNotifications

@main
struct BrimApp: App {
    @StateObject private var timerEngine = TimerEngine()
    // Hold a reference so it doesn't get deallocated
    @State private var overlayController: OverlayController?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerEngine: timerEngine)
        } label: {
            Image(systemName: timerEngine.isRunning ? "timer" : "timer.circle")
        }
    }

    init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
```

Note: We need to properly initialize the OverlayController. Since `@StateObject` is created before `body` is called, we'll use an `AppDelegate` approach in the next task.

**Step 3: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds (may have warnings about unused overlayController — that's fine, we wire it in the next task)

**Step 4: Commit**

```bash
git add Sources/Brim/MenuBarView.swift Sources/Brim/BrimApp.swift
git commit -m "feat: add MenuBarView with timer presets and custom input"
```

---

### Task 7: Add AppDelegate for overlay lifecycle and URL scheme handling

The AppDelegate creates the overlay controller and handles `brim://` URLs.

**Files:**
- Create: `Sources/Brim/AppDelegate.swift`
- Modify: `Sources/Brim/BrimApp.swift`

**Step 1: Create AppDelegate**

`Sources/Brim/AppDelegate.swift`:
```swift
import AppKit
import UserNotifications

@MainActor
final class BrimAppDelegate: NSObject, NSApplicationDelegate {
    var overlayController: OverlayController?
    var timerEngine: TimerEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let timerEngine else { return }
        overlayController = OverlayController(timerEngine: timerEngine)

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let timerEngine else { return }
        for url in urls {
            handleURL(url, timerEngine: timerEngine)
        }
    }

    private func handleURL(_ url: URL, timerEngine: TimerEngine) {
        guard url.scheme == "brim" else { return }

        switch url.host {
        case "start":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let minutes = components?.queryItems?
                .first(where: { $0.name == "minutes" })?
                .value
                .flatMap(Double.init) ?? 25
            timerEngine.start(minutes: minutes)
        case "stop":
            timerEngine.stop()
        default:
            break
        }
    }
}
```

**Step 2: Update BrimApp.swift to use AppDelegate**

Replace `Sources/Brim/BrimApp.swift` with:
```swift
import SwiftUI

@main
struct BrimApp: App {
    @NSApplicationDelegateAdaptor(BrimAppDelegate.self) var appDelegate
    @StateObject private var timerEngine = TimerEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerEngine: timerEngine)
        } label: {
            Image(systemName: timerEngine.isRunning ? "timer" : "timer.circle")
        }
    }

    init() {}
}
```

Wait — we have a chicken-and-egg problem. The `timerEngine` lives in the SwiftUI App, but the AppDelegate needs it. Let's restructure: make TimerEngine a singleton or pass it from app to delegate.

**Revised BrimApp.swift:**
```swift
import SwiftUI

@main
struct BrimApp: App {
    @NSApplicationDelegateAdaptor(BrimAppDelegate.self) var appDelegate
    @StateObject private var timerEngine = TimerEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerEngine: timerEngine)
                .onAppear {
                    appDelegate.timerEngine = timerEngine
                    if appDelegate.overlayController == nil {
                        appDelegate.overlayController = OverlayController(timerEngine: timerEngine)
                    }
                }
        } label: {
            Image(systemName: timerEngine.isRunning ? "timer" : "timer.circle")
        }
    }
}
```

**Step 3: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/Brim/AppDelegate.swift Sources/Brim/BrimApp.swift
git commit -m "feat: add AppDelegate with URL scheme handling and overlay lifecycle"
```

---

### Task 8: Add notification on timer completion

Fire a macOS notification when the timer finishes.

**Files:**
- Modify: `Sources/Brim/OverlayController.swift`

**Step 1: Add notification to flashAndHide**

In `OverlayController.swift`, add to the `flashAndHide` method, right before the flash animation:

```swift
// Send notification
let content = UNMutableNotificationContent()
content.title = "Brim"
content.body = "Timer complete!"
content.sound = .default
let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
UNUserNotificationCenter.current().add(request)
```

Add `import UserNotifications` at the top of the file.

**Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Brim/OverlayController.swift
git commit -m "feat: fire macOS notification on timer completion"
```

---

### Task 9: Integration test — build and run

This is a manual verification task.

**Step 1: Build the release binary**

Run: `swift build -c release 2>&1`
Expected: Build succeeds

**Step 2: Run the app**

Run the built binary. Verify:
- [ ] Menu bar icon appears (timer.circle icon)
- [ ] Clicking it shows the menu with preset buttons
- [ ] Clicking "5 minutes" shows the bar at the top of the screen
- [ ] Bar depletes over time
- [ ] Clicking "Stop Timer" hides the bar
- [ ] On completion, bar flashes and notification fires

**Step 3: Test URL scheme**

Run: `open brim://start?minutes=1`
Verify: Timer starts with 1 minute.

Run: `open brim://stop`
Verify: Timer stops.

**Step 4: Fix any issues found, then commit**

```bash
git add -A
git commit -m "fix: integration test fixes"
```

---

### Task 10: Add README

**Files:**
- Create: `README.md`

**Step 1: Write README**

```markdown
# Brim

A thin timer bar that lives at the very top of your Mac screen.

## Install

Requires macOS 14 (Sonoma) or later.

```bash
swift build -c release
cp -r .build/release/Brim /Applications/
```

## Usage

Click the timer icon in the menu bar to start a timer with presets (5, 15, 25, 45 min) or a custom duration.

### Raycast / Alfred Integration

Use the URL scheme:

- `brim://start?minutes=25` — start a 25-minute timer
- `brim://stop` — cancel the current timer

## Development

```bash
swift build    # debug build
swift run Brim # run locally
```
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install and usage instructions"
```
