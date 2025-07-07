import Foundation
import AppKit

class ContextTracker: ObservableObject {
    @Published var contextShiftCount: Int = 0
    
    private var currentApp: NSRunningApplication?
    private var appObserver: Any?
    
    init() {
        setupContextTracking()
    }
    
    deinit {
        stopTracking()
    }
    
    private func setupContextTracking() {
        // Track the current active application
        currentApp = NSWorkspace.shared.frontmostApplication
        
        // Observe app activation changes
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppSwitch(notification: notification)
        }
    }
    
    private func handleAppSwitch(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Check if this is actually a different app
        if let currentApp = currentApp, currentApp.bundleIdentifier != newApp.bundleIdentifier {
            DispatchQueue.main.async {
                self.contextShiftCount += 1
            }
        }
        
        currentApp = newApp
    }
    
    func startTracking() {
        if appObserver == nil {
            setupContextTracking()
        }
    }
    
    func stopTracking() {
        if let appObserver = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appObserver)
            self.appObserver = nil
        }
    }
    
    func resetCounter() {
        contextShiftCount = 0
    }
    
    func getSessionCount() -> Int {
        return contextShiftCount
    }
    
    func getCurrentContext() -> String {
        return currentApp?.localizedName ?? "Unknown"
    }
}