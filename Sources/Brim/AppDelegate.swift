import AppKit
import UserNotifications

@MainActor
final class BrimAppDelegate: NSObject, NSApplicationDelegate {
    var overlayController: OverlayController?
    var timerEngine: TimerEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let timerEngine else { return }
        overlayController = OverlayController(timerEngine: timerEngine)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let timerEngine else { return }
        for url in urls {
            handleURL(url, timerEngine: timerEngine)
        }
    }

    private func handleURL(_ url: URL, timerEngine: TimerEngine) {
        guard url.scheme == "brim" else { return }

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
