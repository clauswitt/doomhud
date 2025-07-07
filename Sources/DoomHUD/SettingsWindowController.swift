import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    convenience init(trackingManager: TrackingManager) {
        let hostingController = NSHostingController(rootView: SettingsView().environmentObject(trackingManager))
        let window = NSWindow(contentViewController: hostingController)
        
        self.init(window: window)
        
        window.title = "DoomHUD Settings"
        window.setContentSize(NSSize(width: 900, height: 700))
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
        case export = "Video Export"
        case hotkeys = "Hotkeys"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .projects: return "folder"
            case .permissions: return "lock"
            case .screenshots: return "camera"
            case .export: return "video"
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
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                
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
                case .export:
                    VideoExportSettingsView()
                case .hotkeys:
                    HotkeySettingsView()
                }
            }
            .environmentObject(trackingManager)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 700)
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

struct VideoExportSettingsView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    @StateObject private var videoExporter = VideoExporter()
    @State private var selectedDate: Date?
    @State private var fps: Int = UserDefaults.standard.object(forKey: "videoExportFPS") as? Int ?? 12
    @State private var quality: VideoExporter.ExportSettings.VideoQuality = {
        if let qualityString = UserDefaults.standard.string(forKey: "videoExportQuality"),
           let savedQuality = VideoExporter.ExportSettings.VideoQuality(rawValue: qualityString) {
            return savedQuality
        }
        return .medium
    }()
    @State private var resolution: VideoExporter.ExportSettings.VideoResolution = {
        if let resolutionString = UserDefaults.standard.string(forKey: "videoExportResolution"),
           let savedResolution = VideoExporter.ExportSettings.VideoResolution(rawValue: resolutionString) {
            return savedResolution
        }
        return .original
    }()
    @State private var showingExportProgress = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Video Export")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Export daily screenshots as MP4 timelapse videos with customizable settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
            
            GroupBox("Date Selection") {
                VStack(alignment: .leading, spacing: 12) {
                    let availableDates = videoExporter.getAvailableDates()
                    
                    if availableDates.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No screenshot data available")
                                .font(.headline)
                            Text("Screenshots will appear here once DoomHUD captures some data")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Select a date to export:")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            CalendarView(
                                availableDates: availableDates,
                                selectedDate: $selectedDate,
                                videoExporter: videoExporter
                            )
                            .frame(height: 200)
                        }
                        
                        if let selectedDate = selectedDate {
                            let screenshotCount = videoExporter.getScreenshotCount(for: selectedDate)
                            HStack {
                                Text("Selected: \(selectedDate, style: .date)")
                                    .font(.headline)
                                Spacer()
                                Text("\(screenshotCount) screenshots")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(12)
            }
            
            GroupBox("Export Settings") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Frames per second:")
                            .frame(width: 120, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(fps) },
                            set: { 
                                fps = Int($0)
                                UserDefaults.standard.set(fps, forKey: "videoExportFPS")
                            }
                        ), in: 1...60, step: 1)
                        Text("\(fps) fps")
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Video quality:")
                            .frame(width: 120, alignment: .leading)
                        Picker("Quality", selection: $quality) {
                            ForEach(VideoExporter.ExportSettings.VideoQuality.allCases, id: \.self) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: quality) { _, newValue in
                            UserDefaults.standard.set(newValue.rawValue, forKey: "videoExportQuality")
                        }
                    }
                    
                    HStack {
                        Text("Resolution:")
                            .frame(width: 120, alignment: .leading)
                        Picker("Resolution", selection: $resolution) {
                            ForEach(VideoExporter.ExportSettings.VideoResolution.allCases, id: \.self) { resolution in
                                Text(resolution.rawValue).tag(resolution)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: resolution) { _, newValue in
                            UserDefaults.standard.set(newValue.rawValue, forKey: "videoExportResolution")
                        }
                    }
                }
                .padding(12)
            }
            
            GroupBox("Export") {
                VStack(spacing: 12) {
                    if videoExporter.isExporting {
                        VStack(spacing: 8) {
                            ProgressView(value: videoExporter.exportProgress)
                            Text(videoExporter.exportStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Cancel Export") {
                                videoExporter.cancelExport()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Export Timelapse") {
                            guard let date = selectedDate else { return }
                            
                            let settings = VideoExporter.ExportSettings(
                                fps: fps,
                                quality: quality,
                                resolution: resolution
                            )
                            
                            Task {
                                await videoExporter.exportTimelapseForDate(date, settings: settings)
                                
                                // Auto-open Finder when export completes
                                if let lastVideo = videoExporter.lastExportedVideo {
                                    print("🔍 Auto-opening Finder for: \(lastVideo.path)")
                                    NSWorkspace.shared.activateFileViewerSelecting([lastVideo])
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedDate == nil)
                        
                        Text(videoExporter.exportStatus)
                            .font(.caption)
                            .foregroundColor(videoExporter.exportStatus.contains("failed") ? .red : .secondary)
                    }
                }
                .padding(12)
            }
            
            Spacer()
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // Set default selected date to the latest available date
            let availableDates = videoExporter.getAvailableDates()
            if let latestDate = availableDates.first {
                selectedDate = latestDate
            }
        }
    }
}

struct CalendarView: View {
    let availableDates: [Date]
    @Binding var selectedDate: Date?
    let videoExporter: VideoExporter
    
    @State private var currentMonth = Date()
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(availableDates: [Date], selectedDate: Binding<Date?>, videoExporter: VideoExporter) {
        self.availableDates = availableDates
        self._selectedDate = selectedDate
        self.videoExporter = videoExporter
        
        // Set current month to the latest available date's month
        if let latestDate = availableDates.first {
            self._currentMonth = State(initialValue: latestDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Month header with navigation
            HStack {
                Button(action: { moveMonth(-1) }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!hasPreviousMonth)
                
                Spacer()
                
                Text(currentMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { moveMonth(1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!hasNextMonth)
            }
            .padding(.horizontal)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast),
                            hasScreenshots: availableDates.contains { calendar.isDate($0, inSameDayAs: date) },
                            onTap: {
                                if availableDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
                                    selectedDate = date
                                }
                            }
                        )
                    } else {
                        // Empty cell for days not in current month
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private var hasPreviousMonth: Bool {
        availableDates.contains { calendar.dateInterval(of: .month, for: $0)?.start ?? Date() < calendar.dateInterval(of: .month, for: currentMonth)?.start ?? Date() }
    }
    
    private var hasNextMonth: Bool {
        availableDates.contains { calendar.dateInterval(of: .month, for: $0)?.start ?? Date() > calendar.dateInterval(of: .month, for: currentMonth)?.start ?? Date() }
    }
    
    private func moveMonth(_ direction: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: direction, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct DayView: View {
    let date: Date
    let isSelected: Bool
    let hasScreenshots: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(dayTextColor)
            
            // Dot indicator for days with screenshots
            Circle()
                .fill(hasScreenshots ? .blue : .clear)
                .frame(width: 4, height: 4)
        }
        .frame(width: 32, height: 32)
        .background(backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            if hasScreenshots {
                onTap()
            }
        }
        .opacity(hasScreenshots ? 1.0 : 0.3)
    }
    
    private var dayTextColor: Color {
        if isSelected {
            return .white
        } else if hasScreenshots {
            return .primary
        } else {
            return .secondary
        }
    }
    
    @ViewBuilder
    private var backgroundContent: some View {
        if isSelected {
            Color.blue
        } else if hasScreenshots {
            Color.blue.opacity(0.1)
        } else {
            Color.clear
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TrackingManager())
}