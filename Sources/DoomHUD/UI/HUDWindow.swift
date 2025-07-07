import SwiftUI
import AppKit

class HUDWindow: NSWindow {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backingStoreType,
            defer: flag
        )
        
        setupWindow()
    }
    
    private func setupWindow() {
        // Make window always on top
        self.level = .floating
        
        // Make window non-activating (won't steal focus)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Set background to transparent
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        
        // Disable window controls
        self.hasShadow = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        // Position window at bottom center of screen
        positionWindow()
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 120
        
        // Position at bottom 20% of screen, centered horizontally
        let x = screenFrame.midX - (windowWidth / 2)
        let y = screenFrame.minY + (screenFrame.height * 0.1) // 10% from bottom
        
        self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }
    
    // Prevent window from becoming key or main
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    // Allow clicks to pass through transparent areas
    override func mouseDown(with event: NSEvent) {
        // Only handle clicks on opaque content
        let location = event.locationInWindow
        if let contentView = self.contentView {
            let hitView = contentView.hitTest(location)
            if hitView != nil {
                super.mouseDown(with: event)
            } else {
                // Pass through to window below
                if let windowBelow = self.windowBelow(at: location) {
                    windowBelow.mouseDown(with: event)
                }
            }
        }
    }
    
    private func windowBelow(at point: NSPoint) -> NSWindow? {
        let globalPoint = NSPoint(x: self.frame.minX + point.x, y: self.frame.minY + point.y)
        
        for window in NSApplication.shared.windows {
            if window != self && window.frame.contains(globalPoint) {
                return window
            }
        }
        return nil
    }
}

// Custom WindowGroup for HUD
struct HUDWindowGroup: Scene {
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some Scene {
        WindowGroup {
            content
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// Helper to access and configure the NSWindow
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            if let window = view.window {
                // Replace the default window with our HUD window
                let hudWindow = HUDWindow(
                    contentRect: window.frame,
                    styleMask: window.styleMask,
                    backing: window.backingType,
                    defer: false
                )
                
                // Transfer content
                hudWindow.contentView = window.contentView
                
                // Show the HUD window
                hudWindow.makeKeyAndOrderFront(nil)
                
                // Hide the original window
                window.orderOut(nil)
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}