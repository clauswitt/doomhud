import Foundation
import Combine
import AppKit

class TrackingCoordinator: ObservableObject {
    @Published var isTracking: Bool = false
    @Published var currentSession: Session?
    
    // Tracking components
    @Published var mouseTracker = MouseTracker()
    @Published var keystrokeTracker = KeystrokeTracker()
    @Published var contextTracker = ContextTracker()
    @Published var activityDetector = ActivityDetector()
    @Published var gitTracker = GitTracker()
    @Published var webcamManager = WebcamManager()
    @Published var permissionManager = PermissionManager()
    
    // Screenshot and timelapse
    @Published var screenshotManager: ScreenshotManager
    @Published var timelapseGenerator: TimelapseGenerator
    
    // Controls
    @Published var hotkeyManager = HotkeyManager()
    @Published var menuBarManager = MenuBarManager()
    
    // Database
    private let databaseManager: DatabaseManager
    
    // Timers
    private var metricsTimer: Timer?
    private var sessionTimer: Timer?
    
    // State
    private var cancellables = Set<AnyCancellable>()
    
    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        self.screenshotManager = ScreenshotManager(databaseManager: databaseManager)
        self.timelapseGenerator = TimelapseGenerator(databaseManager: databaseManager)
        
        setupTracking()
        setupActivityDetection()
        setupHotkeys()
        setupMenuBar()
    }
    
    deinit {
        stopTracking()
    }
    
    private func setupTracking() {
        // Start a new session
        currentSession = Session()
        
        // Setup activity detection combining mouse and keyboard
        activityDetector.combineWithMouseTracker(mouseTracker)
        activityDetector.combineWithKeystrokeTracker(keystrokeTracker)
        
        // Setup timers
        setupMetricsTimer()
        setupSessionTimer()
    }
    
    private func setupActivityDetection() {
        // Combine webcam motion with activity detection
        webcamManager.$isMotionDetected
            .sink { [weak self] isMotionDetected in
                if isMotionDetected {
                    self?.activityDetector.recordActivity()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupHotkeys() {
        hotkeyManager.registerHotkeys(
            pauseAction: { [weak self] in
                self?.pauseTracking()
            },
            resumeAction: { [weak self] in
                self?.resumeTracking()
            },
            timelapseAction: { [weak self] in
                self?.timelapseGenerator.generateTimelapseForToday()
            },
            quitAction: {
                NSApplication.shared.terminate(nil)
            }
        )
    }
    
    private func setupMenuBar() {
        menuBarManager.configure(
            trackingCoordinator: self,
            screenshotManager: screenshotManager,
            timelapseGenerator: timelapseGenerator
        )
        menuBarManager.updateMenuPeriodically()
    }
    
    private func setupMetricsTimer() {
        // Save metrics every 30 seconds
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.saveCurrentMetrics()
        }
    }
    
    private func setupSessionTimer() {
        // Update session every 5 minutes
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateCurrentSession()
        }
    }
    
    private func saveCurrentMetrics() {
        guard let session = currentSession else { return }
        
        let metric = MetricData(
            mouseClicks: mouseTracker.totalClickCount,
            keystrokes: keystrokeTracker.keystrokeCount,
            contextShifts: contextTracker.contextShiftCount,
            gitCommits: gitTracker.sessionCommits,
            sessionId: session.id,
            isActive: activityDetector.isActive
        )
        
        databaseManager.saveMetric(metric)
    }
    
    private func updateCurrentSession() {
        guard var session = currentSession else { return }
        
        // Update session totals
        session.totalMouseClicks = mouseTracker.totalClickCount
        session.totalKeystrokes = keystrokeTracker.keystrokeCount
        session.totalContextShifts = contextTracker.contextShiftCount
        session.totalGitCommits = gitTracker.sessionCommits
        session.activeMinutes = Int(Date().timeIntervalSince(session.startTime) / 60)
        
        // Save to database
        databaseManager.saveSession(session)
        
        // Update published session
        currentSession = session
    }
    
    func startTracking() {
        guard !isTracking else { return }
        
        // Check permissions first
        permissionManager.checkAllPermissions()
        
        if !permissionManager.allPermissionsGranted {
            print("Missing permissions: \(permissionManager.missingPermissions)")
            permissionManager.requestAllPermissions()
            return
        }
        
        // Start all trackers
        mouseTracker.startTracking()
        keystrokeTracker.startTracking()
        contextTracker.startTracking()
        activityDetector.startTracking()
        gitTracker.startTracking()
        webcamManager.startCapture()
        
        // Start screenshot capture if activity is detected
        if activityDetector.isActive {
            screenshotManager.startCapture()
        }
        
        isTracking = true
        
        print("Tracking started")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        // Stop all trackers
        mouseTracker.stopTracking()
        keystrokeTracker.stopTracking()
        contextTracker.stopTracking()
        activityDetector.stopTracking()
        gitTracker.stopTracking()
        webcamManager.stopCapture()
        screenshotManager.stopCapture()
        
        // Stop timers
        metricsTimer?.invalidate()
        sessionTimer?.invalidate()
        metricsTimer = nil
        sessionTimer = nil
        
        // End current session
        if var session = currentSession {
            session.end()
            databaseManager.saveSession(session)
        }
        
        isTracking = false
        
        print("Tracking stopped")
    }
    
    func pauseTracking() {
        if isTracking {
            stopTracking()
        }
    }
    
    func resumeTracking() {
        if !isTracking {
            startTracking()
        }
    }
    
    func resetSessionCounts() {
        mouseTracker.resetCounters()
        keystrokeTracker.resetCounter()
        contextTracker.resetCounter()
        gitTracker.resetSessionCount()
        activityDetector.resetActivityTimer()
        webcamManager.resetMotionDetection()
        
        // Start new session
        currentSession = Session()
    }
    
    func getCurrentMetrics() -> (mouseClicks: Int, keystrokes: Int, contextShifts: Int, gitCommits: Int, isActive: Bool) {
        return (
            mouseClicks: mouseTracker.totalClickCount,
            keystrokes: keystrokeTracker.keystrokeCount,
            contextShifts: contextTracker.contextShiftCount,
            gitCommits: gitTracker.sessionCommits,
            isActive: activityDetector.isActive
        )
    }
    
    func getSessionDuration() -> TimeInterval {
        guard let session = currentSession else { return 0 }
        return Date().timeIntervalSince(session.startTime)
    }
    
    func getSessionDurationString() -> String {
        let duration = getSessionDuration()
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}