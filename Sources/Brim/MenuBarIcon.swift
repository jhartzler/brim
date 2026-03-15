import AppKit

package enum MenuBarIcon {
    package static func cap() -> NSImage {
        // Load from the SPM resource bundle
        if let url = Bundle.module.url(forResource: "BrimIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 22, height: 22)
            image.isTemplate = true
            return image
        }
        return NSImage(systemSymbolName: "timer", accessibilityDescription: "Brim")!
    }
}
