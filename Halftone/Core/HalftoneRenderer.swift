//
//  HalftoneRenderer.swift
//  Halftone
//
//  Metal rendering pipeline for halftone effect
//

import Foundation
import Metal
import MetalKit
import simd

class HalftoneRenderer: NSObject {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var screenTexture: MTLTexture?

    // Uniform data
    private var uniforms = HalftoneUniforms(dotSize: 8.0, intensity: 1.0, screenSize: SIMD2<Float>(0, 0))

    init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue

        super.init()

        setupPipeline()
        setupVertexBuffer()
    }

    // MARK: - Setup

    private func setupPipeline() {
        print("DEBUG: setupPipeline called")
        guard let library = device.makeDefaultLibrary() else {
            print("DEBUG ERROR: Failed to create default Metal library")
            return
        }
        print("DEBUG: Got Metal library with functions: \(library.functionNames)")

        guard let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
            print("DEBUG ERROR: Failed to load shader functions")
            return
        }
        print("DEBUG: Loaded shader functions")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("DEBUG: Pipeline state created successfully")
        } catch {
            print("DEBUG ERROR: Failed to create pipeline state: \(error)")
        }
    }

    private func setupVertexBuffer() {
        // Fullscreen quad vertices (2 triangles)
        // Position (clip space) and texture coordinates
        let vertices: [Vertex] = [
            // Triangle 1
            Vertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD2<Float>(1, -1), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD2<Float>(-1, 1), texCoord: SIMD2<Float>(0, 0)),
            // Triangle 2
            Vertex(position: SIMD2<Float>(1, -1), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD2<Float>(1, 1), texCoord: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD2<Float>(-1, 1), texCoord: SIMD2<Float>(0, 0)),
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: .storageModeShared)
    }

    // MARK: - Public Interface

    /// Update the screen texture to render
    func updateScreenTexture(_ texture: MTLTexture) {
        screenTexture = texture
    }

    /// Update effect parameters
    func updateUniforms(dotSize: Float, intensity: Float, screenSize: CGSize) {
        uniforms.dotSize = dotSize
        uniforms.intensity = intensity
        uniforms.screenSize = SIMD2<Float>(Float(screenSize.width), Float(screenSize.height))
    }
}

// MARK: - MTKViewDelegate

extension HalftoneRenderer: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Update screen size in uniforms
        uniforms.screenSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    private static var drawCount = 0

    func draw(in view: MTKView) {
        Self.drawCount += 1

        guard let pipelineState = pipelineState else {
            if Self.drawCount % 30 == 1 { print("DEBUG: draw - no pipelineState") }
            return
        }
        guard let vertexBuffer = vertexBuffer else {
            if Self.drawCount % 30 == 1 { print("DEBUG: draw - no vertexBuffer") }
            return
        }
        guard let screenTexture = screenTexture else {
            if Self.drawCount % 30 == 1 { print("DEBUG: draw - no screenTexture") }
            return
        }
        guard let drawable = view.currentDrawable else {
            if Self.drawCount % 30 == 1 { print("DEBUG: draw - no drawable") }
            return
        }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            if Self.drawCount % 30 == 1 { print("DEBUG: draw - no renderPassDescriptor") }
            return
        }

        // Update uniforms from app state AND drawable size
        let state = AppState.shared
        uniforms.dotSize = state.dotSize
        uniforms.intensity = state.intensity
        uniforms.screenSize = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))

        if Self.drawCount % 30 == 1 {
            print("DEBUG: draw #\(Self.drawCount) - screenSize: \(uniforms.screenSize), dotSize: \(uniforms.dotSize), intensity: \(uniforms.intensity)")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(VertexInputIndexVertices.rawValue))
        renderEncoder.setFragmentTexture(screenTexture, index: Int(TextureIndexScreen.rawValue))
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<HalftoneUniforms>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
