# Settings Menu — Color Picker

## Summary

Add a settings panel to Brim that lets users customize the bar color and completion flash color. Colors persist across app restarts via UserDefaults.

## Components

### Settings.swift (new)

`@MainActor final class Settings: ObservableObject` — singleton model backed by UserDefaults.

- `@Published var barColor: NSColor` and `@Published var flashColor: NSColor` as stored properties
- `didSet` on each property writes the hex string to UserDefaults as a side effect
- `init()` reads hex strings from UserDefaults, converts to NSColor (fallback to defaults on malformed/missing values)
- Defaults: `.systemBlue` for bar, `.white` for flash
- `resetToDefaults()` removes UserDefaults keys and resets stored properties to defaults
- Hex conversion: 6-character sRGB hex (`#RRGGBB`), alpha channel stripped. Invalid hex falls back to default color.

### SettingsPanel.swift (new)

Compact floating NSPanel with no title bar.

- `NSPanel` subclass, `.utilityWindow` style mask, `.nonactivatingPanel` behavior (doesn't steal focus)
- Two labeled `NSColorWell` controls: "Bar Color" and "Flash Color"
- "Reset to Defaults" link at the bottom
- Reads initial values from `Settings.shared`, writes back on color well change via target/action
- Singleton instance — `toggle()` opens or closes. Dismissed by clicking away, pressing Escape (via `cancelOperation:`), or toggling again from the menu.
- Positioned near the top of the screen when opened

### MenuBarView.swift (modified)

- Add a "Settings..." button between the last Divider and the "Quit" button
- Button calls `SettingsPanel.shared.toggle()` — the menu bar dropdown will dismiss first (standard MenuBarExtra behavior), then the panel appears via `orderFrontRegardless()`

### OverlayController.swift (modified)

- Subscribe to `Settings.shared.$barColor` and `Settings.shared.$flashColor`
- Replace hardcoded `.systemBlue` with `Settings.shared.barColor`
- Replace hardcoded `.white` flash color with `Settings.shared.flashColor`
- In `flashAndHide`: capture both colors at the start of the method to avoid mixed colors if settings change mid-animation
- Color changes apply in real time, even mid-timer

### BarOverlayWindow.swift (modified)

- Initial `backgroundColor` reads from `Settings.shared.barColor` instead of hardcoded `.systemBlue`

## Data Flow

```
SettingsPanel (NSColorWell target/action)
  -> Settings.shared (@Published NSColor properties, writes hex to UserDefaults)
    -> OverlayController (subscribes via Combine $barColor/$flashColor, updates window)
    -> BarOverlayWindow (initial color on creation)
```

## Persistence

- Storage: `UserDefaults.standard`
- Keys: `brim.barColorHex`, `brim.flashColorHex`
- Format: 6-char sRGB hex strings like `#007AFF`, `#FFFFFF` (alpha stripped)
- Missing or malformed keys = use defaults (systemBlue, white)

## Out of Scope

- URL scheme for setting colors (not needed — visual preference only)
- Gradient or multi-color bar (future work, see backlog)
- Notch-aware color settings (future work)
- Any other settings beyond colors
