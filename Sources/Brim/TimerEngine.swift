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
    private var timer: Timer?

    var isRunning: Bool { state == .running }

    func start(minutes: Double) {
        stop()
        duration = minutes * 60
        startDate = Date()
        state = .running
        progress = 1.0

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

    func acknowledge() {
        state = .idle
        progress = 1.0
    }
}
