import SwiftUI

@main
struct BrimApp: App {
    @NSApplicationDelegateAdaptor(BrimAppDelegate.self) var appDelegate
    @ObservedObject private var timerEngine = TimerEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerEngine: timerEngine)
        } label: {
            Image(nsImage: MenuBarIcon.cap())
        }
    }
}
