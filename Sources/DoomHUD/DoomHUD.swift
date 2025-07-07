import SwiftUI
import AppKit
import AVFoundation

@main
struct DoomHUDApp: App {
    @StateObject private var trackingManager = TrackingManager()
    @StateObject private var appDelegate = AppDelegate()
    
    init() {
        print("🎮 DoomHUD Starting...")
        print("🎮 Bundle path: \(Bundle.main.bundlePath)")
        print("🎮 Process: \(ProcessInfo.processInfo.processName)")
        
        do {
            // Set the app delegate FIRST, before anything else
            NSApplication.shared.delegate = appDelegate
            print("🎮 App delegate set")
            
            NSApplication.shared.setActivationPolicy(.accessory)
            print("🎮 Activation policy set to accessory")
        } catch {
            print("❌ Error during initialization: \(error)")
        }
    }
    
    var body: some Scene {
        Window("DoomHUD", id: "main") {
            ModernHUDView()
                .environmentObject(trackingManager)
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched - triggering Input Monitoring permission")
        
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
}

