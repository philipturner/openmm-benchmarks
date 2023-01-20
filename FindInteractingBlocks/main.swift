//
//  main.swift
//  OpenMMBenchmarks
//
//  Created by Philip Turner on 1/20/23.
//

import Foundation
import Metal

let device = MTLCopyAllDevices().first!
let commandQueue = device.makeCommandQueue()!
let numAtoms = 4096
let numBlocks = (numAtoms + 31) / 32 * 32

let scratchBufferSize = 128 * 128
let buffer_posq = device.makeBuffer(length: scratchBufferSize)!
let buffer_sortedBlocks = device.makeBuffer(length: scratchBufferSize)!
let buffer_return_neighborsInBuffer = device.makeBuffer(length: scratchBufferSize)!
let gridSize = 6144 * 8
let threadgroupSize = 256

let library = device.makeDefaultLibrary()!
let constants = MTLFunctionConstantValues()
do {
    var _numAtoms: UInt32 = UInt32(numAtoms)
    constants.setConstantValue(&_numAtoms, type: .uint, index: 0)
    var _numBlocks: UInt32 = UInt32(numBlocks)
    constants.setConstantValue(&_numBlocks, type: .uint, index: 1)
}
let function = try! library.makeFunction(name: "findBlocksWithInteractions", constantValues: constants)
let pipeline = try! device.makeComputePipelineState(function: function)

let numIterations = 5
for i in 0..<numIterations {
    let shouldCapture = false//i == numIterations - 1
    if shouldCapture {
        let captureManager = MTLCaptureManager.shared()
        let descriptor = MTLCaptureDescriptor()
        descriptor.captureObject = commandQueue
        descriptor.destination = .developerTools
        try! captureManager.startCapture(with: descriptor)
    }

    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(buffer_posq, offset: 0, index: 0)
    encoder.setBuffer(buffer_sortedBlocks, offset: 0, index: 1)
    encoder.setBuffer(buffer_return_neighborsInBuffer, offset: 0, index: 2)
    encoder.dispatchThreads(
        MTLSizeMake(gridSize, 1, 1), threadsPerThreadgroup:
        MTLSizeMake(threadgroupSize, 1, 1))
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    let gpuTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    let microseconds = Int(gpuTime * 1e6)
    print("Iteration \(i): \(microseconds) us")
    
    if shouldCapture {
        MTLCaptureManager.shared().stopCapture()
    }
}
