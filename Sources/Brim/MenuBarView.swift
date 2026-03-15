import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine
    @State private var customMinutes: String = ""

    var body: some View {
        Group {
            if timerEngine.isRunning {
                let remaining = Int(timerEngine.progress * 100)
                Text("Timer: \(remaining)% remaining")
                    .font(.caption)
                Divider()
                Button("Stop Timer") {
                    timerEngine.stop()
                }
            } else {
                Text("Start Timer")
                    .font(.caption)
                Divider()
                Button("5 minutes") { timerEngine.start(minutes: 5) }
                Button("15 minutes") { timerEngine.start(minutes: 15) }
                Button("25 minutes") { timerEngine.start(minutes: 25) }
                Button("45 minutes") { timerEngine.start(minutes: 45) }
                Divider()
                HStack {
                    TextField("Minutes", text: $customMinutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Button("Start") {
                        if let mins = Double(customMinutes), mins > 0 {
                            timerEngine.start(minutes: mins)
                            customMinutes = ""
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            Divider()
            Button("Settings...") {
                SettingsPanel.shared.toggle()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
