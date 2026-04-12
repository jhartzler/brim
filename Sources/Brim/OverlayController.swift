import AppKit
import Combine
import UserNotifications

@MainActor
package final class OverlayController {
    /// One window per screen, keyed by the screen's displayID (persistent across frame changes).
    private var windows: [UInt32: BarOverlayWindow] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var isFlashing = false

    package init(timerEngine: TimerEngine) {
        // Create initial windows for all connected screens
        rebuildAllWindows()

        timerEngine.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.updateProgress(progress)
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

        Settings.shared.$barAlpha
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateBarColor(Settings.shared.barColor)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.handleScreenChange(timerEngine: timerEngine)
            }
            .store(in: &cancellables)
    }

    // MARK: - Window Management

    /// Rebuild windows for all currently connected screens.
    /// Removes windows for disconnected screens, creates new ones for new screens,
    /// and updates existing windows whose screen reference or geometry may have changed.
    private func rebuildAllWindows() {
        let currentScreenIDs = Set(NSScreen.screens.map { $0.displayID })

        // Remove windows for screens that no longer exist
        for id in windows.keys where !currentScreenIDs.contains(id) {
            windows[id]?.orderOut(nil)
            windows.removeValue(forKey: id)
        }

        // Create windows for new screens, update existing windows' screen references
        for screen in NSScreen.screens {
            let id = screen.displayID
            if let existingWindow = windows[id] {
                // Update screen reference — the NSScreen object's frame may have
                // changed (resolution, arrangement) even if the displayID is the same.
                existingWindow.currentScreen = screen
                existingWindow.rebuild()
            } else {
                let window = BarOverlayWindow(screen: screen)
                windows[id] = window
            }
        }
    }

    // MARK: - Progress Visibility

    private func updateProgress(_ progress: Double) {
        for window in windows.values {
            window.updateProgress(progress)
        }
    }

    private func show() {
        for window in windows.values {
            window.repositionFrame()
            window.orderFrontRegardless()
        }
    }

    private func hide() {
        for window in windows.values {
            window.orderOut(nil)
        }
    }

    // MARK: - Color Updates

    private func updateBarColor(_ color: NSColor) {
        guard !isFlashing else { return }  // Don't interfere with flash sequence
        let alphaColor = color.withAlphaComponent(CGFloat(Settings.shared.barAlpha))
        for window in windows.values {
            if window.hasNotch {
                window.shapeLayer?.strokeColor = alphaColor.cgColor
            } else {
                window.backgroundColor = alphaColor
            }
        }
    }

    private func setFlashColor(_ color: NSColor) {
        for window in windows.values {
            if window.hasNotch {
                window.shapeLayer?.strokeColor = color.cgColor
            } else {
                window.backgroundColor = color
            }
        }
    }

    // MARK: - Screen Change Handling

    private func handleScreenChange(timerEngine: TimerEngine) {
        // Rebuild all windows for the new screen configuration
        rebuildAllWindows()

        // Apply current progress to new windows
        updateProgress(timerEngine.progress)

        // Re-show windows if timer is currently running
        if timerEngine.state == .running {
            show()
        }
    }

    // MARK: - Flash and Hide

    private func flashAndHide(timerEngine: TimerEngine) {
        let content = UNMutableNotificationContent()
        content.title = "Brim"
        content.body = "Timer complete!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        isFlashing = true

        // Reset bar to full size so the flash is visible.
        // By the time the timer finishes, progress is ~0 and the bar has
        // shrunk to nothing — resetting to full gives the flash something to show.
        for window in windows.values {
            window.updateProgress(1.0)
        }

        let barColor = Settings.shared.barColor
        let flashColor = Settings.shared.flashColor
        let flashDuration = 0.25
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
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                for window in self.windows.values {
                    window.animator().alphaValue = 0
                }
            }, completionHandler: { [weak self] in
                guard let self else { return }
                self.isFlashing = false
                self.hide()
                for window in self.windows.values {
                    window.alphaValue = 1
                }
                timerEngine.acknowledge()
            })
        }
    }
}

// MARK: - NSScreen displayID extension

extension NSScreen {
    /// Returns a persistent identifier for this screen that survives frame changes.
    /// Uses `CGDirectDisplayID` which is stable across resolution changes and
    /// does not change when the user repositions displays in System Settings.
    var displayID: UInt32 {
        return self.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
    }
}