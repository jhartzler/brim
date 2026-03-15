# Notch-Wrapping Timer Bar Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the timer bar wrap around the MacBook notch in a continuous U-shape instead of having a gap.

**Architecture:** Single `BarOverlayWindow` with two rendering modes — non-notch (current backgroundColor approach) and notch (CAShapeLayer with strokeEnd-based progress). A new `NotchGeometry` struct encapsulates notch detection and measurement. A new `NotchBarPathBuilder` builds the CGPath. `OverlayController` becomes mode-aware for color/progress/flash updates.

**Tech Stack:** Swift, AppKit, Core Animation (CAShapeLayer), NSScreen APIs (auxiliaryTopLeftArea/auxiliaryTopRightArea, safeAreaInsets)

**Spec:** `docs/superpowers/specs/2026-03-15-notch-wrapping-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `Sources/Brim/NotchGeometry.swift` | Create | Detect notch, measure dimensions, pure data struct |
| `Sources/Brim/NotchBarPathBuilder.swift` | Create | Build the U-shaped CGPath from NotchGeometry + screen size |
| `Sources/Brim/BarOverlayWindow.swift` | Modify | Add notch mode: taller window, CAShapeLayer sublayer, strokeEnd-based progress |
| `Sources/Brim/OverlayController.swift` | Modify | Mode-aware color/progress/flash, rebuild on screen changes |
| `Tests/BrimTests/NotchGeometryTests.swift` | Create | Test notch detection logic |
| `Tests/BrimTests/NotchBarPathBuilderTests.swift` | Create | Test path construction geometry |
| `Sources/BrimApp/BrimApp.swift` | Move | Thin executable entry point (moved from Sources/Brim/) |
| `Sources/BrimApp/AppDelegate.swift` | Move | App delegate (moved from Sources/Brim/) |
| `Package.swift` | Modify | Split into library + executable + test targets |

---

## Chunk 1: Foundation — Package Split, NotchGeometry, Path Builder

### Task 1: Split Package into Library + Executable for Testability

**Files:**
- Modify: `Package.swift`
- Move: `Sources/Brim/BrimApp.swift` -> `Sources/BrimApp/BrimApp.swift`
- Move: `Sources/Brim/AppDelegate.swift` -> `Sources/BrimApp/AppDelegate.swift`

SPM cannot link a test target against an executable with `@main` (duplicate entry point). The fix is to split into a library target (`BrimLib`) containing all logic, and a thin executable target (`Brim`) with just the `@main` entry point and app delegate.

- [ ] **Step 1: Create BrimApp directory and move entry point files**

```bash
mkdir -p Sources/BrimApp
mv Sources/Brim/BrimApp.swift Sources/BrimApp/BrimApp.swift
mv Sources/Brim/AppDelegate.swift Sources/BrimApp/AppDelegate.swift
```

- [ ] **Step 2: Update Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brim",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BrimLib",
            path: "Sources/Brim",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Brim",
            dependencies: ["BrimLib"],
            path: "Sources/BrimApp"
        ),
        .testTarget(
            name: "BrimTests",
            dependencies: ["BrimLib"],
            path: "Tests/BrimTests"
        )
    ]
)
```

- [ ] **Step 3: Add `import BrimLib` to moved files**

In `Sources/BrimApp/BrimApp.swift`, add `import BrimLib` at the top (after `import SwiftUI`).
In `Sources/BrimApp/AppDelegate.swift`, add `import BrimLib` at the top (after `import AppKit`).

- [ ] **Step 4: Make types in BrimLib that BrimApp needs `public` or `package`**

The entry point files reference `TimerEngine`, `OverlayController`, `MenuBarIcon`, `MenuBarView`. These types and their used members need at minimum `package` access (since both targets are in the same package). Add `package` access to:
- `TimerEngine` class and `shared`, `start(minutes:)`, `stop()`, `isRunning`, `state`, `progress`
- `OverlayController` class and `init(timerEngine:)`
- `MenuBarIcon` and its `cap()` method
- `MenuBarView` and its `init()`

- [ ] **Step 5: Create test directory**

Run: `mkdir -p Tests/BrimTests`

- [ ] **Step 6: Verify build compiles**

Run: `cd /Users/jackhartzler/projects/brim && swift build 2>&1 | tail -10`
Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/BrimApp/ Sources/Brim/
git commit -m "refactor: split package into BrimLib + Brim executable for testability"
```

---

### Task 2: NotchGeometry — Notch Detection and Measurement

**Files:**
- Create: `Sources/Brim/NotchGeometry.swift`
- Create: `Tests/BrimTests/NotchGeometryTests.swift`

This struct encapsulates all notch-related measurements. It's a pure data type with a static factory method, making it testable without a real screen.

- [ ] **Step 1: Write NotchGeometry struct**

```swift
// Sources/Brim/NotchGeometry.swift
import AppKit

/// Describes the notch region on a MacBook screen.
/// All coordinates are in screen coordinate space (origin bottom-left).
struct NotchGeometry {
    let notchLeftX: CGFloat    // left edge of notch
    let notchRightX: CGFloat   // right edge of notch
    let notchHeight: CGFloat   // how far down from screen top the notch extends
    let screenWidth: CGFloat
    let screenMaxY: CGFloat    // top of screen in global coords

    var notchWidth: CGFloat { notchRightX - notchLeftX }
    var leftSegmentWidth: CGFloat { notchLeftX }
    var rightSegmentWidth: CGFloat { screenWidth - notchRightX }

    /// Detect notch from the main screen. Returns nil if no notch.
    static func detect(from screen: NSScreen? = .main) -> NotchGeometry? {
        guard let screen else { return nil }
        guard screen.safeAreaInsets.top > 0 else { return nil }

        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return nil
        }

        let screenFrame = screen.frame
        // auxiliaryTopLeftArea/Right give rects in screen coords
        // The notch is the gap between them
        let notchLeftX = leftArea.maxX
        let notchRightX = rightArea.origin.x

        // Sanity check: notch should have positive width
        guard notchRightX > notchLeftX else { return nil }

        return NotchGeometry(
            notchLeftX: notchLeftX - screenFrame.origin.x,  // relative to screen origin
            notchRightX: notchRightX - screenFrame.origin.x,
            notchHeight: screen.safeAreaInsets.top,
            screenWidth: screenFrame.width,
            screenMaxY: screenFrame.maxY
        )
    }

    /// Create with explicit values (for testing).
    static func mock(
        notchLeftX: CGFloat,
        notchRightX: CGFloat,
        notchHeight: CGFloat,
        screenWidth: CGFloat,
        screenMaxY: CGFloat = 956
    ) -> NotchGeometry {
        NotchGeometry(
            notchLeftX: notchLeftX,
            notchRightX: notchRightX,
            notchHeight: notchHeight,
            screenWidth: screenWidth,
            screenMaxY: screenMaxY
        )
    }
}
```

- [ ] **Step 2: Write tests for NotchGeometry**

```swift
// Tests/BrimTests/NotchGeometryTests.swift
import XCTest
@testable import Brim

final class NotchGeometryTests: XCTestCase {

    func testMockGeometryComputedProperties() {
        // 14-inch MacBook Pro approximate dimensions
        let geo = NotchGeometry.mock(
            notchLeftX: 510,
            notchRightX: 702,
            notchHeight: 32,
            screenWidth: 1512
        )

        XCTAssertEqual(geo.notchWidth, 192)
        XCTAssertEqual(geo.leftSegmentWidth, 510)
        XCTAssertEqual(geo.rightSegmentWidth, 810)
        XCTAssertEqual(geo.notchHeight, 32)
    }

    func testDetectReturnsNilForNonNotchScreen() {
        // We can't easily mock NSScreen, but we can verify detect()
        // returns a value or nil depending on hardware.
        // This test documents the expected behavior.
        let result = NotchGeometry.detect()
        // On CI or non-notch Mac, result is nil. On notch Mac, non-nil.
        // Either way, it shouldn't crash.
        if let geo = result {
            XCTAssertGreaterThan(geo.notchWidth, 0)
            XCTAssertGreaterThan(geo.notchHeight, 0)
        }
    }
}
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/jackhartzler/projects/brim && swift test 2>&1 | tail -20`
Expected: Tests pass (or build error if `@main` conflicts — see Task 1 note).

If `@main` conflict occurs: make `NotchGeometry` and `NotchBarPathBuilder` standalone files that don't require importing the Brim module. Add `// @testable` comment and adjust.

- [ ] **Step 4: Commit**

```bash
git add Sources/Brim/NotchGeometry.swift Tests/BrimTests/NotchGeometryTests.swift
git commit -m "feat: add NotchGeometry for notch detection and measurement"
```

---

### Task 3: NotchBarPathBuilder — CGPath Construction

**Files:**
- Create: `Sources/Brim/NotchBarPathBuilder.swift`
- Create: `Tests/BrimTests/NotchBarPathBuilderTests.swift`

This is the trickiest part — building the U-shaped path. The path is in the window's local coordinate space (origin bottom-left of window, since we're using Core Animation which is bottom-left by default in macOS layers — but `CALayer` on macOS uses a top-left coordinate system when `isGeometryFlipped` is not set. We need to be careful here).

**Important coordinate space note:** In a macOS `NSView`'s layer, the coordinate system origin is at the **bottom-left** by default (unlike iOS which is top-left). The window is positioned with its top edge at the screen top. So within the window:
- y=0 is the bottom of the window
- y=windowHeight is the top of the window (flush with screen top)
- The bar at the "top" of the screen is drawn near y=windowHeight

- [ ] **Step 1: Write NotchBarPathBuilder**

```swift
// Sources/Brim/NotchBarPathBuilder.swift
import AppKit
import QuartzCore

enum NotchBarPathBuilder {

    static let cornerRadius: CGFloat = 8
    static let barThickness: CGFloat = 4

    /// Build the U-shaped path around the notch.
    ///
    /// The path traces: left edge -> right along top -> down right side of notch
    /// -> across bottom of notch -> up left side of notch -> right along top -> right edge.
    ///
    /// Wait — re-reading the spec: path goes left-to-right so strokeEnd shrinking
    /// removes from the right first.
    ///
    /// Coordinate space: window-local, origin at bottom-left.
    /// Window height = notchHeight + barThickness.
    /// The top horizontal segments are at y = windowHeight - (barThickness / 2).
    /// The bottom of the U is at y = barThickness / 2 (bottom of window + half stroke).
    ///
    /// - Parameters:
    ///   - geometry: The notch measurements
    ///   - windowHeight: Height of the overlay window
    /// - Returns: A CGPath tracing the full bar route
    static func buildPath(geometry: NotchGeometry, windowHeight: CGFloat) -> CGPath {
        let r = cornerRadius
        let halfStroke = barThickness / 2

        // Key Y coordinates (window-local, bottom-left origin)
        let topY = windowHeight - halfStroke          // center of top bar stroke
        let bottomY = halfStroke                       // center of bottom-of-notch stroke

        // Key X coordinates (window-local, 0 = left edge of screen)
        let leftEdge: CGFloat = halfStroke
        let rightEdge = geometry.screenWidth - halfStroke
        let notchLeft = geometry.notchLeftX
        let notchRight = geometry.notchRightX

        let path = CGMutablePath()

        // Start at left edge, at the top
        path.move(to: CGPoint(x: leftEdge, y: topY))

        // Horizontal line to notch left corner (minus radius)
        path.addLine(to: CGPoint(x: notchLeft - r, y: topY))

        // Curve down around notch left-top corner
        path.addArc(tangent1End: CGPoint(x: notchLeft, y: topY),
                     tangent2End: CGPoint(x: notchLeft, y: topY - r),
                     radius: r)

        // Down the left side of the notch
        path.addLine(to: CGPoint(x: notchLeft, y: bottomY + r))

        // Curve around notch bottom-left corner
        path.addArc(tangent1End: CGPoint(x: notchLeft, y: bottomY),
                     tangent2End: CGPoint(x: notchLeft + r, y: bottomY),
                     radius: r)

        // Across the bottom of the notch
        path.addLine(to: CGPoint(x: notchRight - r, y: bottomY))

        // Curve around notch bottom-right corner
        path.addArc(tangent1End: CGPoint(x: notchRight, y: bottomY),
                     tangent2End: CGPoint(x: notchRight, y: bottomY + r),
                     radius: r)

        // Up the right side of the notch
        path.addLine(to: CGPoint(x: notchRight, y: topY - r))

        // Curve around notch right-top corner
        path.addArc(tangent1End: CGPoint(x: notchRight, y: topY),
                     tangent2End: CGPoint(x: notchRight + r, y: topY),
                     radius: r)

        // Horizontal line to right edge
        path.addLine(to: CGPoint(x: rightEdge, y: topY))

        return path
    }

}
```

- [ ] **Step 2: Write path builder tests**

```swift
// Tests/BrimTests/NotchBarPathBuilderTests.swift
import XCTest
@testable import Brim

final class NotchBarPathBuilderTests: XCTestCase {

    func testPathStartsAtLeftEdge() {
        let geo = NotchGeometry.mock(
            notchLeftX: 510,
            notchRightX: 702,
            notchHeight: 32,
            screenWidth: 1512
        )
        let windowHeight = geo.notchHeight + NotchBarPathBuilder.barThickness
        let path = NotchBarPathBuilder.buildPath(geometry: geo, windowHeight: windowHeight)

        // Path should not be empty
        XCTAssertFalse(path.isEmpty)

        // Bounding box should span most of the screen width
        let bounds = path.boundingBox
        XCTAssertLessThan(bounds.minX, 10, "Path should start near left edge")
        XCTAssertGreaterThan(bounds.maxX, 1500, "Path should end near right edge")
    }

    func testPathDescendsBelowTopForNotch() {
        let geo = NotchGeometry.mock(
            notchLeftX: 510,
            notchRightX: 702,
            notchHeight: 32,
            screenWidth: 1512
        )
        let windowHeight = geo.notchHeight + NotchBarPathBuilder.barThickness
        let path = NotchBarPathBuilder.buildPath(geometry: geo, windowHeight: windowHeight)
        let bounds = path.boundingBox

        // Path should extend below the top line (the U-shape dips down)
        XCTAssertLessThan(bounds.minY, windowHeight / 2,
                          "Path should dip below midpoint for the notch wrap")
    }

}
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/jackhartzler/projects/brim && swift test 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Brim/NotchBarPathBuilder.swift Tests/BrimTests/NotchBarPathBuilderTests.swift
git commit -m "feat: add NotchBarPathBuilder for U-shaped notch path"
```

---

## Chunk 2: Window and Controller Integration

### Task 4: BarOverlayWindow — Add Notch Mode

**Files:**
- Modify: `Sources/Brim/BarOverlayWindow.swift`

The window needs two modes. In notch mode, it's taller, has a clear background, and uses a CAShapeLayer for drawing. It exposes the shape layer so `OverlayController` can update `strokeColor` and `strokeEnd`.

- [ ] **Step 1: Rewrite BarOverlayWindow with dual-mode support**

```swift
// Sources/Brim/BarOverlayWindow.swift
import AppKit
import QuartzCore

final class BarOverlayWindow: NSWindow {
    static let barHeight: CGFloat = 4

    private(set) var notchGeometry: NotchGeometry?
    private(set) var shapeLayer: CAShapeLayer?

    var hasNotch: Bool { notchGeometry != nil }

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let notch = NotchGeometry.detect(from: screen)

        let windowHeight: CGFloat
        let windowY: CGFloat

        if let notch {
            windowHeight = notch.notchHeight + Self.barHeight
            windowY = screen.frame.maxY - windowHeight
        } else {
            windowHeight = Self.barHeight
            windowY = screen.frame.maxY - Self.barHeight
        }

        let frame = NSRect(
            x: screen.frame.origin.x,
            y: windowY,
            width: screen.frame.width,
            height: windowHeight
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        notchGeometry = notch

        if let notch {
            setupNotchMode(notch: notch, windowHeight: windowHeight)
        } else {
            backgroundColor = Settings.shared.barColor
        }
    }

    private func setupNotchMode(notch: NotchGeometry, windowHeight: CGFloat) {
        backgroundColor = .clear

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        contentView.wantsLayer = true
        contentView.layer?.isGeometryFlipped = false  // keep default bottom-left origin
        self.contentView = contentView

        let layer = CAShapeLayer()
        layer.lineWidth = Self.barHeight
        layer.strokeColor = Settings.shared.barColor.cgColor
        layer.fillColor = nil
        layer.lineCap = .round
        layer.path = NotchBarPathBuilder.buildPath(geometry: notch, windowHeight: windowHeight)
        layer.frame = contentView.bounds

        contentView.layer?.addSublayer(layer)
        shapeLayer = layer
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    /// Update progress. In notch mode, only updates strokeEnd (window frame is static).
    /// Call repositionFrame() separately when the window needs to move (show, rebuild).
    func updateProgress(_ progress: Double) {
        if hasNotch {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shapeLayer?.strokeEnd = CGFloat(progress)
            CATransaction.commit()
        } else {
            repositionFrame(progress: progress)
        }
    }

    /// Reposition the window frame on screen. Called on show() and rebuild().
    func repositionFrame(progress: Double = 1.0) {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        if hasNotch {
            let notch = notchGeometry!
            let windowHeight = notch.notchHeight + Self.barHeight
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - windowHeight,
                width: screen.frame.width,
                height: windowHeight
            )
            setFrame(frame, display: true)
        } else {
            // Non-notch: resize width for progress (existing behavior)
            let fullWidth = screen.frame.width
            let barWidth = fullWidth * progress
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - Self.barHeight,
                width: barWidth,
                height: Self.barHeight
            )
            setFrame(frame, display: true)
        }
    }

    /// Rebuild for a potentially different screen (notch <-> non-notch).
    func rebuild() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let newNotch = NotchGeometry.detect(from: screen)

        // Clean up old layer if present
        shapeLayer?.removeFromSuperlayer()
        shapeLayer = nil
        notchGeometry = nil

        if let newNotch {
            let windowHeight = newNotch.notchHeight + Self.barHeight
            notchGeometry = newNotch
            setupNotchMode(notch: newNotch, windowHeight: windowHeight)

            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - windowHeight,
                width: screen.frame.width,
                height: windowHeight
            )
            setFrame(frame, display: true)
        } else {
            backgroundColor = Settings.shared.barColor
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - Self.barHeight,
                width: screen.frame.width,
                height: Self.barHeight
            )
            setFrame(frame, display: true)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/jackhartzler/projects/brim && swift build 2>&1 | tail -10`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Brim/BarOverlayWindow.swift
git commit -m "feat: add notch mode to BarOverlayWindow with CAShapeLayer"
```

---

### Task 5: OverlayController — Mode-Aware Updates

**Files:**
- Modify: `Sources/Brim/OverlayController.swift`

The controller needs to:
1. Update `strokeColor` instead of `backgroundColor` in notch mode.
2. Flash `strokeColor` instead of `backgroundColor` in notch mode.
3. Call `rebuild()` on screen changes instead of just `reposition()`.

- [ ] **Step 1: Rewrite OverlayController with mode-aware logic**

```swift
// Sources/Brim/OverlayController.swift
import AppKit
import Combine
import UserNotifications

@MainActor
final class OverlayController {
    private let window: BarOverlayWindow
    private var cancellables = Set<AnyCancellable>()
    private var isFlashing = false

    init(timerEngine: TimerEngine) {
        window = BarOverlayWindow()

        timerEngine.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.window.updateProgress(progress)
            }
            .store(in: &cancellables)

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

        Settings.shared.$barColor
            .receive(on: RunLoop.main)
            .sink { [weak self] color in
                self?.updateBarColor(color)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.handleScreenChange(timerEngine: timerEngine)
            }
            .store(in: &cancellables)
    }

    private func updateBarColor(_ color: NSColor) {
        guard !isFlashing else { return }  // Don't interfere with flash sequence
        if window.hasNotch {
            window.shapeLayer?.strokeColor = color.cgColor
        } else {
            window.backgroundColor = color
        }
    }

    private func handleScreenChange(timerEngine: TimerEngine) {
        window.rebuild()
        // Re-show window if timer is currently running
        if timerEngine.state == .running {
            show()
        }
    }

    private func show() {
        window.repositionFrame()
        window.orderFrontRegardless()
    }

    private func hide() {
        window.orderOut(nil)
    }

    private func flashAndHide(timerEngine: TimerEngine) {
        let content = UNMutableNotificationContent()
        content.title = "Brim"
        content.body = "Timer complete!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        isFlashing = true
        let barColor = Settings.shared.barColor
        let flashColor = Settings.shared.flashColor
        let flashDuration = 0.15
        var delay = 0.0

        for _ in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.setFlashColor(flashColor)
            }
            delay += flashDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.setFlashColor(barColor)
            }
            delay += flashDuration
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                self?.window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.isFlashing = false
                self?.hide()
                self?.window.alphaValue = 1
                timerEngine.acknowledge()
            })
        }
    }

    private func setFlashColor(_ color: NSColor) {
        if window.hasNotch {
            window.shapeLayer?.strokeColor = color.cgColor
        } else {
            window.backgroundColor = color
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/jackhartzler/projects/brim && swift build 2>&1 | tail -10`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Brim/OverlayController.swift
git commit -m "feat: mode-aware OverlayController for notch/non-notch displays"
```

---

### Task 6: Manual Visual Testing

**Files:** None (testing only)

- [ ] **Step 1: Build the app**

Run: `cd /Users/jackhartzler/projects/brim && swift build -c release && ./scripts/build-app.sh`

- [ ] **Step 2: Launch and test on your display**

Run: `build/Brim.app/Contents/MacOS/Brim &`

Test checklist:
- Start a 1-minute timer
- Verify the bar appears at the top of the screen
- If on a notch Mac: verify the bar wraps around the notch in a U-shape
- If on a non-notch Mac: verify current behavior is unchanged
- Verify the bar depletes from right to left
- Verify the flash animation works on completion
- Change bar color in settings — verify it updates
- Stop timer — verify bar hides

- [ ] **Step 3: Add diagnostic logging if needed**

If the bar doesn't appear or looks wrong, add temporary `print()` statements in:
- `NotchGeometry.detect()` — print detected notch dimensions
- `BarOverlayWindow.init()` — print whether notch mode was activated
- `BarOverlayWindow.setupNotchMode()` — print path bounding box

Key things to check (lessons from the debugging doc):
- Is the window frame correct? (print `frame` after `setFrame`)
- Is the shape layer's frame correct? (print `shapeLayer.frame`)
- Is the path non-empty? (print `path.boundingBox`)
- Is `strokeEnd` being updated? (print in `reposition()`)

- [ ] **Step 4: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix: resolve visual issues from notch wrapping testing"
```

---

### Task 7: Run All Tests

- [ ] **Step 1: Run the full test suite**

Run: `cd /Users/jackhartzler/projects/brim && swift test 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 2: Final commit if any test fixes needed**

```bash
git add -A
git commit -m "test: fix any test issues from integration"
```
