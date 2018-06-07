//
//  ViewController.swift
//  computeShaderTest
//
//  Created by StellarBiblos on 2018/05/29.
//  Copyright © 2018年 StellarBiblos. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var CPUComputeButton: NSButton!
    @IBOutlet weak var GPUComputeButton: NSButton!
    @IBOutlet weak var CPUScore: NSTextField!
    @IBOutlet weak var GPUScore: NSTextField!
    @IBOutlet weak var drawSpiralButton: NSButton!
    
    private var pushFlag = true
    private var startTime: Date?
    private var startTimeWithGPU: Date?
    
    private let device = MTLCreateSystemDefaultDevice()!
    private var commandQueue: MTLCommandQueue?
    private var library: MTLLibrary?
    private var computePipelineState: MTLComputePipelineState?
    
    private var digit = 800 * 800
    private var primes: [Bool] = []
    
    let _down = [1,0]
    let _up = [-1,0]
    let _right = [0,1]
    let _left = [0,-1]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        initMetal()
        
        drawSpiralButton.isHidden = true
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func clickedCPUComputeBUtton(_ sender: Any) {
        calcPrime(max: digit)
        CPUComputeButton.isEnabled = false
    }
    
    @IBAction func clickedGPUComputeButton(_ sender: Any) {
        calcPrimeWithGPGPU(max: digit)
        GPUComputeButton.isEnabled = false
    }
    
    @IBAction func clickedUlamButton(_ sender: Any) {
        let story = NSStoryboard(name: NSStoryboard.Name("UlamSpiral"), bundle: nil)
        let vc = story.instantiateInitialController() as! UlamSpiralViewController
        //vc.primes = [[true,true,false,false],[false,false,false,true],[true,true,false,false],[false,false,false,true]]
         vc.primes = self.primes
        self.presentViewControllerAsModalWindow(vc)
    }
}

extension ViewController {
    
    func initMetal () {
        commandQueue = device.makeCommandQueue()
        library = device.makeDefaultLibrary()
        let comp = library?.makeFunction(name: "calcPrimeNum")
        computePipelineState = try! device.makeComputePipelineState(function: comp!)
    }
    
    func calcPrime (max: Int){
        var prime: [Int] = []
        
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "parentQueue", attributes: .concurrent)
        let childQueue = DispatchQueue(label: "childQueue", attributes: .concurrent)
        
        startTime = Date()
        if max <= 1 { return }
        else if max > 1 { prime.append(2) }
        
        if max == 3 {
            prime.append(3)
            return
        }
        
        group.enter()
        queue.async(group: group){
            for i in 4..<max {
                group.enter()
                childQueue.async(group: group) {
                    if i % 2 != 0 {
                        var isPrime = true
                        for j in 2..<i/2 {
                            if i % j == 0 {
                                isPrime = false
                                break
                            }
                        }
                        if isPrime {
                            prime.append(i)
                        }
                    }
                    group.leave()
                }
            }
            group.leave()
        }
        group.notify(queue: DispatchQueue.main) {
            let score = Date().timeIntervalSince(self.startTime!)
            print(score)
            self.CPUScore.stringValue = String(format: "%d: %.4fsec", self.digit, score)
            //            print(prime.count)
            self.CPUComputeButton.isEnabled = true
        }
    }
    
    func calcPrimeWithGPGPU (max: Int) {
        var input: [Int] = []
        var primes: [Bool] = []
        for i in 1..<max+1 {
            input.append(i)
            primes.append(false)
        }
        
        // buffer登録まで
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let computeEncoder = commandBuffer?.makeComputeCommandEncoder()
        let inputBuffer = device.makeBuffer(bytes: input, length: input.byteLength)
        let outputBuffer = device.makeBuffer(bytes: primes, length: primes.byteLength)
        computeEncoder?.setComputePipelineState(computePipelineState!)
        computeEncoder?.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder?.setBuffer(outputBuffer, offset: 0, index: 1)
        
        // threadサイズ
        let width = 64
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (input.count + width - 1) / width, height: 1, depth: 1)
        computeEncoder?.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        startTimeWithGPU = Date()
        computeEncoder?.endEncoding()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "GPUCommandQueue", attributes: .concurrent)
        queue.async(group: group) {
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
        }
        
        group.notify(queue: DispatchQueue.main) {
            let data = Data(bytesNoCopy: (outputBuffer?.contents())!, count: primes.byteLength, deallocator: .none)
            var resultData = [Bool](repeating: false, count: primes.count)
            resultData = data.withUnsafeBytes {
                Array(UnsafeBufferPointer<Bool>(start: $0, count: data.count/MemoryLayout<Bool>.size))
            }
            let score = Date().timeIntervalSince(self.startTimeWithGPU!)
            print(score)
            self.GPUComputeButton.isEnabled = true
            self.drawSpiralButton.isHidden = false
            self.GPUScore.stringValue = String(format: "%d: %.4fsec", self.digit, score)
            
            print(resultData.filter{$0 == true}.count)
            self.primes = resultData
        }
    }
    
    func circle (a: Int, n: Int) -> Int {
        return sigma(a: a ,n: n) - 4 * n
    }
    
    func sigma (a: Int, n: Int) -> Int {
        if n <= -1 {return 0}
        var sum = a * n
        switch n {
        case 0:
            return sum
        default:
            sum += sigma(a: a, n: n - 1)
        }
        return sum
    }
}

extension Array {
    var byteLength: Int {
        return self.count * MemoryLayout.size(ofValue: self[0])
    }
}
