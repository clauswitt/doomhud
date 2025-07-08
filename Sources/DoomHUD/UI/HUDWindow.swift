import SwiftUI
import AppKit

class HUDWindow: NSWindow {
    var trackingManager: TrackingManager?
    
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
    
    func configure(with trackingManager: TrackingManager) {
        self.trackingManager = trackingManager
        updateWindowLevel()
    }
    
    private func setupWindow() {
        // Window level will be set by updateWindowLevel()
        
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
    
    func updateWindowLevel() {
        guard let trackingManager = trackingManager else { return }
        
        if trackingManager.alwaysOnTop {
            self.level = .floating
        } else {
            self.level = .normal
        }
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 120
        
        // Position closer to bottom of screen, centered horizontally
        let x = screenFrame.midX - (windowWidth / 2)
        let y = screenFrame.minY + 20 // 20 pixels from bottom
        
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

