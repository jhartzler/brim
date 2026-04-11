import AppKit

@MainActor
final class SettingsPanel: NSPanel {

    static let shared = SettingsPanel()

    // MARK: - Layout constants

    private let sectionSpacing: CGFloat = 22
    private let rowSpacing: CGFloat = 5
    private let hPad: CGFloat = 18
    private let vPad: CGFloat = 22
    private let rowH: CGFloat = 38

    // MARK: - Subviews (stored for updates)

    private let barColorWell   = NSColorWell(style: .expanded)
    private let flashColorWell = NSColorWell(style: .expanded)
    private let barAlphaSlider = NSSlider(value: 1.0, minValue: 0.05, maxValue: 1.0, target: nil, action: nil)
    private let barAlphaLabel  = NSTextField(labelWithString: "100%")

    // MARK: - Init

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 352),
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
        appearance = NSAppearance(named: .darkAqua)
        buildContentView()
    }

    // MARK: - Build

    private func buildContentView() {
        let fx = NSVisualEffectView()
        fx.translatesAutoresizingMaskIntoConstraints = false
        fx.material = .underWindowBackground
        fx.blendingMode = .behindWindow
        fx.state = .active
        contentView = fx

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: fx.topAnchor, constant: vPad),
            root.leadingAnchor.constraint(equalTo: fx.leadingAnchor, constant: hPad),
            root.trailingAnchor.constraint(equalTo: fx.trailingAnchor, constant: -hPad),
            root.bottomAnchor.constraint(equalTo: fx.bottomAnchor, constant: -vPad),
        ])

        // ── Panel header ──
        let appNameLabel = makeLabel("BRIM", size: 10, weight: .black, alpha: 0.9)
        appNameLabel.alignment = .center

        let settingsTitleLabel = makeLabel("Settings", size: 18, weight: .light, alpha: 0.75)
        settingsTitleLabel.alignment = .center

        // ── Colors ──
        let colorsHead = makeSectionHeader("Colors")
        configureColorWell(barColorWell, color: Settings.shared.barColor, action: #selector(barColorChanged(_:)))
        configureColorWell(flashColorWell, color: Settings.shared.flashColor, action: #selector(flashColorChanged(_:)))
        let barColorRow   = makeControlRow(title: "Bar",   control: barColorWell,   controlWidth: 100)
        let flashColorRow = makeControlRow(title: "Flash", control: flashColorWell, controlWidth: 100)

        // ── Opacity ──
        let opacityHead = makeSectionHeader("Opacity")
        barAlphaLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        barAlphaLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        barAlphaLabel.translatesAutoresizingMaskIntoConstraints = false
        barAlphaLabel.setContentHuggingPriority(.required, for: .horizontal)
        configureAlphaSlider(barAlphaSlider, value: Settings.shared.barAlpha)
        let opacityRow = makeSliderRow(title: "Bar", slider: barAlphaSlider, pctLabel: barAlphaLabel)

        // ── Reset ──
        let resetBtn = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults(_:)))
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        resetBtn.isBordered = false
        resetBtn.font = .systemFont(ofSize: 11, weight: .regular)
        resetBtn.contentTintColor = NSColor.white.withAlphaComponent(0.28)

        for v in [appNameLabel, settingsTitleLabel, colorsHead, barColorRow, flashColorRow,
                  opacityHead, opacityRow, resetBtn] {
            root.addSubview(v)
        }

        NSLayoutConstraint.activate([
            // Header
            appNameLabel.topAnchor.constraint(equalTo: root.topAnchor),
            appNameLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            settingsTitleLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 2),
            settingsTitleLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            // Colors
            colorsHead.topAnchor.constraint(equalTo: settingsTitleLabel.bottomAnchor, constant: sectionSpacing),
            colorsHead.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 2),

            barColorRow.topAnchor.constraint(equalTo: colorsHead.bottomAnchor, constant: 7),
            barColorRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            barColorRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            barColorRow.heightAnchor.constraint(equalToConstant: rowH),

            flashColorRow.topAnchor.constraint(equalTo: barColorRow.bottomAnchor, constant: rowSpacing),
            flashColorRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            flashColorRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            flashColorRow.heightAnchor.constraint(equalToConstant: rowH),

            // Opacity
            opacityHead.topAnchor.constraint(equalTo: flashColorRow.bottomAnchor, constant: sectionSpacing),
            opacityHead.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 2),

            opacityRow.topAnchor.constraint(equalTo: opacityHead.bottomAnchor, constant: 7),
            opacityRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            opacityRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            opacityRow.heightAnchor.constraint(equalToConstant: rowH),

            // Reset
            resetBtn.topAnchor.constraint(equalTo: opacityRow.bottomAnchor, constant: sectionSpacing),
            resetBtn.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            resetBtn.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Row factories

    /// A settings row: glass card with a label on the left and a control on the right.
    private func makeControlRow(title: String, control: NSView, controlWidth: CGFloat) -> NSView {
        let card = makeGlassCard()
        let lbl  = makeLabel(title, size: 13, weight: .regular, alpha: 0.85)
        control.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        card.addSubview(control)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            lbl.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            control.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            control.widthAnchor.constraint(equalToConstant: controlWidth),
        ])
        return card
    }

    private func makeSliderRow(title: String, slider: NSSlider, pctLabel: NSTextField) -> NSView {
        let card = makeGlassCard()
        let lbl  = makeLabel(title, size: 13, weight: .regular, alpha: 0.85)
        slider.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        card.addSubview(slider)
        card.addSubview(pctLabel)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            lbl.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            pctLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            pctLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            slider.trailingAnchor.constraint(equalTo: pctLabel.leadingAnchor, constant: -8),
            slider.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            slider.widthAnchor.constraint(equalToConstant: 108),
        ])
        return card
    }

    // MARK: - Visual primitives

    private func makeGlassCard() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
        v.layer?.cornerRadius = 9
        return v
    }

    private func makeSectionHeader(_ text: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: text.uppercased())
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 10, weight: .semibold)
        lbl.textColor = NSColor.white.withAlphaComponent(0.32)
        return lbl
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: size, weight: weight)
        lbl.textColor = NSColor.white.withAlphaComponent(alpha)
        return lbl
    }

    // MARK: - Configuration

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
