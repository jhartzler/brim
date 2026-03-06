import SwiftUI

@main
struct BrimApp: App {
    @NSApplicationDelegateAdaptor(BrimAppDelegate.self) var appDelegate
    @StateObject private var timerEngine = TimerEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerEngine: timerEngine)
                .onAppear {
                    appDelegate.timerEngine = timerEngine
                    if appDelegate.overlayController == nil {
                        appDelegate.overlayController = OverlayController(timerEngine: timerEngine)
                    }
                }
        } label: {
            Image(systemName: timerEngine.isRunning ? "timer" : "timer.circle")
        }
    }
}
