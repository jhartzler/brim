# Brim MVP Design

## Overview
A macOS menu bar app that displays a thin timer bar at the very top edge of the screen. The bar depletes over the timer duration, then sends a notification.

## Technology
- Native Swift, macOS 14+ (Sonoma)
- SwiftUI for menu bar popover, AppKit for overlay window
- No external dependencies

## Architecture

### Components
1. **TimerEngine** — ObservableObject tracking start time, duration, progress. Publishes via Combine.
2. **BarOverlayWindow** — NSWindow subclass: borderless, click-through, non-activating, level above status bar. Hosts the bar view.
3. **BarOverlayView** — NSView rendering a colored rectangle proportional to remaining time. On notched displays, splits into two segments using NSScreen safe area insets. Rendering layer designed for future swap to bezier curve path.
4. **MenuBarView** — SwiftUI MenuBarExtra with presets (5, 15, 25, 45 min), custom input, stop button.
5. **AppDelegate** — Registers URL scheme handler, creates overlay window.

### Timer Bar Behavior
- 4px tall, anchored to top edge of screen
- Depletes left to right
- Single color (default blue, stored in UserDefaults)
- On completion: flashes 3 times, fades out, fires macOS notification
- Menu bar icon shows active/inactive state

### URL Scheme
- `brim://start?minutes=25` — starts a timer
- `brim://stop` — cancels current timer

### App Configuration
- LSUIElement = true (no dock icon)
- URL scheme registered in Info.plist

## Project Structure
```
Brim/
  BrimApp.swift          — App entry, MenuBarExtra
  TimerEngine.swift      — Timer state & logic
  BarOverlayWindow.swift — NSWindow subclass
  BarOverlayView.swift   — NSView rendering the bar
  MenuBarView.swift      — SwiftUI menu popover
  Assets.xcassets/       — App icon, colors
  Info.plist             — URL scheme, LSUIElement
```

## Future Hooks (not built in MVP)
- Configurable color gradients / color transitions — swap BarOverlayView rendering
- Notch curve — swap rectangle for bezier path in BarOverlayView
- Sounds — add to completion handler in TimerEngine
- Pomodoro sequences — extend TimerEngine with a duration queue
