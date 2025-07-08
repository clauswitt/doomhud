import SwiftUI
import AppKit
import AVFoundation
import ApplicationServices
import Carbon

class TrackingManager: ObservableObject {
    @Published var mouseClicks = 0
    @Published var keystrokes = 0
    @Published var contextShifts = 0
    @Published var gitCommits = 0
    @Published var lastCommitProject = "None"
    @Published var timeSinceLastCommit = "Never"
    @Published var projectMappingManager = ProjectMappingManager()
    @Published var sessionTime = "00:00"
    @Published var cameraStatus = "Requesting..."
    @Published var hasCameraAccess = false
    @Published var isTracking = false
    @Published var screenshotCount = 0
    @Published var lastScreenshotTime: Date?
    @Published var hasAccessibilityPermission = false
    @Published var hasInputMonitoringPermission = false
    @Published var hasScreenRecordingPermission = false
    
    // Settings (with UserDefaults persistence)
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
        }
    }
    @Published var hudOpacity: Double {
        didSet {
            UserDefaults.standard.set(hudOpacity, forKey: "hudOpacity")
        }
    }
    @Published var screenshotInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(screenshotInterval, forKey: "screenshotInterval")
            // Only update the timer if we're not in initialization
            if isInitialized {
                updateScreenshotInterval()
            }
        }
    }
    
    private var isInitialized = false
    
    // Hotkey settings
    @Published var pauseHotkey = HotkeyConfig(keyCode: kVK_ANSI_P, modifiers: [.command, .control, .option])
    @Published var screenshotHotkey = HotkeyConfig(keyCode: kVK_ANSI_R, modifiers: [.command, .control, .option]) 
    @Published var openFolderHotkey = HotkeyConfig(keyCode: kVK_ANSI_T, modifiers: [.command, .control, .option])
    @Published var quitHotkey = HotkeyConfig(keyCode: kVK_ANSI_Q, modifiers: [.command, .control, .option])
    
    // Computed property for overall permission status
    var allPermissionsGranted: Bool {
        return hasAccessibilityPermission && hasInputMonitoringPermission && hasCameraAccess && hasScreenRecordingPermission
    }
    
    func recheckAllPermissions() {
        print("🔄 Re-checking all permissions...")
        checkPermissions()
        
        // Also restart tracking with updated permissions
        if !isTracking {
            startTracking()
        }
    }
    
    private func startPeriodicPermissionChecking() {
        // Periodic permission checking disabled - only check on startup and manual request
        print("✅ Periodic permission checking disabled - manual checks only")
    }
    
    private var startTime = Date()
    private var sessionTimer: Timer?
    private var screenshotTimer: Timer?
    private var mouseEventTap: CFMachPort?
    private var keyEventMonitor: Any?
    private var appObserver: Any?
    private var currentApp: NSRunningApplication?
    private var cameraManager: SimpleCameraManager?
    private var gitTimer: Timer?
    private var gitRepositories: [URL] = []
    private var lastCommitCounts: [URL: Int] = [:]
    private var lastCommitTime: Date?
    private var lastCommitTimer: Timer?
    @Published var hotkeyManager: HotkeyManager?
    private var statusItem: NSStatusItem?
    private var permissionCheckTimer: Timer?
    private var initialScanTask: Task<Void, Never>?
    
    // Screenshot directory
    private var screenshotsDirectory: URL {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let doomHudDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: doomHudDir, withIntermediateDirectories: true)
        
        return doomHudDir
    }
    
    init() {
        // Initialize settings with saved values from UserDefaults
        self.alwaysOnTop = UserDefaults.standard.object(forKey: "alwaysOnTop") as? Bool ?? true
        self.hudOpacity = UserDefaults.standard.object(forKey: "hudOpacity") as? Double ?? 0.95
        self.screenshotInterval = UserDefaults.standard.object(forKey: "screenshotInterval") as? TimeInterval ?? 60.0
        
        print("🎯 TrackingManager initializing...")
        print("🎯 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🎯 Executable path: \(Bundle.main.executablePath ?? "unknown")")
        print("⚙️ Loaded settings - AlwaysOnTop: \(alwaysOnTop), Opacity: \(hudOpacity), Screenshot Interval: \(screenshotInterval)s")
        
        do {
            setupSessionTimer()
            print("✅ Session timer setup complete")
            
            checkPermissions() // Just check, don't request
            print("✅ Permission check complete")
            
            setupMenuBar()
            print("✅ Menu bar setup complete")
            
            // Delay hotkey setup until after app is fully launched
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.setupHotkeys()
                print("✅ Hotkeys setup complete")
            }
            
            // Delay tracking start to avoid conflicting with early permission tap
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🎯 Starting tracking...")
                self.startTracking() // Always start, even with limited permissions
            }
            
            startGitMonitoring()
            print("✅ Git monitoring started")
            
            // Start background scan for today's commits
            startInitialCommitScan()
            print("✅ Initial commit scan started")
            
            startPeriodicPermissionChecking()
            print("✅ Permission checking started")
            
            // Delay screenshots until after window is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("📸 Starting screenshots...")
                self.startScreenshots()
            }
            
            print("✅ TrackingManager initialization complete")
            
            // Mark as initialized to enable settings updates
            isInitialized = true
        } catch {
            print("❌ Error during TrackingManager initialization: \(error)")
            // Still mark as initialized even if there's an error
            isInitialized = true
        }
    }
    
    deinit {
        stopTracking()
        initialScanTask?.cancel()
    }
    
    private func setupSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateSessionTime()
        }
        
        // Also update time since last commit
        lastCommitTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimeSinceLastCommit()
        }
    }
    
    private func updateSessionTime() {
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) % 3600 / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            sessionTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            sessionTime = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func updateTimeSinceLastCommit() {
        guard let lastTime = lastCommitTime else {
            timeSinceLastCommit = "Never"
            return
        }
        
        let elapsed = Date().timeIntervalSince(lastTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) % 3600 / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            timeSinceLastCommit = String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            timeSinceLastCommit = String(format: "%dm %02ds", minutes, seconds)
        } else {
            timeSinceLastCommit = String(format: "%ds", seconds)
        }
    }
    
    private func checkPermissions() {
        // Just check permissions silently, don't request
        checkCameraPermission()
        checkAccessibilityPermission()
        checkInputMonitoringPermission()
        checkScreenRecordingPermission()
    }
    
    private func checkInputMonitoringPermissionStatus() -> Bool {
        // More reliable method: Try to create and immediately enable an event tap
        // If it fails to enable, we don't have permission
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )
        
        guard let tap = testTap else {
            print("🔐 Event tap creation failed - no permission")
            return false
        }
        
        // Try to enable the tap - this is where permission is really tested
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        
        // Enable and immediately check if it's working
        CGEvent.tapEnable(tap: tap, enable: true)
        let isEnabled = CGEvent.tapIsEnabled(tap: tap)
        
        // Clean up immediately
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CFMachPortInvalidate(tap)
        
        print("🔐 Event tap enabled successfully: \(isEnabled)")
        return isEnabled
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.hasCameraAccess = true
                self.cameraStatus = "Active"
                self.setupCamera()
            }
        case .notDetermined:
            DispatchQueue.main.async {
                self.hasCameraAccess = false
                self.cameraStatus = "Not Requested"
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasCameraAccess = false
                self.cameraStatus = "Denied"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.hasCameraAccess = false
                self.cameraStatus = "Error"
            }
        }
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.hasCameraAccess = granted
                self.cameraStatus = granted ? "Active" : "Denied"
                if granted {
                    self.setupCamera()
                }
            }
        }
    }
    
    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        print("🔐 Accessibility permission: \(trusted ? "✅ Granted" : "❌ Denied")")
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibilityPermission()
        }
    }
    
    private func checkInputMonitoringPermission() {
        let hasPermission = checkInputMonitoringPermissionStatus()
        print("🔐 Input monitoring permission result: \(hasPermission ? "✅ Granted" : "❌ Not granted")")
        print("🔐 Setting hasInputMonitoringPermission to: \(hasPermission)")
        DispatchQueue.main.async {
            print("🔐 UI Update: hasInputMonitoringPermission = \(hasPermission)")
            self.hasInputMonitoringPermission = hasPermission
        }
    }
    
    func requestInputMonitoringPermission() {
        // Create event tap to trigger permission request
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )
        
        if testTap != nil {
            CFMachPortInvalidate(testTap!)
        }
        
        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkInputMonitoringPermission()
        }
    }
    
    private func checkScreenRecordingPermission() {
        let displayID = CGMainDisplayID()
        let testImage = CGDisplayCreateImage(displayID)
        let hasPermission = testImage != nil
        print("🔐 Screen recording permission: \(hasPermission ? "✅ Granted" : "❌ Not granted")")
        DispatchQueue.main.async {
            self.hasScreenRecordingPermission = hasPermission
        }
    }
    
    func requestScreenRecordingPermission() {
        // Trigger screen recording permission by attempting to capture
        let displayID = CGMainDisplayID()
        let _ = CGDisplayCreateImage(displayID)
        
        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkScreenRecordingPermission()
        }
    }
    
    private func setupCamera() {
        cameraManager = SimpleCameraManager()
        cameraManager?.startCamera()
    }
    
    func getCameraManager() -> SimpleCameraManager? {
        return cameraManager
    }
    
    private func updateCameraStatus() {
        DispatchQueue.main.async {
            if self.hasCameraAccess {
                if let cameraManager = self.cameraManager, cameraManager.isRunning {
                    self.cameraStatus = "Active"
                } else {
                    self.cameraStatus = "Stopped"
                }
            } else {
                self.cameraStatus = "No Permission"
            }
            print("📷 Camera status updated: \(self.cameraStatus)")
        }
    }
    
    private func restartTimers() {
        // Restart screenshot timer if we have permission
        if hasScreenRecordingPermission && screenshotTimer == nil {
            screenshotTimer = Timer.scheduledTimer(withTimeInterval: screenshotInterval, repeats: true) { _ in
                self.captureScreenshot()
            }
            print("📸 Screenshot timer restarted")
        }
        
        // Restart git monitoring timer if it's not running
        if gitTimer == nil {
            gitTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                self.checkGitCommits()
            }
            print("🔀 Git monitoring timer restarted")
        }
    }
    
    private func startTracking() {
        guard !isTracking else { return }
        
        print("🎯 Starting input tracking...")
        
        // Check all required permissions before starting
        let hasInputMonitoring = checkInputMonitoringPermissionStatus()
        let hasAccessibility = AXIsProcessTrusted()
        
        print("🔐 Permission check - Input Monitoring: \(hasInputMonitoring ? "✅" : "❌"), Accessibility: \(hasAccessibility ? "✅" : "❌")")
        
        if !hasInputMonitoring {
            print("🔐 ⚠️  Input monitoring not available - mouse and keyboard tracking disabled")
        }
        
        setupMouseTracking()
        setupKeyboardTracking()
        setupContextTracking()
        
        // Restart camera if we have permission
        if hasCameraAccess && cameraManager?.isRunning != true {
            print("📷 Restarting camera...")
            cameraManager?.startCamera()
            // Delay status update to allow camera to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateCameraStatus()
            }
        } else {
            updateCameraStatus()
        }
        
        // Restart activity timers
        restartTimers()
        
        isTracking = true
        print("✅ Tracking started (limited by permissions)")
    }
    
    
    private func stopTracking() {
        isTracking = false
        
        // Stop mouse tracking
        if let eventTap = mouseEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            mouseEventTap = nil
        }
        
        // Stop keyboard tracking
        if let monitor = keyEventMonitor {
            // Check if it's a CGEvent tap (CFMachPort) or NSEvent monitor
            if CFGetTypeID(monitor as CFTypeRef) == CFMachPortGetTypeID() {
                // It's a CGEvent tap
                let eventTap = monitor as! CFMachPort
                CGEvent.tapEnable(tap: eventTap, enable: false)
                CFMachPortInvalidate(eventTap)
            } else {
                // It's an NSEvent monitor
                NSEvent.removeMonitor(monitor)
            }
            keyEventMonitor = nil
        }
        
        // Stop context tracking
        if let observer = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appObserver = nil
        }
        
        // Stop activity timers (but keep session timer running)
        screenshotTimer?.invalidate()
        screenshotTimer = nil
        
        gitTimer?.invalidate()
        gitTimer = nil
        
        // Note: sessionTimer and lastCommitTimer continue running during pause
        
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        
        // Stop camera
        cameraManager?.stopCamera()
        updateCameraStatus()
        
        print("🛑 Tracking stopped")
    }
    
    // MARK: - Mouse Tracking
    
    private func setupMouseTracking() {
        print("🖱️ Setting up mouse tracking...")
        
        // Only try if we have permission
        if !hasInputMonitoringPermission {
            print("⚠️ Skipping mouse tracking - no Input Monitoring permission")
            return
        }
        
        // Check permissions first
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        
        mouseEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let manager = Unmanaged<TrackingManager>.fromOpaque(refcon).takeUnretainedValue()
                    DispatchQueue.main.async {
                        manager.mouseClicks += 1
                        print("🖱️ Mouse click detected! Total: \(manager.mouseClicks)")
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap = mouseEventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("✅ Mouse tracking enabled successfully")
        } else {
            print("❌ Failed to create mouse event tap - permission check may be wrong")
        }
    }
    
    // MARK: - Keyboard Tracking
    
    private func setupKeyboardTracking() {
        print("⌨️ Setting up keyboard tracking...")
        
        // Only try if we have permission
        if !hasInputMonitoringPermission {
            print("⚠️ Skipping keyboard tracking - no Input Monitoring permission")
            return
        }
        
        // Use CGEvent tap for keyboard events too, similar to mouse tracking
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let keyEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let manager = Unmanaged<TrackingManager>.fromOpaque(refcon).takeUnretainedValue()
                    DispatchQueue.main.async {
                        manager.keystrokes += 1
                        print("⌨️ Keystroke detected! Total: \(manager.keystrokes)")
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap = keyEventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("✅ Keyboard tracking enabled with CGEvent tap")
            
            // Store the tap for cleanup
            keyEventMonitor = eventTap
        } else {
            print("❌ Failed to create keyboard event tap - permission check may be wrong")
        }
    }
    
    // MARK: - Context Tracking
    
    private func setupContextTracking() {
        currentApp = NSWorkspace.shared.frontmostApplication
        
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppSwitch(notification: notification)
        }
        
        if appObserver != nil {
            print("✅ Context tracking enabled")
        } else {
            print("❌ Failed to setup context tracking")
        }
    }
    
    private func handleAppSwitch(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        if let currentApp = currentApp, currentApp.bundleIdentifier != newApp.bundleIdentifier {
            contextShifts += 1
        }
        
        currentApp = newApp
    }
    
    // MARK: - Test Functions
    
    func testTracking() {
        print("🧪 Testing tracking functionality...")
        print("🧪 Current counts - Mouse: \(mouseClicks), Keys: \(keystrokes), Context: \(contextShifts)")
        
        // Test if we can increment manually
        mouseClicks += 1
        keystrokes += 1
        print("🧪 After manual increment - Mouse: \(mouseClicks), Keys: \(keystrokes)")
    }
    
    // MARK: - Screenshot Functionality
    
    private func startScreenshots() {
        // Check if we have screen recording permission
        let displayID = CGMainDisplayID()
        let testImage = CGDisplayCreateImage(displayID)
        
        if testImage == nil {
            print("❌ No screen recording permission - screenshots disabled")
            return
        }
        
        print("✅ Screen recording permission available")
        
        // Take initial screenshot
        captureScreenshot()
        
        // Setup timer for regular screenshots with dynamic interval
        screenshotTimer = Timer.scheduledTimer(withTimeInterval: screenshotInterval, repeats: true) { _ in
            self.captureScreenshot()
        }
        
        print("✅ Screenshot timer started (\(Int(screenshotInterval))s interval)")
    }
    
    private func captureScreenshot() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get the main display bounds for capturing all windows
            let displayBounds = CGDisplayBounds(CGMainDisplayID())
            
            // Use CGWindowListCreateImage to capture all visible windows
            // This should include all application windows, not just the desktop
            let windowListOptions: CGWindowListOption = [
                .optionOnScreenOnly,
                .excludeDesktopElements
            ]
            
            // First try with all visible windows
            guard let image = CGWindowListCreateImage(
                displayBounds,
                windowListOptions,
                kCGNullWindowID,
                .bestResolution
            ) else {
                print("❌ Failed to capture screenshot with window list")
                // Fallback to display capture if window list fails
                self.captureDisplayScreenshot()
                return
            }
            
            // Debug: Check image dimensions
            let width = image.width
            let height = image.height
            print("📸 Captured image with windows: \(width)x\(height)")
            
            // Create today's directory
            let today = DateFormatter().dateString(from: Date())
            let todayDir = self.screenshotsDirectory.appendingPathComponent(today)
            try? FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)
            
            // Generate filename with timestamp
            let timestamp = DateFormatter().timeString(from: Date())
            let filename = "screenshot_\(timestamp).png"
            let filePath = todayDir.appendingPathComponent(filename)
            
            // Save image
            if self.saveImage(image, to: filePath) {
                DispatchQueue.main.async {
                    self.screenshotCount += 1
                    self.lastScreenshotTime = Date()
                    print("📸 Screenshot saved: \(filename) (Total: \(self.screenshotCount))")
                    print("📁 Saved to: \(filePath.path)")
                }
            } else {
                print("❌ Failed to save screenshot to: \(filePath.path)")
            }
        }
    }
    
    private func captureDisplayScreenshot() {
        // Fallback method using display capture
        let displayID = CGMainDisplayID()
        
        guard let image = CGDisplayCreateImage(displayID) else {
            print("❌ Failed to capture display screenshot")
            return
        }
        
        // Debug: Check image dimensions
        let width = image.width
        let height = image.height
        print("📸 Captured display image: \(width)x\(height)")
        
        // Create today's directory
        let today = DateFormatter().dateString(from: Date())
        let todayDir = self.screenshotsDirectory.appendingPathComponent(today)
        try? FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)
        
        // Generate filename with timestamp
        let timestamp = DateFormatter().timeString(from: Date())
        let filename = "display_screenshot_\(timestamp).png"
        let filePath = todayDir.appendingPathComponent(filename)
        
        // Save image
        if self.saveImage(image, to: filePath) {
            DispatchQueue.main.async {
                self.screenshotCount += 1
                self.lastScreenshotTime = Date()
                print("📸 Display screenshot saved: \(filename) (Total: \(self.screenshotCount))")
                print("📁 Saved to: \(filePath.path)")
            }
        } else {
            print("❌ Failed to save display screenshot to: \(filePath.path)")
        }
    }
    
    private func saveImage(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return false
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}

// MARK: - Date Formatter Extensions

extension DateFormatter {
    func dateString(from date: Date) -> String {
        self.dateFormat = "yyyy-MM-dd"
        return self.string(from: date)
    }
    
    func timeString(from date: Date) -> String {
        self.dateFormat = "HHmmss"
        return self.string(from: date)
    }
}

// MARK: - Git Tracking Extension

extension TrackingManager {
    private func startGitMonitoring() {
        print("🔍 Starting git repository monitoring...")
        
        // Find git repositories in common locations
        findGitRepositories()
        
        // Check for commits immediately
        checkGitCommits()
        
        // Setup timer to check every 30 seconds
        gitTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.checkGitCommits()
        }
        
        print("✅ Git monitoring started (checking every 30s)")
    }
    
    private func findGitRepositories() {
        // Focus on Documents/Projects with deeper scanning as specified
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let documentsProjectsURL = homeURL.appendingPathComponent("Documents/Projects")
        
        var searchPaths: [URL] = []
        
        // Primary focus: Documents/Projects (scan deeper)
        if FileManager.default.fileExists(atPath: documentsProjectsURL.path) {
            searchPaths.append(documentsProjectsURL)
            print("🔍 Scanning Documents/Projects for git repositories...")
            scanForGitRepos(at: documentsProjectsURL, maxDepth: 6) // Deeper scan for Documents/Projects
        }
        
        // Backup locations (shallower scan)
        let backupPaths = [
            homeURL.appendingPathComponent("Documents"),
            homeURL.appendingPathComponent("Projects"), 
            homeURL.appendingPathComponent("Development"),
            homeURL.appendingPathComponent("Code")
        ]
        
        for path in backupPaths {
            if FileManager.default.fileExists(atPath: path.path) && path != documentsProjectsURL {
                scanForGitRepos(at: path, maxDepth: 3)
            }
        }
        
        // Add current working directory
        if let cwd = ProcessInfo.processInfo.environment["PWD"] {
            let cwdURL = URL(fileURLWithPath: cwd)
            if !searchPaths.contains(cwdURL) {
                scanForGitRepos(at: cwdURL, maxDepth: 2)
            }
        }
        
        print("📁 Found \(gitRepositories.count) git repositories:")
        for repo in gitRepositories {
            // Show relative path from home for cleaner output
            let relativePath = repo.path.replacingOccurrences(of: homeURL.path + "/", with: "~/")
            print("   - \(relativePath)")
        }
    }
    
    private func scanForGitRepos(at url: URL, maxDepth: Int, currentDepth: Int = 0) {
        guard currentDepth < maxDepth else { return }
        
        // Check if this directory is a git repo
        let gitPath = url.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitPath.path) {
            gitRepositories.append(url)
            
            // Get initial commit count
            if let count = getCommitCount(for: url) {
                lastCommitCounts[url] = count
            }
            
            // Register project in mapping manager
            DispatchQueue.main.async {
                let _ = self.projectMappingManager.addProject(at: url.path)
            }
            return // Don't scan subdirectories of git repos
        }
        
        // Scan subdirectories
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            for item in contents {
                if let isDirectory = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                   isDirectory == true,
                   !item.lastPathComponent.starts(with: "."),
                   !["node_modules", "build", "dist", ".build", "DerivedData", "Pods"].contains(item.lastPathComponent) {
                    scanForGitRepos(at: item, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                }
            }
        } catch {
            // Skip directories we can't read
        }
    }
    
    private func checkGitCommits() {
        var totalNewCommits = 0
        var latestCommitRepo: URL?
        
        for repo in gitRepositories {
            if let currentCount = getCommitCount(for: repo) {
                let lastCount = lastCommitCounts[repo] ?? currentCount
                let newCommits = currentCount - lastCount
                
                if newCommits > 0 {
                    totalNewCommits += newCommits
                    latestCommitRepo = repo
                    print("🔀 New commits in \(repo.lastPathComponent): \(newCommits)")
                }
                
                lastCommitCounts[repo] = currentCount
            }
        }
        
        if totalNewCommits > 0 {
            // Cancel initial scan since we have real-time updates
            initialScanTask?.cancel()
            
            DispatchQueue.main.async {
                self.gitCommits += totalNewCommits
                self.lastCommitTime = Date()
                
                if let repo = latestCommitRepo {
                    // Use project mapping manager to get display name
                    self.lastCommitProject = self.projectMappingManager.getDisplayName(for: repo.path)
                }
                
                print("🎉 Total git commits: \(self.gitCommits)")
            }
        }
    }
    
    private func getCommitCount(for repoURL: URL) -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoURL.path, "rev-list", "--count", "HEAD"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Silence errors
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let count = Int(output) {
                    return count
                }
            }
        } catch {
            // Git command failed
        }
        
        return nil
    }
    
    private func startInitialCommitScan() {
        // Cancel any existing scan
        initialScanTask?.cancel()
        
        initialScanTask = Task {
            await scanForTodaysCommits()
        }
    }
    
    private func scanForTodaysCommits() async {
        print("🔍 Scanning for today's commits...")
        
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        
        var latestCommitTime: Date?
        var latestCommitRepo: URL?
        var totalTodaysCommits = 0
        
        for repo in gitRepositories {
            // Check if task was cancelled
            if Task.isCancelled {
                print("🔍 Initial commit scan cancelled")
                return
            }
            
            if let commits = await getTodaysCommits(for: repo, since: startOfToday, until: endOfToday) {
                totalTodaysCommits += commits.count
                
                // Find the latest commit from today
                if let latestInRepo = commits.max(by: { $0.date < $1.date }) {
                    if latestCommitTime == nil || latestInRepo.date > latestCommitTime! {
                        latestCommitTime = latestInRepo.date
                        latestCommitRepo = repo
                    }
                }
                
                print("🔍 Found \(commits.count) commits today in \(repo.lastPathComponent)")
            }
        }
        
        // Update UI on main thread if we found commits from today
        if totalTodaysCommits > 0, let commitTime = latestCommitTime, let commitRepo = latestCommitRepo {
            let commitsCount = totalTodaysCommits // Capture for concurrency safety
            await MainActor.run {
                // Only update if this scan isn't cancelled and no new commits came in during scan
                if !Task.isCancelled {
                    print("🎉 Found \(commitsCount) commits from today, latest at \(commitTime)")
                    self.gitCommits += commitsCount
                    self.lastCommitTime = commitTime
                    self.lastCommitProject = self.projectMappingManager.getDisplayName(for: commitRepo.path)
                }
            }
        } else {
            print("🔍 No commits found from today")
        }
    }
    
    private func getTodaysCommits(for repoURL: URL, since: Date, until: Date) async -> [(date: Date, hash: String)]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone.current
                
                let sinceString = formatter.string(from: since)
                let untilString = formatter.string(from: until)
                
                // Get commits from today with timestamp and hash
                task.arguments = [
                    "-C", repoURL.path,
                    "log",
                    "--since=\(sinceString)",
                    "--until=\(untilString)",
                    "--pretty=format:%H|%ci", // hash|commit date
                    "--no-merges"
                ]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe() // Silence errors
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    if task.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            let commits = self.parseGitLogOutput(output)
                            continuation.resume(returning: commits)
                            return
                        }
                    }
                } catch {
                    // Git command failed
                }
                
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func parseGitLogOutput(_ output: String) -> [(date: Date, hash: String)] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var commits: [(date: Date, hash: String)] = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        for line in lines {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 2 {
                let hash = parts[0]
                let dateString = parts[1]
                
                if let date = formatter.date(from: dateString) {
                    commits.append((date: date, hash: hash))
                }
            }
        }
        
        return commits
    }
    
    func updateScreenshotInterval() {
        // Restart the screenshot timer with new interval
        screenshotTimer?.invalidate()
        
        if hasScreenRecordingPermission {
            screenshotTimer = Timer.scheduledTimer(withTimeInterval: screenshotInterval, repeats: true) { _ in
                self.captureScreenshot()
            }
            print("📸 Screenshot interval updated to \(Int(screenshotInterval)) seconds")
        }
    }
    
    private func setupHotkeys() {
        hotkeyManager = HotkeyManager()
        
        hotkeyManager?.registerHotkeys(
            pauseConfig: pauseHotkey,
            pauseAction: {
                print("🔥 Hotkey: Pause/Resume tracking")
                DispatchQueue.main.async {
                    self.toggleTracking()
                }
            },
            screenshotConfig: screenshotHotkey,
            screenshotAction: {
                print("🔥 Hotkey: Take screenshot now")
                DispatchQueue.main.async {
                    self.captureScreenshot()
                }
            },
            openFolderConfig: openFolderHotkey,
            openFolderAction: {
                print("🔥 Hotkey: Open screenshots folder")
                DispatchQueue.main.async {
                    self.openScreenshotsFolder()
                }
            },
            quitConfig: quitHotkey,
            quitAction: {
                print("🔥 Hotkey: Quit application")
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        )
        
        print("✅ Hotkeys registered:")
        for (action, hotkey) in hotkeyManager?.getAllHotkeys() ?? [:] {
            print("   \(action): \(hotkey)")
        }
    }
    
    private func toggleTracking() {
        if isTracking {
            stopTracking()
            print("⏸️ Tracking paused")
        } else {
            startTracking()
            print("▶️ Tracking resumed")
        }
    }
    
    private func openScreenshotsFolder() {
        NSWorkspace.shared.open(screenshotsDirectory)
        print("📁 Opened screenshots folder")
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "💀"
            button.toolTip = "DoomHUD - Productivity Tracker"
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "DOOM HUD", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit DoomHUD", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command, .control, .option]
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        print("✅ Menu bar item created")
    }
    
    @objc private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
    }
    
}