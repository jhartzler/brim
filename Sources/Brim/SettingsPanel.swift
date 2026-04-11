import AppKit

@MainActor
final class SettingsPanel: NSPanel {

    static let shared = SettingsPanel()

    // MARK: - Constants

    private let rowHeight: CGFloat = 24
    private let sectionGap: CGFloat = 18
    private let rowGap: CGFloat = 10
    private let sidePadding: CGFloat = 20
    private let verticalPadding: CGFloat = 18
    private let panelWidth: CGFloat = 280

    // MARK: - Color Wells

    private let barColorWell = NSColorWell()
    private let flashColorWell = NSColorWell()

    // MARK: - Opacity Slider

    private let barAlphaSlider = NSSlider(value: 1.0, minValue: 0.05, maxValue: 1.0, target: nil, action: nil)
    private let barAlphaLabel = NSTextField(labelWithString: "100%")

    // MARK: - Init

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        title = "Brim Settings"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = .floating

        buildContentView()
    }

    // MARK: - Layout

    private func buildContentView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView = NSView()
        contentView!.wantsLayer = true
        contentView!.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: verticalPadding),
            container.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: sidePadding),
            container.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -sidePadding),
            container.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -verticalPadding),
        ])

        // ── Section: Colors ──
        let colorsHeader = makeSectionHeader("Colors")
        let barLabel = makeRowLabel("Bar")
        configureColorWell(barColorWell, color: Settings.shared.barColor, action: #selector(barColorChanged(_:)))
        let flashLabel = makeRowLabel("Flash")
        configureColorWell(flashColorWell, color: Settings.shared.flashColor, action: #selector(flashColorChanged(_:)))

        // ── Section: Opacity ──
        let opacityHeader = makeSectionHeader("Opacity")
        let opacityLabel = makeRowLabel("Bar")
        configureAlphaSlider(barAlphaSlider, value: Settings.shared.barAlpha)
        barAlphaLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        barAlphaLabel.textColor = .secondaryLabelColor
        barAlphaLabel.alignment = .right
        barAlphaLabel.translatesAutoresizingMaskIntoConstraints = false

        // ── Reset ──
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults(_:)))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .small
        resetButton.font = .systemFont(ofSize: 11, weight: .medium)

        // ── Separator ──
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        // ── Add all subviews ──
        for view in [colorsHeader, barLabel, barColorWell, flashLabel, flashColorWell, opacityHeader, opacityLabel, barAlphaSlider, barAlphaLabel, separator, resetButton] {
            container.addSubview(view)
        }

        NSLayoutConstraint.activate([
            // Colors section header
            colorsHeader.topAnchor.constraint(equalTo: container.topAnchor),
            colorsHeader.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colorsHeader.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Bar color row
            barLabel.topAnchor.constraint(equalTo: colorsHeader.bottomAnchor, constant: rowGap),
            barLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            barLabel.centerYAnchor.constraint(equalTo: barColorWell.centerYAnchor),

            barColorWell.topAnchor.constraint(equalTo: colorsHeader.bottomAnchor, constant: rowGap),
            barColorWell.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            barColorWell.heightAnchor.constraint(equalToConstant: rowHeight),

            // Flash color row
            flashLabel.topAnchor.constraint(equalTo: barColorWell.bottomAnchor, constant: rowGap),
            flashLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            flashLabel.centerYAnchor.constraint(equalTo: flashColorWell.centerYAnchor),

            flashColorWell.topAnchor.constraint(equalTo: barColorWell.bottomAnchor, constant: rowGap),
            flashColorWell.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            flashColorWell.heightAnchor.constraint(equalToConstant: rowHeight),

            // Opacity section header
            opacityHeader.topAnchor.constraint(equalTo: flashColorWell.bottomAnchor, constant: sectionGap),
            opacityHeader.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            opacityHeader.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Opacity row
            opacityLabel.topAnchor.constraint(equalTo: opacityHeader.bottomAnchor, constant: rowGap),
            opacityLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            opacityLabel.centerYAnchor.constraint(equalTo: barAlphaSlider.centerYAnchor),

            barAlphaSlider.topAnchor.constraint(equalTo: opacityHeader.bottomAnchor, constant: rowGap),
            barAlphaSlider.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: -30),
            barAlphaSlider.widthAnchor.constraint(equalToConstant: 100),

            barAlphaLabel.centerYAnchor.constraint(equalTo: barAlphaSlider.centerYAnchor),
            barAlphaLabel.leadingAnchor.constraint(equalTo: barAlphaSlider.trailingAnchor, constant: 6),
            barAlphaLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Separator
            separator.topAnchor.constraint(equalTo: barAlphaSlider.bottomAnchor, constant: sectionGap),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Reset button
            resetButton.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            resetButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            resetButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
    }

    // MARK: - Helpers

    private func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeRowLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
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
        slider.controlSize = .small
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
            makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Escape to Close

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}