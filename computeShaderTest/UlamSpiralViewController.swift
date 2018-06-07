//
//  UlamSpiralViewController.swift
//  computeShaderTest
//
//  Created by StellarBiblos on 2018/05/30.
//  Copyright © 2018年 StellarBiblos. All rights reserved.
//

import Cocoa
import SpriteKit
import MetalKit

class UlamSpiralViewController: NSViewController {
    
    @IBOutlet var ulamView: MTKView!
    
    var primes: [Bool]? // presented by segue
    var circledPrimes: [Bool]?
    
    private let device = MTLCreateSystemDefaultDevice()
    private var library: MTLLibrary?
    private var commandQueue: MTLCommandQueue?
    
    private var computePipelineState: MTLComputePipelineState?
    private var ulamTexture: MTLTexture?
    private var computeBuffer: MTLBuffer?
    private var sizeBuffer: MTLBuffer?
    
    override func viewWillAppear() {
        super.viewWillAppear()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ulam loaded")
        ulamView.device = self.device
        ulamView.delegate = self
        initMetal()
        ulamView.framebufferOnly = false
        guard let primes = primes else {
            fatalError()
        }
        ulamView.drawableSize = CGSize(width: sqrt(Double(primes.count)), height: sqrt(Double(primes.count)))
        
    }
    
    func initMetal () {
        guard let device = self.device else {
            fatalError("Could not load MTLDevice")
        }
        library = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
        guard let primes = primes else {
            fatalError("Could not load Primes Data")
        }
        
        let texturePassDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(sqrt(Double(primes.count))), height: Int(sqrt(Double(primes.count))), mipmapped: false)
        texturePassDescriptor.usage = .shaderWrite
        ulamTexture = device.makeTexture(descriptor: texturePassDescriptor)
        let compute = library?.makeFunction(name: "circle_prime")
        computePipelineState = try? device.makeComputePipelineState(function: compute!)
        var size = primes.count * MemoryLayout<Bool>.size
        computeBuffer = device.makeBuffer(bytes: primes, length: size)
        let drawSize:[uint] = [uint(sqrt(Double(primes.count))), uint(sqrt(Double(primes.count)))]
        size = drawSize.count * MemoryLayout<uint>.size
        sizeBuffer = device.makeBuffer(bytes: drawSize, length: size)
    }
}

extension UlamSpiralViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("\(view)")
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {
            fatalError()
        }
        let commandBuffer = commandQueue?.makeCommandBuffer()
        plotCompute(commandBuffer: commandBuffer!, drawable: drawable)
        blit(commandBuffer: commandBuffer!, drawable: drawable)
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
    }
    
    
    func plotCompute(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable) {
        guard let texture = ulamTexture else {
            fatalError()
        }
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder?.setComputePipelineState(computePipelineState!)
        computeEncoder?.setTexture(ulamTexture, index: 0)
        computeEncoder?.setBuffer(computeBuffer, offset: 0, index: 0)
        computeEncoder?.setBuffer(sizeBuffer, offset: 0, index: 1)
        let threadGroupSize = MTLSize(width: 32, height: 32, depth: 1)
        let w = (texture.width + threadGroupSize.width - 1)/threadGroupSize.width
        let h = (texture.height + threadGroupSize.height - 1)/threadGroupSize.height
        let threadGroupCount = MTLSize(width: w, height: h, depth: 1)
        computeEncoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        computeEncoder?.endEncoding()
    }
    
    func blit(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable) {
        guard let texture = ulamTexture else {
            fatalError()
        }
        let w = min(texture.width, drawable.texture.width)
        let h = min(texture.height, drawable.texture.height)
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSizeMake(w, h, texture.depth),
                          to: drawable.texture, destinationSlice: 0, destinationLevel: 0,
                          destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder?.endEncoding()
    }
    
}

