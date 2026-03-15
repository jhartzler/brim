# Notch-Wrapping Timer Bar Design

## Problem

On MacBooks with a notch, the timer bar currently renders as a full-width 4px strip at the top of the screen. The notch creates a visual gap — the bar appears on both sides but is not continuous. The goal is to make the bar wrap around the notch in a U-shape, creating one unbroken line.

## Approach

Single window + `CAShapeLayer` with `strokeEnd`-based progress.

## Notch Detection

On launch and `didChangeScreenParametersNotification`, check `NSScreen.main?.safeAreaInsets`:

- `safeAreaInsets.top == 0` (no notch): use current behavior — 4px-tall window, `backgroundColor` as the bar, no custom drawing.
- `safeAreaInsets.top > 0` (notch present): use notch-wrapping mode with `CAShapeLayer`.

Notch geometry is derived from `NSScreen.auxiliaryTopLeftArea` and `NSScreen.auxiliaryTopRightArea` (macOS 12+). These give the usable rectangles on either side of the notch. The notch region is the gap between them: its left edge is `auxiliaryTopLeftArea.maxX`, its right edge is `auxiliaryTopRightArea.origin.x`, and its height is `safeAreaInsets.top`. On non-notch screens, these auxiliary areas may be nil or absent.

## Window (Notch Mode)

- Height: `safeAreaInsets.top + barHeight` (~36px) to fit the U-wrap beneath the notch.
- Width: full screen width.
- `backgroundColor = .clear` (not the bar color — drawing is via layer).
- `isOpaque = false` (required — `.clear` on an opaque window produces black, not transparency).
- `hasShadow = false`.
- Window positioned at `y = screen.frame.maxY - (safeAreaInsets.top + barHeight)` so the top edge is flush with the screen top.
- All existing properties preserved: borderless, `ignoresMouseEvents = true`, `constrainFrameRect` override, level `mainMenuWindow + 1`, `canJoinAllSpaces`, `stationary`, `ignoresCycle`.

## Drawing: CAShapeLayer

The content view gets `wantsLayer = true`. A `CAShapeLayer` is added as a **sublayer** of `contentView.layer` (not as the view's own backing layer). This avoids the `draw()` / `updateLayer()` question entirely.

Layer properties:
- `lineWidth = 4` (bar thickness)
- `strokeColor` = user's bar color (from `Settings.shared.barColor`)
- `fillColor = nil`
- `lineCap = .round`

### Path Shape

One continuous `CGPath` tracing this route:

```
(right edge, 2px down) ---- (notch right corner)
                                     |  8px radius curve
                              (notch right side, vertical)
                                     |
                        8px curve -- (under notch) -- 8px curve
                              |
                       (notch left side, vertical)
                 8px radius curve
                       |
(notch left corner) ---------- (left edge, 2px down)
```

The path starts at the right edge of the screen and ends at the left edge. The 2px vertical offset (half of `lineWidth`) keeps the 4px stroke visually flush with the top of the screen.

Corner radius: 8px initially. Future follow-on to read actual notch radius (possibly via a third-party library).

### Progress Mapping

- `strokeStart = 0` (right edge)
- `strokeEnd` = timer progress (1.0 = full, 0.0 = empty)

As time depletes, `strokeEnd` decreases. The visible stroke shrinks from the left end back toward the right. The 30fps timer updates set `strokeEnd` directly — `CAShapeLayer` handles the rendering.

Note: `CAShapeLayer` animations must be disabled for per-frame updates (set `CATransaction.setDisableActions(true)`) to avoid implicit animation lag.

## Non-Notch Fallback

When `safeAreaInsets.top == 0`, the existing implementation is used unchanged: a 4px-tall window whose `backgroundColor` is the bar color, resized via `setFrame()` for progress. No `CAShapeLayer` involved.

## Screen Changes

On `didChangeScreenParametersNotification`, re-detect notch presence. If the user moves the app between a notch and non-notch display, rebuild the window in the appropriate mode.

## Color Updates

`Settings.shared.$barColor` subscription must be mode-aware: updates `strokeColor` on the `CAShapeLayer` in notch mode, or `window.backgroundColor` in non-notch mode. The flash animation must also be mode-aware — toggling `strokeColor` instead of `backgroundColor` in notch mode. Care must be taken that the color subscription doesn't interfere with the flash sequence timing (the subscription fires on any color change and could reset the flash mid-animation).

## Flash Animation

The existing flash-and-hide sequence (3x color toggle + fade) adapts to notch mode by toggling `strokeColor` on the layer instead of `window.backgroundColor`.

## Files Changed

- `BarOverlayWindow.swift` — Add notch detection, optional CAShapeLayer setup, path construction, progress via `strokeEnd`.
- `OverlayController.swift` — Branch progress/color/flash updates between notch and non-notch modes.
- No new files needed. The window subclass handles both modes.

## Out of Scope

- Matching exact Apple notch corner radius (follow-on — tracked as backlog item).
- Gradient or multi-color bar effects.
- Multiple display support (uses `NSScreen.main` only, same as today).
