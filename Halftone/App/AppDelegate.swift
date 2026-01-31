//
//  AppDelegate.swift
//  Halftone
//
//  Main application delegate - manages app lifecycle and coordinates components
//

import Cocoa
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var overlayWindowController: OverlayWindowController?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: applicationDidFinishLaunching started")

        // Request screen capture permission if needed
        requestScreenCapturePermission()

        // Initialize status bar
        print("DEBUG: Creating StatusBarController")
        statusBarController = StatusBarController()
        print("DEBUG: StatusBarController created: \(statusBarController != nil)")

        // Initialize overlay window (hidden initially)
        overlayWindowController = OverlayWindowController()

        // Initialize hotkey manager
        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleEffect()
        }

        // Observe app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appStateDidChange),
            name: AppState.didChangeNotification,
            object: nil
        )

        // Apply initial state
        updateEffectState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save state
        AppState.shared.save()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Effect Control

    private func toggleEffect() {
        AppState.shared.isEnabled.toggle()
    }

    @objc private func appStateDidChange() {
        updateEffectState()
    }

    private func updateEffectState() {
        if AppState.shared.isEnabled {
            overlayWindowController?.showOverlay()
        } else {
            overlayWindowController?.hideOverlay()
        }
    }

    // MARK: - Permissions

    private func requestScreenCapturePermission() {
        // Check if we have permission
        Task {
            do {
                // This will trigger the permission dialog if needed
                let content = try await SCShareableContent.current
                print("Screen capture permission granted. Found \(content.displays.count) display(s).")
            } catch {
                print("Screen capture permission error: \(error)")
                showPermissionAlert()
            }
        }
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "Halftone needs screen recording permission to apply the effect. Please grant permission in System Settings > Privacy & Security > Screen Recording."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
