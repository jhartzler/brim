import AppKit
import Combine
import UserNotifications

@MainActor
final class OverlayController {
    private let window: BarOverlayWindow
    private var cancellables = Set<AnyCancellable>()

    init(timerEngine: TimerEngine) {
        window = BarOverlayWindow()

        // Observe timer progress — resize window width
        timerEngine.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.window.reposition(progress: progress)
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
        let content = UNMutableNotificationContent()
        content.title = "Brim"
        content.body = "Timer complete!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        let flashDuration = 0.15
        var delay = 0.0

        for _ in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.window.backgroundColor = .white
            }
            delay += flashDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.window.backgroundColor = .systemBlue
            }
            delay += flashDuration
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                self?.window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.hide()
                self?.window.alphaValue = 1
                timerEngine.acknowledge()
            })
        }
    }
}
