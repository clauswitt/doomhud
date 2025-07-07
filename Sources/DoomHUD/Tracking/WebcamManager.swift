import Foundation
import AVFoundation
import SwiftUI

class WebcamManager: NSObject, ObservableObject {
    @Published var isMotionDetected: Bool = false
    @Published var lastMotionTime: Date = Date()
    @Published var isWebcamActive: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var previousPixelBuffer: CVPixelBuffer?
    private let motionThreshold: Double = 0.1
    private let motionQueue = DispatchQueue(label: "motionDetection", qos: .userInitiated)
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    deinit {
        stopCapture()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        // Configure session
        captureSession.sessionPreset = .medium
        
        // Setup video input
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("No video device available")
            return
        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput!) {
                captureSession.addInput(videoInput!)
            }
        } catch {
            print("Error setting up video input: \(error)")
            return
        }
        
        // Setup video output
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: motionQueue)
        
        if captureSession.canAddOutput(videoOutput!) {
            captureSession.addOutput(videoOutput!)
        }
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
    }
    
    func startCapture() {
        guard let captureSession = captureSession else { return }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isWebcamActive = true
                }
            }
        }
    }
    
    func stopCapture() {
        guard let captureSession = captureSession else { return }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
            isWebcamActive = false
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    private func detectMotion(in pixelBuffer: CVPixelBuffer) -> Bool {
        guard let previousBuffer = previousPixelBuffer else {
            previousPixelBuffer = pixelBuffer
            return false
        }
        
        let motionScore = calculateMotionScore(current: pixelBuffer, previous: previousBuffer)
        previousPixelBuffer = pixelBuffer
        
        return motionScore > motionThreshold
    }
    
    private func calculateMotionScore(current: CVPixelBuffer, previous: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(current, .readOnly)
        CVPixelBufferLockBaseAddress(previous, .readOnly)
        
        defer {
            CVPixelBufferUnlockBaseAddress(current, .readOnly)
            CVPixelBufferUnlockBaseAddress(previous, .readOnly)
        }
        
        let currentWidth = CVPixelBufferGetWidth(current)
        let currentHeight = CVPixelBufferGetHeight(current)
        let previousWidth = CVPixelBufferGetWidth(previous)
        let previousHeight = CVPixelBufferGetHeight(previous)
        
        guard currentWidth == previousWidth && currentHeight == previousHeight else {
            return 0.0
        }
        
        guard let currentBaseAddress = CVPixelBufferGetBaseAddress(current),
              let previousBaseAddress = CVPixelBufferGetBaseAddress(previous) else {
            return 0.0
        }
        
        let currentBytes = currentBaseAddress.assumingMemoryBound(to: UInt8.self)
        let previousBytes = previousBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        let pixelCount = currentWidth * currentHeight
        let sampleSize = min(pixelCount, 1000) // Sample 1000 pixels for performance
        let step = max(1, pixelCount / sampleSize)
        
        var totalDifference = 0.0
        var sampledPixels = 0
        
        for i in stride(from: 0, to: pixelCount, by: step) {
            let currentPixel = currentBytes[i * 4] // Red channel
            let previousPixel = previousBytes[i * 4] // Red channel
            
            totalDifference += abs(Double(currentPixel) - Double(previousPixel))
            sampledPixels += 1
        }
        
        let avgDifference = totalDifference / Double(sampledPixels)
        return avgDifference / 255.0 // Normalize to 0-1 range
    }
    
    func resetMotionDetection() {
        previousPixelBuffer = nil
        isMotionDetected = false
    }
    
    func getTimeSinceLastMotion() -> TimeInterval {
        return Date().timeIntervalSince(lastMotionTime)
    }
    
    func hasRecentMotion(within seconds: TimeInterval = 60) -> Bool {
        return getTimeSinceLastMotion() < seconds
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension WebcamManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let motionDetected = detectMotion(in: pixelBuffer)
        
        DispatchQueue.main.async {
            if motionDetected {
                self.isMotionDetected = true
                self.lastMotionTime = Date()
            } else {
                self.isMotionDetected = false
            }
        }
    }
}