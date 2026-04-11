import AppKit

@MainActor
final class SettingsPanel: NSPanel {

    static let shared = SettingsPanel()

    // MARK: - Color Wells

    private let barColorWell = NSColorWell()
    private let flashColorWell = NSColorWell()

    // MARK: - Opacity Slider

    private let barAlphaSlider = NSSlider(value: 1.0, minValue: 0.05, maxValue: 1.0, target: nil, action: nil)
    private let barAlphaLabel = NSTextField(labelWithString: "100%")

    // MARK: - Init

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )

        title = "Settings"
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false

        buildContentView()
    }

    // MARK: - Layout

    private func buildContentView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView = NSView()
        contentView!.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -16),
        ])

        // Bar Color row
        let barLabel = makeLabel("Bar Color")
        configureColorWell(barColorWell, color: Settings.shared.barColor, action: #selector(barColorChanged(_:)))

        // Flash Color row
        let flashLabel = makeLabel("Flash Color")
        configureColorWell(flashColorWell, color: Settings.shared.flashColor, action: #selector(flashColorChanged(_:)))

        // Bar Opacity row
        let opacityLabel = makeLabel("Bar Opacity")
        configureAlphaSlider(barAlphaSlider, value: Settings.shared.barAlpha)
        barAlphaLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        barAlphaLabel.alignment = .right
        barAlphaLabel.translatesAutoresizingMaskIntoConstraints = false

        // Reset button
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults(_:)))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .regular

        for view in [barLabel, barColorWell, flashLabel, flashColorWell, opacityLabel, barAlphaSlider, barAlphaLabel, resetButton] {
            container.addSubview(view)
        }

        NSLayoutConstraint.activate([
            // Bar Color row
            barLabel.topAnchor.constraint(equalTo: container.topAnchor),
            barLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            barLabel.centerYAnchor.constraint(equalTo: barColorWell.centerYAnchor),

            barColorWell.topAnchor.constraint(equalTo: container.topAnchor),
            barColorWell.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            barColorWell.widthAnchor.constraint(equalToConstant: 44),
            barColorWell.heightAnchor.constraint(equalToConstant: 28),

            // Flash Color row
            flashLabel.topAnchor.constraint(equalTo: barColorWell.bottomAnchor, constant: 12),
            flashLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            flashLabel.centerYAnchor.constraint(equalTo: flashColorWell.centerYAnchor),

            flashColorWell.topAnchor.constraint(equalTo: barColorWell.bottomAnchor, constant: 12),
            flashColorWell.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            flashColorWell.widthAnchor.constraint(equalToConstant: 44),
            flashColorWell.heightAnchor.constraint(equalToConstant: 28),

            // Bar Opacity row
            opacityLabel.topAnchor.constraint(equalTo: flashColorWell.bottomAnchor, constant: 12),
            opacityLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            opacityLabel.centerYAnchor.constraint(equalTo: barAlphaSlider.centerYAnchor),

            barAlphaSlider.topAnchor.constraint(equalTo: flashColorWell.bottomAnchor, constant: 12),
            barAlphaSlider.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: -20),
            barAlphaSlider.widthAnchor.constraint(equalToConstant: 100),

            barAlphaLabel.centerYAnchor.constraint(equalTo: barAlphaSlider.centerYAnchor),
            barAlphaLabel.leadingAnchor.constraint(equalTo: barAlphaSlider.trailingAnchor, constant: 6),
            barAlphaLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Reset button
            resetButton.topAnchor.constraint(equalTo: barAlphaSlider.bottomAnchor, constant: 16),
            resetButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            resetButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        return label
    }

    private func configureColorWell(_ well: NSColorWell, color: NSColor, action: Selector) {
        well.translatesAutoresizingMaskIntoConstraints = false
        well.color = color
        well.target = self
        well.action = action
    }

    private func configureAlphaSlider(_ slider: NSSlider, value: Double) {
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.doubleValue = value
        slider.target = self
        slider.action = #selector(barAlphaChanged(_:))
        slider.isContinuous = true
        updateAlphaLabel(value)
    }

    private func updateAlphaLabel(_ value: Double) {
        barAlphaLabel.stringValue = "\(Int(round(value * 100)))%"
    }

    // MARK: - Actions

    @objc private func barColorChanged(_ sender: NSColorWell) {
        Settings.shared.barColor = sender.color
    }

    @objc private func flashColorChanged(_ sender: NSColorWell) {
        Settings.shared.flashColor = sender.color
    }

    @objc private func barAlphaChanged(_ sender: NSSlider) {
        Settings.shared.barAlpha = sender.doubleValue
        updateAlphaLabel(sender.doubleValue)
    }

    @objc private func resetDefaults(_ sender: NSButton) {
        Settings.shared.resetToDefaults()
        barColorWell.color = Settings.shared.barColor
        flashColorWell.color = Settings.shared.flashColor
        barAlphaSlider.doubleValue = Settings.shared.barAlpha
        updateAlphaLabel(Settings.shared.barAlpha)
    }

    // MARK: - Toggle

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            center()
            orderFrontRegardless()
        }
    }

    // MARK: - Escape to Close

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}