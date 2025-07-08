import SwiftUI
import AppKit
import AVFoundation
import Combine

@main
struct DoomHUDApp: App {
    @NSApplicationDelegateAdaptor(HUDAppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView() // Required to avoid crash
        }
    }
}

class HUDAppDelegate: NSObject, NSApplicationDelegate {
    var window: HUDWindow!
    var trackingManager: TrackingManager!
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎮 DoomHUD Starting...")
        print("🎮 Bundle path: \(Bundle.main.bundlePath)")
        print("🎮 Process: \(ProcessInfo.processInfo.processName)")
        
        // Set activation policy
        NSApplication.shared.setActivationPolicy(.accessory)
        print("🎮 Activation policy set to accessory")
        
        // Initialize tracking manager
        trackingManager = TrackingManager()
        
        // Create the main content view
        let contentView = ModernHUDView()
            .environmentObject(trackingManager)
        
        // Create hosting controller
        let hosting = NSHostingController(rootView: contentView)
        
        // Calculate window frame
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 120)
        let windowFrame = NSRect(
            x: screen.midX - 400,
            y: screen.minY + screen.height * 0.1,
            width: 800,
            height: 120
        )
        
        // Create the HUD window
        window = HUDWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hosting
        window.configure(with: trackingManager)
        window.makeKeyAndOrderFront(nil)
        
        // Set up observer for alwaysOnTop changes
        trackingManager.$alwaysOnTop
            .sink { [weak self] _ in
                self?.window.updateWindowLevel()
            }
            .store(in: &cancellables)
        
        // Trigger Input Monitoring permission
        triggerInputMonitoringPermission()
        
        print("✅ HUD window created and displayed")
    }
    
    private func triggerInputMonitoringPermission() {
        print("🚀 Triggering Input Monitoring permission")
        
        // Create an event tap IMMEDIATELY to trigger the permission dialog
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
        
        let earlyTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Just pass through - this is only to trigger permission
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )
        
        if let tap = earlyTap {
            // Try to enable it to trigger permission dialog
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            
            print("🔐 Early event tap created to trigger Input Monitoring prompt")
            
            // Clean up after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                CGEvent.tapEnable(tap: tap, enable: false)
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
                CFMachPortInvalidate(tap)
                print("🔐 Early event tap cleaned up")
            }
        } else {
            print("❌ Failed to create early event tap - permission dialog may not appear")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Save final metrics before quitting
        trackingManager.saveCurrentMetrics()
        print("💾 Saved final metrics before quit")
    }
}

