import Foundation
import AVFoundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

class TimelapseGenerator: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0.0
    @Published var lastTimelapseURL: URL?
    
    private let databaseManager: DatabaseManager
    private let fileManager = FileManager.default
    
    // Video settings
    private let frameRate: Int32 = 12 // 12 fps as specified in PRD
    private let videoQuality: String = AVAssetExportPresetMediumQuality
    
    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }
    
    func generateTimelapseForToday() {
        guard !isGenerating else { return }
        
        let screenshotsDir = getScreenshotsDirectory()
        let todayDir = getTodayDirectory(in: screenshotsDir)
        
        generateTimelapse(from: todayDir, outputName: "timelapse_\(getTodayString()).mp4")
    }
    
    func generateTimelapseForSession() {
        guard !isGenerating else { return }
        
        let screenshotsDir = getScreenshotsDirectory()
        let todayDir = getTodayDirectory(in: screenshotsDir)
        
        // Filter screenshots for current session
        let sessionScreenshots = getSessionScreenshots(in: todayDir)
        
        if sessionScreenshots.isEmpty {
            print("No screenshots found for current session")
            return
        }
        
        let sessionId = GitAppState.shared.sessionId.uuidString.prefix(8)
        generateTimelapse(from: sessionScreenshots, outputName: "session_\(sessionId)_\(getTodayString()).mp4")
    }
    
    private func generateTimelapse(from directory: URL, outputName: String) {
        let screenshots = getScreenshotFiles(in: directory)
        generateTimelapse(from: screenshots, outputName: outputName)
    }
    
    private func generateTimelapse(from screenshots: [URL], outputName: String) {
        guard !screenshots.isEmpty else {
            print("No screenshots available for timelapse")
            return
        }
        
        isGenerating = true
        progress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.createTimelapse(from: screenshots, outputName: outputName)
        }
    }
    
    private func createTimelapse(from screenshots: [URL], outputName: String) {
        let outputDir = getTimelapsesDirectory()
        let outputURL = outputDir.appendingPathComponent(outputName)
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }
        
        // Create asset writer
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            print("Failed to create asset writer")
            finishGeneration(success: false)
            return
        }
        
        // Get first image to determine video dimensions
        guard let firstImageURL = screenshots.first,
              let firstImage = loadImage(from: firstImageURL),
              let cgImage = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to load first image")
            finishGeneration(success: false)
            return
        }
        
        let videoWidth = cgImage.width
        let videoHeight = cgImage.height
        
        // Create video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoWidth * videoHeight * 8, // 8 bits per pixel
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ]
        ]
        
        // Create video input
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterInput.expectsMediaDataInRealTime = false
        
        // Create pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        // Add input to writer
        guard assetWriter.canAdd(assetWriterInput) else {
            print("Cannot add video input to asset writer")
            finishGeneration(success: false)
            return
        }
        
        assetWriter.add(assetWriterInput)
        
        // Start writing
        guard assetWriter.startWriting() else {
            print("Failed to start writing: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
            finishGeneration(success: false)
            return
        }
        
        assetWriter.startSession(atSourceTime: .zero)
        
        // Process screenshots
        let totalFrames = screenshots.count
        var frameIndex = 0
        
        assetWriterInput.requestMediaDataWhenReady(on: DispatchQueue.global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }
            
            while assetWriterInput.isReadyForMoreMediaData && frameIndex < totalFrames {
                let screenshotURL = screenshots[frameIndex]
                
                if let image = self.loadImage(from: screenshotURL),
                   let pixelBuffer = self.createPixelBuffer(from: image, adaptor: pixelBufferAdaptor) {
                    
                    let frameTime = CMTime(value: Int64(frameIndex), timescale: self.frameRate)
                    
                    if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime) {
                        print("Failed to append pixel buffer at frame \(frameIndex)")
                        break
                    }
                }
                
                frameIndex += 1
                
                // Update progress
                DispatchQueue.main.async {
                    self.progress = Double(frameIndex) / Double(totalFrames)
                }
            }
            
            if frameIndex >= totalFrames {
                assetWriterInput.markAsFinished()
                
                assetWriter.finishWriting { [weak self] in
                    guard let self = self else { return }
                    
                    let success = assetWriter.status == .completed
                    
                    if success {
                        // Save to database
                        let duration = Double(totalFrames) / Double(self.frameRate)
                        let fileSize = self.getFileSize(at: outputURL)
                        let sessionId = GitAppState.shared.sessionId
                        
                        let timelapse = TimelapseVideo(
                            filePath: outputURL.path,
                            sessionId: sessionId,
                            duration: duration,
                            frameCount: totalFrames,
                            fileSize: fileSize
                        )
                        
                        self.databaseManager.saveTimelapse(timelapse)
                        
                        DispatchQueue.main.async {
                            self.lastTimelapseURL = outputURL
                        }
                        
                        print("Timelapse created successfully: \(outputName)")
                    } else {
                        print("Timelapse generation failed: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
                    }
                    
                    self.finishGeneration(success: success)
                }
            }
        }
    }
    
    private func loadImage(from url: URL) -> NSImage? {
        return NSImage(contentsOf: url)
    }
    
    private func createPixelBuffer(from image: NSImage, adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            return nil
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        return buffer
    }
    
    private func finishGeneration(success: Bool) {
        DispatchQueue.main.async {
            self.isGenerating = false
            self.progress = success ? 1.0 : 0.0
        }
    }
    
    // MARK: - File Management
    
    private func getScreenshotsDirectory() -> URL {
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportDir.appendingPathComponent("DoomHUD/screenshots")
    }
    
    private func getTimelapsesDirectory() -> URL {
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let timelapsesDir = appSupportDir.appendingPathComponent("DoomHUD/timelapses")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: timelapsesDir, withIntermediateDirectories: true)
        
        return timelapsesDir
    }
    
    private func getTodayDirectory(in parentDir: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return parentDir.appendingPathComponent(today)
    }
    
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getScreenshotFiles(in directory: URL) -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        return files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 < date2
            }
    }
    
    private func getSessionScreenshots(in directory: URL) -> [URL] {
        let sessionStartTime = GitAppState.shared.sessionStartTime
        let allScreenshots = getScreenshotFiles(in: directory)
        
        return allScreenshots.filter { url in
            guard let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate else {
                return false
            }
            return creationDate >= sessionStartTime
        }
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

