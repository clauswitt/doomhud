import SwiftUI
import AVFoundation

struct ModernHUDView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    
    var body: some View {
        ZStack {
            // Semi-transparent background with blur
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .frame(width: 900, height: 160)
            
            // Main content
            HStack(spacing: 20) {
                // Left Panel - Input Metrics
                VStack(alignment: .leading, spacing: 8) {
                    Text("INPUT TRACKING")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        MetricRow(label: "Mouse Clicks", value: trackingManager.mouseClicks, color: .blue)
                        MetricRow(label: "Keystrokes", value: trackingManager.keystrokes, color: .green)
                        MetricRow(label: "Context Shifts", value: trackingManager.contextShifts, color: .orange)
                        MetricRow(label: "Git Commits", value: trackingManager.gitCommits, color: .purple)
                        
                        // Control buttons
                        HStack(spacing: 6) {
                            Button(action: { showPermissionsDialog() }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(trackingManager.allPermissionsGranted ? .green : .red)
                                        .frame(width: 8, height: 8)
                                    Text("Permissions")
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                            
                            Button("Settings") {
                                showSettingsDialog()
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                            
                            Button("Quit") {
                                NSApplication.shared.terminate(nil)
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(width: 280, alignment: .leading)
                
                Spacer()
                
                // Center - Webcam
                ModernWebcamView()
                    .environmentObject(trackingManager)
                
                Spacer()
                
                // Right Panel - Split into two sections
                HStack(spacing: 20) {
                    // Git Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GIT ACTIVITY")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last commit in:")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(trackingManager.lastCommitProject)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.purple)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Time since commit:")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(trackingManager.timeSinceLastCommit)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .frame(width: 140, alignment: .leading)
                    
                    // Session Info Section
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("SESSION")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Text("Duration")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(trackingManager.sessionTime)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Status")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(trackingManager.isTracking ? "Active" : "Paused")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(trackingManager.isTracking ? .green : .red)
                            }
                            
                            HStack {
                                Text("Camera")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(trackingManager.cameraStatus)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(trackingManager.hasCameraAccess ? .green : .red)
                            }
                            
                            HStack {
                                Text("Screenshots")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(trackingManager.screenshotCount)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(width: 140, alignment: .trailing)
                }
                .frame(width: 280, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 900, height: 160)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .opacity(trackingManager.hudOpacity)
        .onAppear {
            print("🎯 ModernHUDView appeared!")
            print("🎯 trackingManager exists: \(trackingManager != nil)")
            setupWindow()
        }
    }
    
    private func setupWindow() {
        print("🪟 Setting up HUD window...")
        
        // Try multiple times with longer delays for bundle apps
        for attempt in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.2) {
                if let window = NSApplication.shared.windows.first {
                    print("🪟 Found window on attempt \(attempt)")
                    self.configureWindow(window)
                    return
                } else {
                    print("🪟 No window found on attempt \(attempt)")
                }
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        print("🪟 Configuring window...")
        
        // Make sure window is visible first
        window.makeKeyAndOrderFront(nil)
        
        // Remove title bar and make completely borderless
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask = [.borderless] // Remove all window chrome
        window.isMovable = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        // Position at bottom center, floating above everything
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 450 // Center horizontally (half of 900)
            let y = screenFrame.minY + 50  // 50pts from bottom
            
            window.setFrame(NSRect(x: x, y: y, width: 900, height: 160), display: true)
            
            // Set window level with more aggressive floating
            if trackingManager.alwaysOnTop {
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
                window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            } else {
                window.level = .normal
                window.collectionBehavior = [.canJoinAllSpaces]
            }
            
            // Force window to front
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            
            // Debug window properties
            print("🪟 Window frame: \(window.frame)")
            print("🪟 Window level: \(window.level.rawValue)")
            print("🪟 Window visible: \(window.isVisible)")
            print("🪟 Window on screen: \(window.isOnActiveSpace)")
        }
        
        print("✅ HUD window configured")
    }
    
    private func showPermissionsDialog() {
        let alert = NSAlert()
        alert.messageText = "DoomHUD Permissions"
        
        var message = "Permission Status:\n\n"
        message += "🔐 Accessibility: \(trackingManager.hasAccessibilityPermission ? "✅ Granted" : "❌ Required")\n"
        message += "⌨️ Input Monitoring: \(trackingManager.hasInputMonitoringPermission ? "✅ Granted" : "❌ Required")\n"
        message += "📷 Camera: \(trackingManager.hasCameraAccess ? "✅ Granted" : "❌ Required")\n"
        message += "📸 Screen Recording: \(trackingManager.hasScreenRecordingPermission ? "✅ Granted" : "❌ Required")\n\n"
        
        if !trackingManager.allPermissionsGranted {
            message += "Click 'Request Missing' to grant permissions, or 'System Preferences' to open settings manually."
        } else {
            message += "All permissions granted! DoomHUD is fully functional."
        }
        
        alert.informativeText = message
        
        if !trackingManager.allPermissionsGranted {
            alert.addButton(withTitle: "Request Missing")
            alert.addButton(withTitle: "Re-check Permissions")
            alert.addButton(withTitle: "System Preferences")
        }
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        if !trackingManager.allPermissionsGranted {
            if response == .alertFirstButtonReturn {
                // Request missing permissions
                requestMissingPermissions()
            } else if response == .alertSecondButtonReturn {
                // Re-check permissions
                trackingManager.recheckAllPermissions()
                
                // Show updated status
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showPermissionsDialog()
                }
            } else if response == .alertThirdButtonReturn {
                // Open System Preferences
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func requestMissingPermissions() {
        if !trackingManager.hasAccessibilityPermission {
            trackingManager.requestAccessibilityPermission()
        }
        if !trackingManager.hasInputMonitoringPermission {
            trackingManager.requestInputMonitoringPermission()
        }
        if !trackingManager.hasCameraAccess {
            trackingManager.requestCameraPermission()
        }
        if !trackingManager.hasScreenRecordingPermission {
            trackingManager.requestScreenRecordingPermission()
        }
    }
    
    private func showSettingsDialog() {
        let alert = NSAlert()
        alert.messageText = "DoomHUD Settings"
        
        var message = "App Settings:\n\n"
        message += "Always on Top: \(trackingManager.alwaysOnTop ? "✅ Enabled" : "❌ Disabled")\n"
        message += "Window Opacity: \(Int(trackingManager.hudOpacity * 100))%\n\n"
        message += "Screenshots Directory:\n"
        message += "~/Library/Application Support/DoomHUD/screenshots\n\n"
        message += "Git Repositories Found: \(getGitRepoCount())\n"
        
        alert.informativeText = message
        
        alert.addButton(withTitle: "Toggle Always on Top")
        alert.addButton(withTitle: "Open Screenshots Folder")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Toggle always on top
            trackingManager.alwaysOnTop.toggle()
            updateWindowLevel()
            
            // Show updated settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showSettingsDialog()
            }
        } else if response == .alertSecondButtonReturn {
            // Open screenshots folder
            let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let screenshotsDir = appSupportDir.appendingPathComponent("DoomHUD/screenshots")
            NSWorkspace.shared.open(screenshotsDir)
        }
    }
    
    private func getGitRepoCount() -> Int {
        // This is a placeholder - we'd need to access the git repositories from TrackingManager
        return 0 // Will fix this later
    }
    
    private func updateWindowLevel() {
        guard let window = NSApplication.shared.windows.first else { return }
        
        if trackingManager.alwaysOnTop {
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.orderFrontRegardless()
            print("🪟 Window level updated: floating (level \(window.level.rawValue))")
        } else {
            window.level = .normal
            window.collectionBehavior = [.canJoinAllSpaces]
            print("🪟 Window level updated: normal")
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

struct ModernWebcamView: View {
    @EnvironmentObject var trackingManager: TrackingManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .frame(width: 140, height: 140)
            
            if trackingManager.hasCameraAccess,
               let cameraManager = trackingManager.getCameraManager(),
               cameraManager.isRunning {
                
                SimpleCameraPreview(captureSession: cameraManager.captureSession)
                    .frame(width: 132, height: 132)
                    .cornerRadius(6)
                
                // Active indicator
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .padding(6)
                    }
                    Spacer()
                }
            } else {
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Text(trackingManager.cameraStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

class SimpleCameraManager: ObservableObject {
    @Published var isRunning = false
    let captureSession = AVCaptureSession()
    
    private var videoInput: AVCaptureDeviceInput?
    
    func startCamera() {
        guard !isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Configure session
            self.captureSession.sessionPreset = .medium
            
            // Setup camera input
            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                print("❌ Failed to setup camera input")
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.videoInput = input
            }
            
            // Start session
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = true
                print("✅ Camera started")
            }
        }
    }
    
    func stopCamera() {
        guard isRunning else { return }
        
        captureSession.stopRunning()
        
        if let input = videoInput {
            captureSession.removeInput(input)
            videoInput = nil
        }
        
        isRunning = false
        print("🛑 Camera stopped")
    }
}

struct SimpleCameraPreview: NSViewRepresentable {
    let captureSession: AVCaptureSession
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        view.layer = previewLayer
        view.wantsLayer = true
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let previewLayer = nsView.layer as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = nsView.bounds
        }
    }
}

#Preview {
    ModernHUDView()
        .environmentObject(TrackingManager())
}