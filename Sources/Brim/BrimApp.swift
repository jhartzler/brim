import SwiftUI

@main
struct BrimApp: App {
    @StateObject private var timerEngine = TimerEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerEngine: timerEngine)
        } label: {
            Image(systemName: timerEngine.isRunning ? "timer" : "timer.circle")
        }
    }
}
