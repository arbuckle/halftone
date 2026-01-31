//
//  ScreenCaptureManager.swift
//  Halftone
//
//  Manages screen capture using ScreenCaptureKit
//

import Foundation
import ScreenCaptureKit
import Metal
import CoreVideo

protocol ScreenCaptureDelegate: AnyObject {
    func screenCaptureManager(_ manager: ScreenCaptureManager, didCaptureTexture texture: MTLTexture)
    func screenCaptureManagerDidStop(_ manager: ScreenCaptureManager)
}

class ScreenCaptureManager: NSObject {

    weak var delegate: ScreenCaptureDelegate?

    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private let device: MTLDevice
    private var textureCache: CVMetalTextureCache?
    private var excludedWindowID: CGWindowID?

    // Capture at 30 FPS for smooth animation without excessive resource use
    private let targetFrameRate: Int = 30

    init(device: MTLDevice) {
        self.device = device
        super.init()

        // Create texture cache for efficient IOSurface -> MTLTexture conversion
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        self.textureCache = cache
    }

    /// Set the window ID to exclude from capture (the overlay window itself)
    func setExcludedWindow(_ windowID: CGWindowID) {
        self.excludedWindowID = windowID
    }

    /// Start capturing the screen
    func startCapture() async throws {
        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        // Create filter to exclude our overlay window
        var excludedWindows: [SCWindow] = []
        if let excludedID = excludedWindowID {
            excludedWindows = content.windows.filter { $0.windowID == excludedID }
        }

        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        // Configure stream for best quality
        let config = SCStreamConfiguration()
        config.width = Int(display.width) * 2  // Retina resolution
        config.height = Int(display.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 3

        // Create stream with self as delegate to handle stop events
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        // Create output handler
        let output = StreamOutput(manager: self)
        self.streamOutput = output

        // Add stream output
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.halftone.capture"))

        // Start capture
        try await stream.startCapture()
    }

    /// Stop capturing the screen
    func stopCapture() async {
        guard let stream = stream else { return }

        do {
            try await stream.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }

        self.stream = nil
        self.streamOutput = nil
    }

    /// Process a captured sample buffer and convert to Metal texture
    fileprivate func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let textureCache = textureCache else { return }

        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            imageBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess, let cvTexture = cvTexture else {
            print("Failed to create Metal texture from image buffer")
            return
        }

        guard let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to get Metal texture")
            return
        }

        // Notify delegate on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.screenCaptureManager(self, didCaptureTexture: texture)
        }
    }

    enum CaptureError: Error {
        case noDisplay
        case noPermission
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("DEBUG: Stream stopped with error: \(error)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.screenCaptureManagerDidStop(self)
        }
    }
}

// MARK: - Stream Output Handler

private class StreamOutput: NSObject, SCStreamOutput {

    private weak var manager: ScreenCaptureManager?

    init(manager: ScreenCaptureManager) {
        self.manager = manager
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        manager?.processSampleBuffer(sampleBuffer)
    }
}
