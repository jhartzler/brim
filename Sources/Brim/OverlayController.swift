import AppKit
import Combine
import UserNotifications

@MainActor
package final class OverlayController {
    private let window: BarOverlayWindow
    private var cancellables = Set<AnyCancellable>()
    private var isFlashing = false

    package init(timerEngine: TimerEngine) {
        window = BarOverlayWindow()

        timerEngine.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.rebuildIfScreenChanged()
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

    private func updateBarColor(_ color: NSColor) {
        guard !isFlashing else { return }  // Don't interfere with flash sequence
        let alphaColor = color.withAlphaComponent(CGFloat(Settings.shared.barAlpha))
        if window.hasNotch {
            window.shapeLayer?.strokeColor = alphaColor.cgColor
        } else {
            window.backgroundColor = alphaColor
        }
    }

    private func rebuildIfScreenChanged() {
        let activeScreen = NSScreen.main ?? NSScreen.screens[0]
        guard activeScreen != window.currentScreen else { return }
        window.rebuild()
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