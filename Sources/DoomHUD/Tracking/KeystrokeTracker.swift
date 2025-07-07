import Foundation
import AppKit

class KeystrokeTracker: ObservableObject {
    @Published var keystrokeCount: Int = 0
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    init() {
        setupGlobalMonitor()
    }
    
    deinit {
        stopTracking()
    }
    
    private func setupGlobalMonitor() {
        // Global monitor for when app is not active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeystroke(event: event)
        }
        
        // Local monitor for when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeystroke(event: event)
            return event
        }
    }
    
    private func handleKeystroke(event: NSEvent) {
        // Filter out modifier keys alone (we want actual character input)
        let modifierFlags = event.modifierFlags
        let isOnlyModifier = modifierFlags.contains(.command) || 
                            modifierFlags.contains(.control) || 
                            modifierFlags.contains(.option) || 
                            modifierFlags.contains(.shift)
        
        // Count keystroke if it's not just a modifier key
        if !isOnlyModifier || !(event.characters?.isEmpty ?? true) {
            DispatchQueue.main.async {
                self.keystrokeCount += 1
            }
        }
    }
    
    func startTracking() {
        if globalMonitor == nil && localMonitor == nil {
            setupGlobalMonitor()
        }
    }
    
    func stopTracking() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
    
    func resetCounter() {
        keystrokeCount = 0
    }
    
    func getSessionCount() -> Int {
        return keystrokeCount
    }
}