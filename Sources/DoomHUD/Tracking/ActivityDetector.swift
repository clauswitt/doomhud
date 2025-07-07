import Foundation
import Combine

class ActivityDetector: ObservableObject {
    @Published var isActive: Bool = true
    @Published var lastActivityTime: Date = Date()
    @Published var inactiveMinutes: Int = 0
    
    private let inactivityThreshold: TimeInterval = 300 // 5 minutes
    private var activityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupActivityTimer()
    }
    
    deinit {
        stopTracking()
    }
    
    private func setupActivityTimer() {
        // Check activity status every 30 seconds
        activityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkActivityStatus()
        }
    }
    
    private func checkActivityStatus() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        let wasActive = isActive
        
        isActive = timeSinceLastActivity < inactivityThreshold
        inactiveMinutes = Int(timeSinceLastActivity / 60)
        
        // Log activity state changes
        if wasActive != isActive {
            print("Activity state changed: \(isActive ? "Active" : "Inactive")")
        }
    }
    
    func recordActivity() {
        lastActivityTime = Date()
        
        // Update active status if we were inactive
        if !isActive {
            isActive = true
            inactiveMinutes = 0
        }
    }
    
    func combineWithMouseTracker(_ mouseTracker: MouseTracker) {
        // Watch for mouse click changes
        mouseTracker.$totalClickCount
            .dropFirst()
            .sink { [weak self] _ in
                self?.recordActivity()
            }
            .store(in: &cancellables)
    }
    
    func combineWithKeystrokeTracker(_ keystrokeTracker: KeystrokeTracker) {
        // Watch for keystroke changes
        keystrokeTracker.$keystrokeCount
            .dropFirst()
            .sink { [weak self] _ in
                self?.recordActivity()
            }
            .store(in: &cancellables)
    }
    
    func startTracking() {
        if activityTimer == nil {
            setupActivityTimer()
        }
    }
    
    func stopTracking() {
        activityTimer?.invalidate()
        activityTimer = nil
        cancellables.removeAll()
    }
    
    func resetActivityTimer() {
        lastActivityTime = Date()
        isActive = true
        inactiveMinutes = 0
    }
    
    func getInactiveMinutes() -> Int {
        return inactiveMinutes
    }
    
    func isInactive() -> Bool {
        return !isActive
    }
}