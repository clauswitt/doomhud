import Foundation
import AVFoundation
import CoreImage
import AppKit

class VideoExporter: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatus = "Ready"
    @Published var lastExportedVideo: URL?
    
    private var exportTask: Task<Void, Never>?
    
    struct ExportSettings {
        let fps: Int
        let quality: VideoQuality
        let resolution: VideoResolution
        
        enum VideoQuality: String, CaseIterable {
            case high = "High"
            case medium = "Medium" 
            case low = "Low"
            
            var compressionProperties: [String: Any] {
                switch self {
                case .high:
                    return [AVVideoAverageBitRateKey: 8_000_000]
                case .medium:
                    return [AVVideoAverageBitRateKey: 4_000_000]
                case .low:
                    return [AVVideoAverageBitRateKey: 2_000_000]
                }
            }
        }
        
        enum VideoResolution: String, CaseIterable {
            case original = "Original"
            case uhd4k = "4K UHD (3840×2160)"
            case qhd = "QHD (2560×1440)"
            case fhd = "Full HD (1920×1080)"
            case hd = "HD (1280×720)"
            
            var size: CGSize? {
                switch self {
                case .original:
                    return nil
                case .uhd4k:
                    return CGSize(width: 3840, height: 2160)
                case .qhd:
                    return CGSize(width: 2560, height: 1440)
                case .fhd:
                    return CGSize(width: 1920, height: 1080)
                case .hd:
                    return CGSize(width: 1280, height: 720)
                }
            }
        }
    }
    
    func exportTimelapseForDate(_ date: Date, settings: ExportSettings) async {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
            exportStatus = "Preparing export..."
        }
        
        exportTask = Task {
            do {
                let videoURL = try await createTimelapse(for: date, settings: settings)
                
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.exportStatus = "Export completed successfully"
                    self.lastExportedVideo = videoURL
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportStatus = "Export failed: \(error.localizedDescription)"
                }
                print("❌ Export failed: \(error)")
            }
        }
    }
    
    func cancelExport() {
        exportTask?.cancel()
        
        Task { @MainActor in
            isExporting = false
            exportStatus = "Export cancelled"
        }
    }
    
    private func createTimelapse(for date: Date, settings: ExportSettings) async throws -> URL {
        // Get screenshots directory for the specific date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots/\(dateString)")
        
        // Get all screenshot files for the day
        guard FileManager.default.fileExists(atPath: screenshotsDir.path) else {
            throw VideoExportError.noScreenshotsFound
        }
        
        let imageFiles = try FileManager.default.contentsOfDirectory(at: screenshotsDir, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }
        
        guard !imageFiles.isEmpty else {
            throw VideoExportError.noScreenshotsFound
        }
        
        await MainActor.run {
            self.exportStatus = "Found \(imageFiles.count) screenshots"
        }
        
        // Determine video dimensions from first image
        guard let firstImage = NSImage(contentsOf: imageFiles.first!) else {
            throw VideoExportError.invalidImage
        }
        
        var videoSize = firstImage.size
        if let targetSize = settings.resolution.size {
            videoSize = targetSize
        }
        
        // Create output URL
        let outputDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = outputDir.appendingPathComponent("DoomHUD_Timelapse_\(dateString)_\(Int(Date().timeIntervalSince1970)).mp4")
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Setup video writer
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: settings.quality.compressionProperties
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height)
            ]
        )
        
        videoWriter.add(videoWriterInput)
        
        // Start writing
        guard videoWriter.startWriting() else {
            throw VideoExportError.writerSetupFailed
        }
        
        videoWriter.startSession(atSourceTime: CMTime.zero)
        
        await MainActor.run {
            self.exportStatus = "Creating video..."
        }
        
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.fps))
        var frameTime = CMTime.zero
        
        // Process images
        for (index, imageURL) in imageFiles.enumerated() {
            // Check for cancellation
            if Task.isCancelled {
                throw VideoExportError.cancelled
            }
            
            // Update progress
            let progress = Double(index) / Double(imageFiles.count)
            await MainActor.run {
                self.exportProgress = progress
                self.exportStatus = "Processing frame \(index + 1) of \(imageFiles.count)"
            }
            
            // Load and process image
            guard let image = NSImage(contentsOf: imageURL),
                  let pixelBuffer = try? createPixelBuffer(from: image, size: videoSize) else {
                print("⚠️ Skipping invalid image: \(imageURL.lastPathComponent)")
                continue
            }
            
            // Wait for input to be ready
            while !videoWriterInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Append frame
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
            frameTime = CMTimeAdd(frameTime, frameDuration)
        }
        
        // Finish writing
        videoWriterInput.markAsFinished()
        
        await MainActor.run {
            self.exportStatus = "Finalizing video..."
        }
        
        await videoWriter.finishWriting()
        
        if videoWriter.status == AVAssetWriter.Status.completed {
            print("✅ Timelapse exported successfully: \(outputURL.path)")
            print("📁 Export URL for Finder: \(outputURL.absoluteString)")
            return outputURL
        } else {
            throw VideoExportError.exportFailed
        }
    }
    
    private func createPixelBuffer(from image: NSImage, size: CGSize) throws -> CVPixelBuffer {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw VideoExportError.pixelBufferCreationFailed
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            throw VideoExportError.contextCreationFailed
        }
        
        // Scale image to fit the target size
        let imageRect = CGRect(origin: .zero, size: size)
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: imageRect)
        }
        
        return buffer
    }
    
    func getAvailableDates() -> [Date] {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots")
        
        guard FileManager.default.fileExists(atPath: screenshotsDir.path) else {
            return []
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        do {
            let dateDirectories = try FileManager.default.contentsOfDirectory(at: screenshotsDir, includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath }
                .compactMap { url -> Date? in
                    let folderName = url.lastPathComponent
                    return dateFormatter.date(from: folderName)
                }
                .sorted(by: >)
            
            return dateDirectories
        } catch {
            print("❌ Error reading screenshots directory: \(error)")
            return []
        }
    }
    
    func getScreenshotCount(for date: Date) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots/\(dateString)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: screenshotsDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "png" }
            return files.count
        } catch {
            return 0
        }
    }
}

enum VideoExportError: LocalizedError {
    case noScreenshotsFound
    case invalidImage
    case writerSetupFailed
    case exportFailed
    case cancelled
    case pixelBufferCreationFailed
    case contextCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noScreenshotsFound:
            return "No screenshots found for the selected date"
        case .invalidImage:
            return "Invalid image file encountered"
        case .writerSetupFailed:
            return "Failed to setup video writer"
        case .exportFailed:
            return "Video export failed"
        case .cancelled:
            return "Export was cancelled"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer"
        case .contextCreationFailed:
            return "Failed to create graphics context"
        }
    }
}