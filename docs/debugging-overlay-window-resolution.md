# Debugging an Invisible NSWindow: Three Compounding Failures on macOS

*How a 4-pixel overlay bar exposed three independent platform behaviors that conspired to produce zero visible output -- and why every debugging attempt appeared to fail.*

---

## The Goal

Brim is a macOS menu bar app with a simple visual premise: a thin colored bar (4 pixels tall) sits at the very top edge of the screen, overlapping the system menu bar, and depletes over time as a timer counts down. Think of it as a progress bar you can never miss because it lives above everything else.

The architecture is a hybrid: SwiftUI provides the `MenuBarExtra` (the menu bar icon, timer controls, presets), while a raw AppKit `NSWindow` provides the overlay bar itself. SwiftUI does not have a way to render a borderless, transparent, always-on-top window that overlaps the menu bar, so AppKit is the right tool for that job.

```
BrimApp (@main SwiftUI App)
  -> MenuBarExtra (SwiftUI) for the menu bar icon and timer controls
  -> @NSApplicationDelegateAdaptor -> BrimAppDelegate
       -> applicationDidFinishLaunching creates OverlayController
            -> OverlayController creates BarOverlayWindow + BarOverlayView
                 -> Subscribes to TimerEngine.shared via Combine
```

The app built. It ran. The menu bar icon appeared. Timers started and stopped correctly. Everything worked -- except the overlay bar was completely invisible.

## The Debugging History

This was not a fresh bug. Multiple previous debugging sessions had already tried an array of fixes:

- Making the bar 50 pixels tall and bright red, to rule out "it is there but too small to see."
- Calling `orderFrontRegardless()` immediately in the window's initializer.
- Escalating the window level from `.floating` to `CGWindowLevelForKey(.maximumWindow)` to `CGShieldingWindowLevel()`.
- Restructuring ownership: AppDelegate owns TimerEngine, SwiftUI passes references to AppDelegate, singleton patterns.
- Building a standalone test that creates a raw `NSWindow` outside of SwiftUI entirely -- and watching it work perfectly.

That last point was the most maddening. A plain `NSWindow`, created in a simple AppKit app, rendered exactly where it was told to. The same window creation code, embedded in a SwiftUI `App` lifecycle, produced nothing. The leading hypothesis was that SwiftUI's `App` protocol was somehow suppressing or interfering with non-SwiftUI windows. It was a reasonable hypothesis. It was also wrong.

## Phase 1: Instrumentation Over Intuition

After several sessions of hypothesis-driven guessing, we changed strategy. Instead of trying fixes and seeing if they worked, we added diagnostic logging to capture the actual runtime state of the window at every critical moment.

We logged:

- The `NSApp.activationPolicy()` at launch time.
- The window's `isVisible`, `isOnActiveSpace`, `alphaValue`, `level`, and `frame` after every call to `show()`.
- The screen's `frame` and `visibleFrame` for comparison.
- Timestamped entries for every call to `show()` and `hide()`.

This approach immediately surfaced something we had not considered.

### The Combine Subscription Trap

In `OverlayController.init()`, the code did something like this:

```swift
window.orderFrontRegardless()  // Show the window for debugging

timerEngine.$state
    .receive(on: RunLoop.main)
    .sink { [weak self] state in
        switch state {
        case .idle:
            self?.hide()
        case .running:
            self?.show()
        // ...
        }
    }
```

The intent was clear: show the window immediately as a debug test, then let the Combine subscription manage visibility going forward. But this sequence has a subtle timing problem.

Swift's `@Published` property wrapper emits its current value immediately upon subscription. If `timerEngine.state` is `.idle` (which it is at launch -- no timer is running yet), the subscriber receives `.idle` right away. But the `.receive(on: RunLoop.main)` operator does not deliver that value synchronously. It schedules delivery on the next iteration of the run loop.

So the sequence is:

1. `orderFrontRegardless()` -- window is shown.
2. Combine subscription is created -- `.idle` is captured but not yet delivered.
3. The current run loop iteration ends.
4. On the next run loop iteration, the subscriber receives `.idle` and calls `hide()`.

The window was shown and then hidden within milliseconds -- faster than a single frame render. This is why "show immediately in init" never worked as a debug test. It was not SwiftUI suppressing the window. It was our own code undoing the show before the window ever painted.

This was an important clue, but fixing it alone did not make the window visible. It just meant we could now trust our `show()` call to persist.

### Activation Policy: A Dead End

The diagnostic logs confirmed that `NSApp.activationPolicy()` was `.accessory`, which is the correct policy for a menu bar app. An accessory app can absolutely own and display windows. This hypothesis was eliminated quickly and cleanly -- exactly the value of instrumentation over intuition.

## Phase 2: The Frame Discrepancy

With the Combine timing issue addressed, we could now call `show()` and trust that the window remained in a "shown" state. The diagnostic logs confirmed: `isVisible: true`, `isOnActiveSpace: true`, `alphaValue: 1.0`. The window was, from macOS's perspective, genuinely visible.

But we could not see it.

We looked more carefully at the frame coordinates. The logs reported the window frame at `(0, 868, 1470, 50)`. The screen frame was `(0, 0, 1470, 956)`. The window's top edge was at `y = 868 + 50 = 918`. The screen's top edge was at `y = 956`. There was a 38-pixel gap between the window's top edge and the screen's top edge.

Thirty-eight pixels. Exactly the height of the macOS menu bar.

We had asked for the window to be placed at the very top of the screen. The code computed `y = screenFrame.maxY - barHeight` and called `setFrame()` with that value. But macOS silently changed the y-coordinate.

### Root Cause 1: `constrainFrameRect(_:to:)`

`NSWindow` has a method called `constrainFrameRect(_:to:)`. macOS calls it during `setFrame()`, `setFrameOrigin()`, and other frame-changing operations. Its default implementation prevents windows from being positioned such that their title bar (or, for borderless windows, their top edge) overlaps the menu bar area.

This is a guardrail. Apple does not want app windows hiding behind the menu bar where users cannot reach them. It is sensible default behavior. It is also completely silent. There is no log message, no error, no delegate callback. The system simply changes your coordinates and moves on.

Our code requested `y = 906`. macOS changed it to `y = 868`. The window was 38 pixels lower than intended, sitting just below the menu bar instead of overlapping it.

The fix is a one-line override in the `NSWindow` subclass:

```swift
override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    return frameRect  // Allow the window to be placed anywhere, including over the menu bar.
}
```

After this change, the window frame correctly reported `(0, 906, 1470, 50)`. The top edge was now at `y = 956`, flush with the top of the screen.

But the window was still invisible.

## Phase 3: The Window Level Problem

The diagnostic logs showed the window's level as `3`. That is `NSWindow.Level.floating`, which we had set explicitly. Floating windows render above normal windows. Surely that was high enough.

It was not.

The macOS menu bar renders at window level `24`, which corresponds to `NSWindow.Level.mainMenu` (or equivalently, `CGWindowLevelForKey(.mainMenuWindow)`). A floating window at level 3 is nowhere close. In the compositing stack, the menu bar paints over anything below level 24 in the menu bar region.

Our window was now correctly *positioned* over the menu bar (thanks to the `constrainFrameRect` fix), but it was rendering *behind* the menu bar in the z-order. The menu bar was painting right on top of it.

Previous sessions had tried higher window levels -- but those attempts were made *before* the `constrainFrameRect` fix. Without the position fix, the window was both behind the menu bar (wrong z-order) *and* below the menu bar (wrong y-coordinate). Raising the window level alone could not help because the window was not even in the right location. The high window level was discarded as "not working" when in fact it was solving one of two remaining problems.

The fix:

```swift
level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
```

Level 25. One above the menu bar. Enough to render on top of it without going to extreme levels that might interfere with system UI like the screen saver or the force-quit dialog.

## Phase 4: The View Drawing Problem

With position and level corrected, we tested with `window.backgroundColor = .red` and `window.isOpaque = true`. A bright red bar appeared at the top of the screen, overlapping the menu bar. After weeks of debugging, the window was finally rendering.

We reverted to the intended configuration: a transparent window background with a custom `BarOverlayView` (an `NSView` subclass) that used `draw(_:)` to paint the timer bar. The bar disappeared again.

The custom view's `draw()` method was never visually rendering, despite the window being correctly positioned and leveled. We did not fully root-cause this failure -- possible causes include the view not being marked as needing display at the right time, coordinate space issues in the notch-aware drawing code, or the transparent window not compositing the subview correctly. But we did not need to.

### A Simpler Architecture

The overlay bar is a solid-colored rectangle that changes width. That is exactly what `NSWindow.backgroundColor` already provides. We do not need a custom `NSView` with a `draw()` override to fill a rectangle with a color. The window itself *is* the rectangle.

The fix was to eliminate `BarOverlayView` entirely and use the window's own `backgroundColor` set to `.systemBlue`. To represent timer progress, we resize the window's width via `setFrame()`. Full width means full time remaining. Zero width means time is up.

This is simpler, has fewer moving parts, and sidesteps whatever issue was preventing the custom view from rendering. It also means there is no need to manage a view hierarchy, handle `needsDisplay` invalidation, or worry about coordinate transforms for notch-aware drawing.

## The Three Root Causes

Three independent issues compounded to produce a single symptom: an invisible window.

| Issue | Behavior | Fix |
|---|---|---|
| `constrainFrameRect` | macOS silently repositioned the window 38px below the menu bar | Override `constrainFrameRect` to return the requested frame unchanged |
| Window level too low | `.floating` (level 3) renders behind the menu bar (level 24) | Set level to `mainMenuWindow + 1` (level 25) |
| Custom `NSView` not drawing | `draw()` never produced visible output in this configuration | Eliminate the custom view; use the window's `backgroundColor` directly |

These issues had to be solved in sequence. Fixing any one or two still resulted in an invisible window. This is the core reason the debugging took so long: each partial fix appeared to be ineffective because the remaining issues masked the improvement.

## Why This Bug Was So Difficult

**Silent failure at every level.** macOS reported `isVisible: true`, `isOnActiveSpace: true`, correct alpha values -- everything looked correct through the API. The window existed. The system considered it visible. It was simply hidden behind the menu bar, positioned below the menu bar, or failing to draw its content. There was no error, no warning, no indication that anything was wrong. You had to compare frame coordinates against screen coordinates and know the menu bar's window level to spot the discrepancies.

**Compounding independent failures.** Three unrelated issues each independently caused invisibility. When you fix one and the window remains invisible, the natural conclusion is that your fix was wrong. In reality, the fix was correct but insufficient. This pattern -- where a correct fix produces no visible change because other issues remain -- is one of the most demoralizing in debugging. It actively punishes correct reasoning.

**`constrainFrameRect` is obscure.** Most macOS developers never need to override it because most apps do not intentionally overlap the menu bar. It is not mentioned in common tutorials or Stack Overflow answers about window positioning. It is a silent, invisible behavior that changes your coordinates without telling you. If you do not know it exists, you have no reason to suspect it, and `setFrame()` appears to work correctly because `frame` returns the constrained value without complaint.

**The Combine timing issue was a red herring factory.** Because the subscription immediately hid the window, every "show the window to test" approach failed. This made it appear that the window *could not* be shown at all, which led to the hypothesis that SwiftUI was suppressing it. That hypothesis was wrong, but it consumed significant debugging effort across multiple sessions.

**Hybrid SwiftUI + AppKit is underexplored territory.** Using SwiftUI's `App` protocol with `MenuBarExtra` while also creating raw `NSWindow` instances is an unusual pattern. Documentation is sparse. There are few examples to reference. When something goes wrong, it is difficult to distinguish between "this is a framework limitation" and "I have a bug."

## The Final Architecture

```
BrimApp (@main SwiftUI App)
  -> MenuBarExtra for timer icon and controls
  -> @NSApplicationDelegateAdaptor -> BrimAppDelegate
       -> Sets activation policy to .accessory
       -> Creates OverlayController

OverlayController
  -> Creates BarOverlayWindow (backgroundColor = .systemBlue)
  -> Subscribes to TimerEngine.$progress -> resizes window width
  -> Subscribes to TimerEngine.$state -> show/hide window
  -> No custom NSView needed -- the window's background color IS the bar

BarOverlayWindow (NSWindow subclass)
  -> Level: mainMenuWindow + 1 (renders above the menu bar)
  -> constrainFrameRect overridden (allows positioning over the menu bar)
  -> collectionBehavior: canJoinAllSpaces, stationary, ignoresCycle
  -> ignoresMouseEvents: true (clicks pass through to the menu bar)
  -> styleMask: borderless
  -> backgroundColor: .systemBlue
```

The window is 4 pixels tall and spans the full screen width. As the timer counts down, the window's width shrinks proportionally. When the timer is idle, the window is hidden. When a timer starts, it is shown. That is the entire rendering model.

## Lessons

**Instrument before you hypothesize.** The breakthrough in this debugging effort was not a clever fix -- it was adding logging that captured the window's actual frame coordinates, level, and visibility state. Once we had real data, the frame discrepancy was obvious. Without data, we spent sessions chasing the wrong hypothesis.

**When multiple things can be wrong, fix and verify each independently.** If we had tested position correctness separately from visibility (for example, by temporarily making the window opaque and placing it in the center of the screen), we would have found `constrainFrameRect` much faster. Instead, we tested everything at once and could not distinguish which failure we were observing.

**Know your platform's invisible guardrails.** `constrainFrameRect`, window levels, activation policies, collection behaviors -- macOS has many mechanisms that silently modify or constrain window behavior. They exist for good reasons, but they can be bewildering when you are intentionally doing something the platform considers unusual. The best defense is familiarity with the platform's window management documentation, but the second-best defense is diagnostic logging that tells you what actually happened versus what you asked for.

**Simplify when you can.** The custom `NSView` with a `draw()` override was unnecessary complexity. The window's own `backgroundColor` and `setFrame()` accomplish the same visual result with fewer failure modes. When debugging reveals that a component is not working, it is worth asking whether that component needs to exist at all.
