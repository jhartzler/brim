import AppKit

@MainActor
final class Settings: ObservableObject {

    static let shared = Settings()

    // MARK: - UserDefaults Keys

    private enum Key {
        static let barColorHex = "brim.barColorHex"
        static let barAlpha = "brim.barAlpha"
        static let flashColorHex = "brim.flashColorHex"
    }

    // MARK: - Defaults

    private static let defaultBarColor: NSColor = .systemBlue
    private static let defaultBarAlpha: Double = 1.0
    private static let defaultFlashColor: NSColor = .white

    // MARK: - Published Properties

    @Published var barColor: NSColor {
        didSet { UserDefaults.standard.set(barColor.hexString, forKey: Key.barColorHex) }
    }

    @Published var barAlpha: Double {
        didSet { UserDefaults.standard.set(barAlpha, forKey: Key.barAlpha) }
    }

    @Published var flashColor: NSColor {
        didSet { UserDefaults.standard.set(flashColor.hexString, forKey: Key.flashColorHex) }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        if let hex = defaults.string(forKey: Key.barColorHex) {
            barColor = NSColor(hex: hex) ?? Self.defaultBarColor
        } else {
            barColor = Self.defaultBarColor
        }

        barAlpha = defaults.object(forKey: Key.barAlpha) as? Double ?? Self.defaultBarAlpha

        if let hex = defaults.string(forKey: Key.flashColorHex) {
            flashColor = NSColor(hex: hex) ?? Self.defaultFlashColor
        } else {
            flashColor = Self.defaultFlashColor
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: Key.barColorHex)
        UserDefaults.standard.removeObject(forKey: Key.barAlpha)
        UserDefaults.standard.removeObject(forKey: Key.flashColorHex)
        barColor = Self.defaultBarColor
        barAlpha = Self.defaultBarAlpha
        flashColor = Self.defaultFlashColor
    }
}

// MARK: - NSColor Hex Helpers

private extension NSColor {

    /// Creates an NSColor from a 6-character hex string like "#RRGGBB" or "RRGGBB".
    /// Returns nil if the string is malformed.
    convenience init?(hex: String) {
        var stripped = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("#") { stripped.removeFirst() }
        guard stripped.count == 6, let value = UInt64(stripped, radix: 16) else { return nil }

        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0

        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Returns a 6-character hex string like "#RRGGBB", stripping the alpha channel.
    var hexString: String {
        let converted = usingColorSpace(.sRGB) ?? self
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}