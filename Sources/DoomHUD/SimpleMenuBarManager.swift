import Foundation
import AppKit
import SwiftUI

class SimpleMenuBarManager: ObservableObject {
    @Published var isVisible: Bool = true
    
    private var statusItem: NSStatusItem?
    private var trackingManager: TrackingManager?
    
    init() {
        setupMenuBar()
    }
    
    deinit {
        cleanup()
    }
    
    func configure(trackingManager: TrackingManager) {
        self.trackingManager = trackingManager
        updateMenu()
        startPeriodicUpdates()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "💀" // DOOM skull emoji
            button.toolTip = "DoomHUD - Productivity Tracker"
        }
        
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Title
        let titleItem = NSMenuItem(title: "DOOM HUD", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Status section
        if let manager = trackingManager {
            let statusItem = NSMenuItem(
                title: manager.isTracking ? "🟢 TRACKING ACTIVE" : "🔴 TRACKING PAUSED",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            
            // Session duration
            let durationItem = NSMenuItem(
                title: "Session: \(manager.sessionTime)",
                action: nil,
                keyEquivalent: ""
            )
            durationItem.isEnabled = false
            menu.addItem(durationItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Metrics
            let mouseItem = NSMenuItem(title: "Mouse Clicks: \(manager.mouseClicks)", action: nil, keyEquivalent: "")
            mouseItem.isEnabled = false
            menu.addItem(mouseItem)
            
            let keystrokeItem = NSMenuItem(title: "Keystrokes: \(manager.keystrokes)", action: nil, keyEquivalent: "")
            keystrokeItem.isEnabled = false
            menu.addItem(keystrokeItem)
            
            let contextItem = NSMenuItem(title: "Context Shifts: \(manager.contextShifts)", action: nil, keyEquivalent: "")
            contextItem.isEnabled = false
            menu.addItem(contextItem)
            
            let gitItem = NSMenuItem(title: "Git Commits: \(manager.gitCommits)", action: nil, keyEquivalent: "")
            gitItem.isEnabled = false
            menu.addItem(gitItem)
            
            let screenshotItem = NSMenuItem(title: "Screenshots: \(manager.screenshotCount)", action: nil, keyEquivalent: "")
            screenshotItem.isEnabled = false
            menu.addItem(screenshotItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Git info
            if manager.lastCommitProject != "None" {
                let lastCommitItem = NSMenuItem(title: "Last commit: \(manager.lastCommitProject)", action: nil, keyEquivalent: "")
                lastCommitItem.isEnabled = false
                menu.addItem(lastCommitItem)
                
                let timeSinceItem = NSMenuItem(title: "Time since: \(manager.timeSinceLastCommit)", action: nil, keyEquivalent: "")
                timeSinceItem.isEnabled = false
                menu.addItem(timeSinceItem)
                
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // Screenshot folder
        let screenshotsItem = NSMenuItem(title: "Open Screenshots Folder", action: #selector(openScreenshotsFolder), keyEquivalent: "")
        screenshotsItem.target = self
        menu.addItem(screenshotsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About and help
        let aboutItem = NSMenuItem(title: "About DoomHUD", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let hotkeysItem = NSMenuItem(title: "Show Hotkeys", action: #selector(showHotkeys), keyEquivalent: "")
        hotkeysItem.target = self
        menu.addItem(hotkeysItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit DoomHUD", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command, .shift]
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Menu Actions
    
    @objc func openScreenshotsFolder() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        
        NSWorkspace.shared.open(screenshotsDir)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DoomHUD v1.0"
        alert.informativeText = """
        A productivity tracking application inspired by classic DOOM aesthetics.
        
        Tracks mouse clicks, keystrokes, context switches, and git commits.
        Captures screenshots for productivity analysis.
        
        Built with SwiftUI for modern macOS.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func showHotkeys() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts & Controls"
        alert.informativeText = """
        🖱️ Click "Quit App" button in the HUD
        
        📋 Menu Bar Options:
        • Click the 💀 skull icon in menu bar
        • Select "Quit DoomHUD"
        
        ⌨️ Keyboard Shortcut:
        • ⌘⇧Q - Quit Application
        
        🎯 The app runs as a floating HUD overlay
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Utility Methods
    
    private func startPeriodicUpdates() {
        // Update menu every 30 seconds to reflect current metrics
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenu()
            }
        }
    }
    
    private func cleanup() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    // MARK: - Public Interface
    
    func hide() {
        statusItem?.isVisible = false
        isVisible = false
    }
    
    func show() {
        statusItem?.isVisible = true
        isVisible = true
    }
}