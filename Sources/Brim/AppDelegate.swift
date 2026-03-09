import AppKit
import UserNotifications

@MainActor
final class BrimAppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlayController = OverlayController(timerEngine: TimerEngine.shared)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "brim" else { return }
        let timerEngine = TimerEngine.shared

        switch url.host {
        case "start":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let minutes = components?.queryItems?
                .first(where: { $0.name == "minutes" })?
                .value
                .flatMap(Double.init) ?? 25
            timerEngine.start(minutes: minutes)
        case "stop":
            timerEngine.stop()
        default:
            break
        }
    }
}
