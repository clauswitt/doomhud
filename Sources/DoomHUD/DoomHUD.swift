import SwiftUI
import AppKit

@main
struct DoomHUDSimpleApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var appDelegate = AppDelegate()
    
    init() {
        print("🎮 DoomHUD Starting...")
        
        // Keep app running as background utility
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        WindowGroup {
            SimpleHUDView()
                .environmentObject(appState)
                .onAppear {
                    NSApplication.shared.delegate = appDelegate
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running
    }
}

class AppState: ObservableObject {
    @Published var isRunning = true
    @Published var mouseClicks = 0
    @Published var keystrokes = 0
    @Published var sessionTime = "00:00"
    
    private var startTime = Date()
    private var timer: Timer?
    
    init() {
        startTimer()
        print("✅ AppState initialized")
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateSessionTime()
        }
    }
    
    private func updateSessionTime() {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        sessionTime = String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SimpleHUDView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 800, height: 120)
                .border(Color.green, width: 2)
            
            HStack(spacing: 20) {
                // Left panel
                VStack(alignment: .leading, spacing: 4) {
                    Text("DOOM HUD v1.0")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text("Session: \(appState.sessionTime)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.yellow)
                    
                    Text("Status: ACTIVE")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .frame(width: 200, alignment: .leading)
                
                Spacer()
                
                // Center - Webcam placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .border(Color.gray, width: 1)
                    .overlay(
                        VStack {
                            Text("CAM")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("READY")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    )
                
                Spacer()
                
                // Right panel
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("METRICS")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    Text("Mouse: \(appState.mouseClicks)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red)
                    
                    Text("Keys: \(appState.keystrokes)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    Text("Git: 0")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.purple)
                }
                .frame(width: 200, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            print("🎯 HUD View appeared")
            positionWindow()
        }
    }
    
    private func positionWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let windowWidth: CGFloat = 800
                    let windowHeight: CGFloat = 120
                    
                    let x = screenFrame.midX - (windowWidth / 2)
                    let y = screenFrame.minY + (screenFrame.height * 0.1)
                    
                    window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
                    window.level = .floating
                    window.collectionBehavior = [.canJoinAllSpaces, .stationary]
                    
                    print("✅ Window positioned at bottom of screen")
                }
            }
        }
    }
}