import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

class ScreenshotManager: ObservableObject {
    @Published var isCapturing: Bool = false
    @Published var screenshotCount: Int = 0
    @Published var lastScreenshotTime: Date?
    
    private var captureTimer: Timer?
    private let captureInterval: TimeInterval = 60.0 // 60 seconds
    private let fileManager = FileManager.default
    private let databaseManager: DatabaseManager
    
    // File paths
    private var baseDirectory: URL {
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportDir.appendingPathComponent("DoomHUD")
    }
    
    private var screenshotsDirectory: URL {
        return baseDirectory.appendingPathComponent("screenshots")
    }
    
    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        createDirectories()
    }
    
    deinit {
        stopCapture()
    }
    
    private func createDirectories() {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directories: \(error)")
        }
    }
    
    private func getTodayDirectory() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        let todayDir = screenshotsDirectory.appendingPathComponent(today)
        
        // Create today's directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: todayDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create today's directory: \(error)")
        }
        
        return todayDir
    }
    
    func startCapture() {
        guard !isCapturing else { return }
        
        // Check screen recording permission
        if !hasScreenRecordingPermission() {
            print("Screen recording permission not granted")
            return
        }
        
        isCapturing = true
        
        // Take initial screenshot
        captureScreenshot()
        
        // Setup timer for regular captures
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }
        
        print("Screenshot capture started")
    }
    
    func stopCapture() {
        guard isCapturing else { return }
        
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
        
        print("Screenshot capture stopped")
    }
    
    func pauseCapture() {
        if isCapturing {
            stopCapture()
        }
    }
    
    func resumeCapture() {
        if !isCapturing {
            startCapture()
        }
    }
    
    private func captureScreenshot() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get main display ID
            let displayID = CGMainDisplayID()
            
            // Create screenshot
            guard let image = CGDisplayCreateImage(displayID) else {
                print("Failed to create screenshot")
                return
            }
            
            // Generate filename
            let timestamp = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "HHmmss"
            let timeString = formatter.string(from: timestamp)
            
            let filename = "screenshot_\(timeString).png"
            let todayDir = self.getTodayDirectory()
            let filePath = todayDir.appendingPathComponent(filename)
            
            // Save image
            if self.saveImage(image, to: filePath) {
                DispatchQueue.main.async {
                    self.screenshotCount += 1
                    self.lastScreenshotTime = timestamp
                }
                
                // Save to database
                let fileSize = self.getFileSize(at: filePath)
                let sessionId = GitAppState.shared.sessionId
                
                let screenshot = Screenshot(
                    filePath: filePath.path,
                    sessionId: sessionId,
                    isMotionDetected: true, // We'll integrate motion detection later
                    fileSize: fileSize
                )
                
                self.databaseManager.saveScreenshot(screenshot)
                
                print("Screenshot saved: \(filename)")
            }
        }
    }
    
    private func saveImage(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func hasScreenRecordingPermission() -> Bool {
        // Test screen recording permission by attempting to create a small image
        let displayID = CGMainDisplayID()
        let imageRef = CGDisplayCreateImage(displayID)
        return imageRef != nil
    }
    
    func getScreenshotsForToday() -> [String] {
        let todayDir = getTodayDirectory()
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: todayDir.path)
            return files.filter { $0.hasSuffix(".png") }.sorted()
        } catch {
            return []
        }
    }
    
    func getScreenshotPath(filename: String) -> URL? {
        let todayDir = getTodayDirectory()
        let filePath = todayDir.appendingPathComponent(filename)
        
        return fileManager.fileExists(atPath: filePath.path) ? filePath : nil
    }
    
    func deleteScreenshot(filename: String) -> Bool {
        guard let filePath = getScreenshotPath(filename: filename) else { return false }
        
        do {
            try fileManager.removeItem(at: filePath)
            screenshotCount = max(0, screenshotCount - 1)
            return true
        } catch {
            print("Failed to delete screenshot: \(error)")
            return false
        }
    }
    
    func getTotalScreenshotSize() -> Int64 {
        let todayDir = getTodayDirectory()
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: todayDir.path)
            for file in files where file.hasSuffix(".png") {
                let filePath = todayDir.appendingPathComponent(file)
                totalSize += getFileSize(at: filePath)
            }
        } catch {
            print("Failed to calculate total size: \(error)")
        }
        
        return totalSize
    }
    
    func getFormattedTotalSize() -> String {
        let totalBytes = getTotalScreenshotSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}

// Extension to GitAppState for session tracking
extension GitAppState {
    var sessionId: UUID {
        if let storedId = UserDefaults.standard.string(forKey: "current_session_id"),
           let uuid = UUID(uuidString: storedId) {
            return uuid
        } else {
            let newId = UUID()
            UserDefaults.standard.set(newId.uuidString, forKey: "current_session_id")
            return newId
        }
    }
    
    func newSession() {
        let newId = UUID()
        UserDefaults.standard.set(newId.uuidString, forKey: "current_session_id")
    }
}