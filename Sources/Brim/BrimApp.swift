import SwiftUI

@main
struct BrimApp: App {
    var body: some Scene {
        MenuBarExtra("Brim", systemImage: "timer") {
            Text("Brim Timer")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
