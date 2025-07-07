import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    convenience init(trackingManager: TrackingManager) {
        let hostingController = NSHostingController(rootView: SettingsView().environmentObject(trackingManager))
        let window = NSWindow(contentViewController: hostingController)
        
        self.init(window: window)
        
        window.title = "DoomHUD Settings"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        
        // Make window look like a proper settings window
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.backgroundColor = NSColor.windowBackgroundColor
    }
    
    func showSettings() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case projects = "Projects" 
        case permissions = "Permissions"
        case screenshots = "Screenshots"
        case hotkeys = "Hotkeys"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .projects: return "folder"
            case .permissions: return "lock"
            case .screenshots: return "camera"
            case .hotkeys: return "keyboard"
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    HStack {
                        Image(systemName: tab.icon)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(tab.rawValue)
                            .font(.system(size: 14))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, maxWidth: 250)
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .projects:
                    ProjectSettingsView()
                case .permissions:
                    PermissionsSettingsView()
                case .screenshots:
                    ScreenshotSettingsView()
                case .hotkeys:
                    HotkeySettingsView()
                }
            }
            .environmentObject(trackingManager)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            GroupBox("Window Behavior") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Always on Top", isOn: $trackingManager.alwaysOnTop)
                        .onChange(of: trackingManager.alwaysOnTop) { _ in
                            updateWindowLevel()
                        }
                    
                    HStack {
                        Text("Window Opacity:")
                        Slider(value: $trackingManager.hudOpacity, in: 0.3...1.0, step: 0.05)
                        Text("\(Int(trackingManager.hudOpacity * 100))%")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Screenshot Interval:")
                        Slider(value: $trackingManager.screenshotInterval, in: 10...600, step: 10)
                            .onChange(of: trackingManager.screenshotInterval) { _, _ in
                                trackingManager.updateScreenshotInterval()
                            }
                        Text("\(Int(trackingManager.screenshotInterval))s")
                            .frame(width: 40)
                    }
                }
                .padding(12)
            }
            
            GroupBox("Tracking") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Status:")
                        Text(trackingManager.isTracking ? "Active" : "Paused")
                            .foregroundColor(trackingManager.isTracking ? .green : .red)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Session Duration:")
                        Text(trackingManager.sessionTime)
                            .fontWeight(.semibold)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(12)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func updateWindowLevel() {
        // This would need to communicate back to the HUD window
        // For now, just update the setting - the HUD will pick it up
        print("🪟 Always on top setting changed to: \(trackingManager.alwaysOnTop)")
    }
}

struct ProjectSettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    @State private var selectedProject: ProjectMapping?
    @State private var editingTitle: String = ""
    @State private var showingTitleEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Project Management")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            Text("Customize how project names are displayed in the HUD. Projects are automatically discovered from Git repositories.")
                .font(.body)
                .foregroundColor(.secondary)
            
            if trackingManager.projectMappingManager.projectMappings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No projects found yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Projects will appear here once Git repositories are discovered")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(trackingManager.projectMappingManager.projectMappings, id: \.id) { project in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.displayName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text(project.fullPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Spacer()
                            
                            Button("Edit") {
                                selectedProject = project
                                editingTitle = project.customTitle ?? ""
                                showingTitleEditor = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingTitleEditor) {
            if let project = selectedProject {
                ProjectTitleEditor(
                    project: project,
                    editingTitle: $editingTitle,
                    isPresented: $showingTitleEditor,
                    projectManager: trackingManager.projectMappingManager
                )
            }
        }
    }
}

struct ProjectTitleEditor: View {
    let project: ProjectMapping
    @Binding var editingTitle: String
    @Binding var isPresented: Bool
    let projectManager: ProjectMappingManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Project Title")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Path:")
                    .font(.headline)
                Text(project.fullPath)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                Text("Display Name:")
                    .font(.headline)
                TextField("Enter custom title (leave empty for folder name)", text: $editingTitle)
                    .textFieldStyle(.roundedBorder)
                
                Text("Current folder name: \(project.folderName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    let titleToSave = editingTitle.isEmpty ? nil : editingTitle
                    projectManager.updateCustomTitle(for: project.fullPath, title: titleToSave)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 500)
    }
}

struct PermissionsSettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Permissions Status")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            Text("DoomHUD requires several permissions to track your productivity metrics.")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Input Monitoring",
                    description: "Required to track mouse clicks and keystrokes",
                    isGranted: trackingManager.hasInputMonitoringPermission,
                    action: {
                        trackingManager.requestInputMonitoringPermission()
                    }
                )
                
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to monitor app switching and context changes",
                    isGranted: trackingManager.hasAccessibilityPermission,
                    action: {
                        trackingManager.requestAccessibilityPermission()
                    }
                )
                
                PermissionRow(
                    title: "Camera Access",
                    description: "Required for webcam feed and motion detection",
                    isGranted: trackingManager.hasCameraAccess,
                    action: {
                        trackingManager.requestCameraPermission()
                    }
                )
                
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture screenshots for timelapse",
                    isGranted: trackingManager.hasScreenRecordingPermission,
                    action: {
                        trackingManager.requestScreenRecordingPermission()
                    }
                )
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Button("Re-check All Permissions") {
                trackingManager.recheckAllPermissions()
            }
            .buttonStyle(.bordered)
            
            if !trackingManager.allPermissionsGranted {
                Text("Some permissions are missing. DoomHUD functionality will be limited until all permissions are granted.")
                    .font(.callout)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(isGranted ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isGranted {
                Button("Request") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("✓ Granted")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ScreenshotSettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Screenshot Settings")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            GroupBox("Screenshot Information") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Total Screenshots Taken:")
                        Spacer()
                        Text("\(trackingManager.screenshotCount)")
                            .fontWeight(.semibold)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if let lastTime = trackingManager.lastScreenshotTime {
                        HStack {
                            Text("Last Screenshot:")
                            Spacer()
                            Text(lastTime, style: .relative)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Interval:")
                        Spacer()
                        Text("\(Int(trackingManager.screenshotInterval)) seconds")
                            .fontWeight(.semibold)
                    }
                }
                .padding(12)
            }
            
            GroupBox("Storage Location") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Screenshots are saved to:")
                        .font(.headline)
                    
                    Text("~/Library/Application Support/DoomHUD/screenshots/")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    
                    Button("Open Screenshots Folder") {
                        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots")
                        NSWorkspace.shared.open(screenshotsDir)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
            }
            
            GroupBox("Screenshot Options") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("• Screenshots capture all visible windows")
                    Text("• Taken automatically at configurable intervals")
                    Text("• Organized by date in subfolders")
                    Text("• Include the HUD window for reference")
                    Text("• Interval can be adjusted from 10 seconds to 10 minutes")
                }
                .font(.body)
                .foregroundColor(.secondary)
                .padding(12)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HotkeySettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Hotkey Settings")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            Text("Global keyboard shortcuts for quick actions. These work when DoomHUD is running, even when other apps are active.")
                .font(.body)
                .foregroundColor(.secondary)
            
            GroupBox("Available Hotkeys") {
                VStack(spacing: 16) {
                    if let hotkeyManager = trackingManager.hotkeyManager {
                        let hotkeys = hotkeyManager.getAllHotkeys()
                        
                        HotkeyRow(
                            title: "Toggle Tracking", 
                            description: "Pause or resume all tracking",
                            hotkey: hotkeys["Pause Tracking"] ?? "⌘⇧P"
                        )
                        
                        HotkeyRow(
                            title: "Take Screenshot",
                            description: "Capture a screenshot immediately", 
                            hotkey: hotkeys["Resume Tracking"] ?? "⌘⇧R"
                        )
                        
                        HotkeyRow(
                            title: "Open Screenshots",
                            description: "Open screenshots folder in Finder",
                            hotkey: hotkeys["Generate Timelapse"] ?? "⌘⇧T"
                        )
                        
                        HotkeyRow(
                            title: "Quit DoomHUD",
                            description: "Exit the application completely",
                            hotkey: hotkeys["Quit Application"] ?? "⌘⇧Q"
                        )
                    } else {
                        Text("Hotkey system not initialized")
                            .foregroundColor(.orange)
                    }
                }
                .padding(16)
            }
            
            GroupBox("Hotkey Status") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(trackingManager.hotkeyManager?.isEnabled == true ? .green : .red)
                            .frame(width: 12, height: 12)
                        
                        Text("Hotkeys Enabled")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    if trackingManager.hotkeyManager?.isEnabled != true {
                        Text("Global hotkeys may require accessibility permissions to function properly.")
                            .font(.body)
                            .foregroundColor(.orange)
                    } else {
                        Text("All hotkeys are active and ready to use.")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                }
                .padding(12)
            }
            
            GroupBox("Notes") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Hotkeys work system-wide when DoomHUD is running")
                    Text("• Requires Accessibility permissions for proper function")
                    Text("• Key combinations are currently fixed but may be customizable in future versions")
                    Text("• Use ⌘⇧Q as emergency quit if the HUD becomes unresponsive")
                }
                .font(.body)
                .foregroundColor(.secondary)
                .padding(12)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HotkeyRow: View {
    let title: String
    let description: String
    let hotkey: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(hotkey)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(TrackingManager())
}