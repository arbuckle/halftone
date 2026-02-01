//
//  StatusBarController.swift
//  Halftone
//
//  Menu bar status item with effect controls
//

import Cocoa

class StatusBarController: NSObject {

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    // Menu items that need updating
    private var toggleItem: NSMenuItem?
    private var fineItem: NSMenuItem?
    private var mediumItem: NSMenuItem?
    private var coarseItem: NSMenuItem?
    private var blackOnlyItem: NSMenuItem?

    override init() {
        super.init()
        setupStatusItem()

        // Observe state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuState),
            name: AppState.didChangeNotification,
            object: nil
        )
    }

    // MARK: - Setup

    private func setupStatusItem() {
        print("DEBUG: setupStatusItem called")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        print("DEBUG: statusItem created: \(statusItem != nil)")

        if let button = statusItem?.button {
            print("DEBUG: Got button, setting image")
            button.image = NSImage(systemSymbolName: "circle.grid.3x3.fill", accessibilityDescription: "Halftone")
            print("DEBUG: Image set: \(button.image != nil)")
            button.image?.isTemplate = true
        } else {
            print("DEBUG: ERROR - no button on statusItem!")
        }

        // Create menu
        let menu = NSMenu()

        // Toggle effect
        let toggleItem = NSMenuItem(title: "Enable Effect", action: #selector(toggleEffect), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.toggleItem = toggleItem

        menu.addItem(NSMenuItem.separator())

        // Dot size submenu
        let dotSizeItem = NSMenuItem(title: "Dot Size", action: nil, keyEquivalent: "")
        let dotSizeMenu = NSMenu()

        let fineItem = NSMenuItem(title: "Fine", action: #selector(setDotSizeFine), keyEquivalent: "")
        fineItem.target = self
        dotSizeMenu.addItem(fineItem)
        self.fineItem = fineItem

        let mediumItem = NSMenuItem(title: "Medium", action: #selector(setDotSizeMedium), keyEquivalent: "")
        mediumItem.target = self
        dotSizeMenu.addItem(mediumItem)
        self.mediumItem = mediumItem

        let coarseItem = NSMenuItem(title: "Coarse", action: #selector(setDotSizeCoarse), keyEquivalent: "")
        coarseItem.target = self
        dotSizeMenu.addItem(coarseItem)
        self.coarseItem = coarseItem

        dotSizeItem.submenu = dotSizeMenu
        menu.addItem(dotSizeItem)

        // Black Only toggle
        let blackOnlyItem = NSMenuItem(title: "Black Only", action: #selector(toggleBlackOnly), keyEquivalent: "")
        blackOnlyItem.target = self
        menu.addItem(blackOnlyItem)
        self.blackOnlyItem = blackOnlyItem

        menu.addItem(NSMenuItem.separator())

        // Intensity slider (using custom view)
        let intensityItem = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
        let intensityView = IntensitySliderView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        intensityItem.view = intensityView
        menu.addItem(intensityItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Halftone", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        statusItem?.menu = menu

        // Update initial state
        updateMenuState()
    }

    // MARK: - Actions

    @objc private func toggleEffect() {
        AppState.shared.isEnabled.toggle()
    }

    @objc private func setDotSizeFine() {
        AppState.shared.dotSizePreset = .fine
    }

    @objc private func setDotSizeMedium() {
        AppState.shared.dotSizePreset = .medium
    }

    @objc private func setDotSizeCoarse() {
        AppState.shared.dotSizePreset = .coarse
    }

    @objc private func toggleBlackOnly() {
        AppState.shared.useBlackOnly.toggle()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - State Updates

    @objc private func updateMenuState() {
        let state = AppState.shared

        // Update toggle item
        toggleItem?.title = state.isEnabled ? "Disable Effect" : "Enable Effect"
        toggleItem?.state = state.isEnabled ? .on : .off

        // Update dot size checkmarks
        fineItem?.state = state.dotSizePreset == .fine ? .on : .off
        mediumItem?.state = state.dotSizePreset == .medium ? .on : .off
        coarseItem?.state = state.dotSizePreset == .coarse ? .on : .off

        // Update black only checkmark
        blackOnlyItem?.state = state.useBlackOnly ? .on : .off

        // Update status item icon
        if let button = statusItem?.button {
            let imageName = state.isEnabled ? "circle.grid.3x3.fill" : "circle.grid.3x3"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Halftone")
        }
    }
}

// MARK: - Intensity Slider View

private class IntensitySliderView: NSView {

    private var slider: NSSlider!
    private var label: NSTextField!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Label
        label = NSTextField(labelWithString: "Intensity:")
        label.frame = NSRect(x: 10, y: 5, width: 60, height: 20)
        label.font = NSFont.menuFont(ofSize: 13)
        addSubview(label)

        // Slider
        slider = NSSlider(value: Double(AppState.shared.intensity), minValue: 0, maxValue: 1, target: self, action: #selector(sliderChanged))
        slider.frame = NSRect(x: 70, y: 5, width: 120, height: 20)
        addSubview(slider)

        // Observe state changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateSlider), name: AppState.didChangeNotification, object: nil)
    }

    @objc private func sliderChanged() {
        AppState.shared.intensity = Float(slider.doubleValue)
    }

    @objc private func updateSlider() {
        slider.doubleValue = Double(AppState.shared.intensity)
    }
}
