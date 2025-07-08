import Foundation
import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    @Published var isVisible: Bool = true
    
    private var statusItem: NSStatusItem?
    private var trackingCoordinator: TrackingCoordinator?
    private var screenshotManager: ScreenshotManager?
    private var timelapseGenerator: TimelapseGenerator?
    
    init() {
        setupMenuBar()
    }
    
    deinit {
        cleanup()
    }
    
    func configure(
        trackingCoordinator: TrackingCoordinator,
        screenshotManager: ScreenshotManager,
        timelapseGenerator: TimelapseGenerator
    ) {
        self.trackingCoordinator = trackingCoordinator
        self.screenshotManager = screenshotManager
        self.timelapseGenerator = timelapseGenerator
        updateMenu()
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
        if let coordinator = trackingCoordinator {
            let statusItem = NSMenuItem(
                title: coordinator.isTracking ? "🟢 TRACKING ACTIVE" : "🔴 TRACKING PAUSED",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            
            // Session duration
            let durationItem = NSMenuItem(
                title: "Session: \(coordinator.getSessionDurationString())",
                action: nil,
                keyEquivalent: ""
            )
            durationItem.isEnabled = false
            menu.addItem(durationItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Metrics
            let metrics = coordinator.getCurrentMetrics()
            
            let mouseItem = NSMenuItem(title: "Mouse Clicks: \(metrics.mouseClicks)", action: nil, keyEquivalent: "")
            mouseItem.isEnabled = false
            menu.addItem(mouseItem)
            
            let keystrokeItem = NSMenuItem(title: "Keystrokes: \(metrics.keystrokes)", action: nil, keyEquivalent: "")
            keystrokeItem.isEnabled = false
            menu.addItem(keystrokeItem)
            
            let contextItem = NSMenuItem(title: "Context Shifts: \(metrics.contextShifts)", action: nil, keyEquivalent: "")
            contextItem.isEnabled = false
            menu.addItem(contextItem)
            
            let gitItem = NSMenuItem(title: "Git Commits: \(metrics.gitCommits)", action: nil, keyEquivalent: "")
            gitItem.isEnabled = false
            menu.addItem(gitItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Control actions
        if let coordinator = trackingCoordinator {
            if coordinator.isTracking {
                let pauseItem = NSMenuItem(title: "Pause Tracking", action: #selector(pauseTracking), keyEquivalent: "p")
                pauseItem.keyEquivalentModifierMask = [.command, .control, .option]
                pauseItem.target = self
                menu.addItem(pauseItem)
            } else {
                let resumeItem = NSMenuItem(title: "Resume Tracking", action: #selector(resumeTracking), keyEquivalent: "r")
                resumeItem.keyEquivalentModifierMask = [.command, .control, .option]
                resumeItem.target = self
                menu.addItem(resumeItem)
            }
        }
        
        // Screenshot controls
        if let screenshotMgr = screenshotManager {
            let screenshotItem = NSMenuItem(
                title: screenshotMgr.isCapturing ? "Stop Screenshots" : "Start Screenshots",
                action: #selector(toggleScreenshots),
                keyEquivalent: ""
            )
            screenshotItem.target = self
            menu.addItem(screenshotItem)
            
            if screenshotMgr.screenshotCount > 0 {
                let countItem = NSMenuItem(
                    title: "Screenshots Today: \(screenshotMgr.screenshotCount)",
                    action: #selector(openScreenshotsFolder),
                    keyEquivalent: ""
                )
                countItem.target = self
                menu.addItem(countItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Timelapse generation
        if let timelapseGen = timelapseGenerator {
            if timelapseGen.isGenerating {
                let progressItem = NSMenuItem(
                    title: "Generating Timelapse... \(Int(timelapseGen.progress * 100))%",
                    action: nil,
                    keyEquivalent: ""
                )
                progressItem.isEnabled = false
                menu.addItem(progressItem)
            } else {
                let timelapseItem = NSMenuItem(title: "Generate Timelapse", action: #selector(generateTimelapse), keyEquivalent: "t")
                timelapseItem.keyEquivalentModifierMask = [.command, .control, .option]
                timelapseItem.target = self
                menu.addItem(timelapseItem)
                
                let sessionTimelapseItem = NSMenuItem(title: "Generate Session Timelapse", action: #selector(generateSessionTimelapse), keyEquivalent: "")
                sessionTimelapseItem.target = self
                menu.addItem(sessionTimelapseItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences and utilities
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        let gitDirsItem = NSMenuItem(title: "Manage Git Directories...", action: #selector(manageGitDirectories), keyEquivalent: "")
        gitDirsItem.target = self
        menu.addItem(gitDirsItem)
        
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
        quitItem.keyEquivalentModifierMask = [.command, .control, .option]
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Menu Actions
    
    @objc private func pauseTracking() {
        trackingCoordinator?.pauseTracking()
        updateMenu()
    }
    
    @objc private func resumeTracking() {
        trackingCoordinator?.resumeTracking()
        updateMenu()
    }
    
    @objc private func toggleScreenshots() {
        guard let screenshotMgr = screenshotManager else { return }
        
        if screenshotMgr.isCapturing {
            screenshotMgr.stopCapture()
        } else {
            screenshotMgr.startCapture()
        }
        updateMenu()
    }
    
    @objc private func generateTimelapse() {
        timelapseGenerator?.generateTimelapseForToday()
    }
    
    @objc private func generateSessionTimelapse() {
        timelapseGenerator?.generateTimelapseForSession()
    }
    
    @objc private func openScreenshotsFolder() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots")
        NSWorkspace.shared.open(screenshotsDir)
    }
    
    @objc private func openPreferences() {
        // This would open a preferences window
        showAlert(title: "Preferences", message: "Preferences panel coming soon!")
    }
    
    @objc private func manageGitDirectories() {
        // This would open git directory management
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.title = "Select Git Repositories to Track"
        panel.message = "Choose directories containing git repositories you want to monitor for commits."
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                trackingCoordinator?.gitTracker.addGitDirectory(url.path)
            }
            updateMenu()
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DoomHUD v1.0"
        alert.informativeText = """
        A productivity tracking application inspired by classic DOOM aesthetics.
        
        Tracks mouse clicks, keystrokes, context switches, and git commits.
        Captures screenshots and generates timelapses of your work sessions.
        
        Built with SwiftUI and love for retro gaming.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func showHotkeys() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        alert.informativeText = """
        ⌘⌃⌥P - Pause Tracking
        ⌘⌃⌥R - Resume Tracking
        ⌘⌃⌥T - Generate Timelapse
        ⌘⌃⌥Q - Quit Application
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Utility Methods
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func updateMenuPeriodically() {
        // Update menu every 30 seconds to reflect current metrics
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateMenu()
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