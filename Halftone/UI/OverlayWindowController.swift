//
//  OverlayWindowController.swift
//  Halftone
//
//  Click-through fullscreen overlay window for rendering halftone effect
//

import Cocoa
import MetalKit

class OverlayWindowController: NSObject {

    private var window: NSWindow?
    private var metalView: MTKView?
    private var renderer: HalftoneRenderer?
    private var captureManager: ScreenCaptureManager?

    override init() {
        super.init()
        setupWindow()
        setupMetal()
    }

    // MARK: - Setup

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }

        // Use full screen frame to match capture
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Configure as overlay - use .normal + 1 to be above normal windows but below menu bar
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true  // Click-through
        window.sharingType = .none  // Exclude from screenshots/recordings
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false

        self.window = window

        print("DEBUG: Window created at frame: \(screen.frame)")
    }

    private func setupMetal() {
        guard let window = window,
              let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        // Create Metal view
        let metalView = MTKView(frame: window.contentView?.bounds ?? .zero, device: device)
        metalView.autoresizingMask = [.width, .height]
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isPaused = true  // We'll drive rendering from capture callbacks
        metalView.enableSetNeedsDisplay = false

        window.contentView?.addSubview(metalView)
        self.metalView = metalView

        // Create renderer
        guard let renderer = HalftoneRenderer(device: device) else {
            print("Failed to create renderer")
            return
        }
        metalView.delegate = renderer
        self.renderer = renderer

        // Create capture manager
        let captureManager = ScreenCaptureManager(device: device)
        captureManager.delegate = self
        self.captureManager = captureManager
    }

    // MARK: - Public Interface

    /// Show the overlay and start capturing
    func showOverlay() {
        guard let window = window else { return }

        print("DEBUG: showOverlay called")

        // Set excluded window for capture
        captureManager?.setExcludedWindow(CGWindowID(window.windowNumber))

        window.orderFront(nil)
        metalView?.isPaused = false

        // Start capture
        Task {
            do {
                print("DEBUG: Starting screen capture...")
                try await captureManager?.startCapture()
                print("DEBUG: Screen capture started successfully")
            } catch {
                print("DEBUG: Failed to start capture: \(error)")
                // If capture fails, hide the overlay
                await MainActor.run {
                    self.hideOverlay()
                    AppState.shared.isEnabled = false
                }
            }
        }

        // Safety timeout: auto-disable after 30 seconds for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if AppState.shared.isEnabled {
                print("DEBUG: Safety timeout - disabling effect")
                AppState.shared.isEnabled = false
            }
        }
    }

    /// Hide the overlay and stop capturing
    func hideOverlay() {
        metalView?.isPaused = true
        window?.orderOut(nil)

        // Stop capture
        Task {
            await captureManager?.stopCapture()
        }
    }
}

// MARK: - ScreenCaptureDelegate

extension OverlayWindowController: ScreenCaptureDelegate {

    private static var frameCount = 0

    func screenCaptureManager(_ manager: ScreenCaptureManager, didCaptureTexture texture: MTLTexture) {
        Self.frameCount += 1
        if Self.frameCount % 30 == 1 {  // Log every ~1 second at 30fps
            print("DEBUG: Frame \(Self.frameCount) - texture size: \(texture.width)x\(texture.height)")
        }

        // Update renderer with new texture
        renderer?.updateScreenTexture(texture)

        // Trigger redraw
        metalView?.draw()
    }

    func screenCaptureManagerDidStop(_ manager: ScreenCaptureManager) {
        print("DEBUG: Capture stopped - hiding overlay")
        hideOverlay()
        AppState.shared.isEnabled = false
    }
}
