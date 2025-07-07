import Foundation
import ApplicationServices
import AVFoundation
import AppKit

class PermissionManager: ObservableObject {
    @Published var hasAccessibilityPermission = false
    @Published var hasInputMonitoringPermission = false
    @Published var hasCameraPermission = false
    @Published var hasScreenRecordingPermission = false
    
    init() {
        checkAllPermissions()
    }
    
    func checkAllPermissions() {
        checkAccessibilityPermission()
        checkInputMonitoringPermission()
        checkCameraPermission()
        checkScreenRecordingPermission()
    }
    
    // MARK: - Accessibility Permission
    
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // MARK: - Input Monitoring Permission
    
    func checkInputMonitoringPermission() {
        // Create a temporary event tap to check if we have permission
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            hasInputMonitoringPermission = false
            return
        }
        
        hasInputMonitoringPermission = true
        CFMachPortInvalidate(eventTap)
    }
    
    func requestInputMonitoringPermission() {
        // Opening Security & Privacy preferences will prompt user
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Camera Permission
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            hasCameraPermission = false
        case .denied, .restricted:
            hasCameraPermission = false
        @unknown default:
            hasCameraPermission = false
        }
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.hasCameraPermission = granted
            }
        }
    }
    
    // MARK: - Screen Recording Permission
    
    func checkScreenRecordingPermission() {
        // Create a small CGImage to test screen recording permission
        let displayID = CGMainDisplayID()
        let imageRef = CGDisplayCreateImage(displayID)
        hasScreenRecordingPermission = (imageRef != nil)
    }
    
    func requestScreenRecordingPermission() {
        // Opening Security & Privacy preferences will prompt user
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Permission Status
    
    var allPermissionsGranted: Bool {
        return hasAccessibilityPermission && 
               hasInputMonitoringPermission && 
               hasCameraPermission && 
               hasScreenRecordingPermission
    }
    
    var missingPermissions: [String] {
        var missing: [String] = []
        
        if !hasAccessibilityPermission {
            missing.append("Accessibility")
        }
        if !hasInputMonitoringPermission {
            missing.append("Input Monitoring")
        }
        if !hasCameraPermission {
            missing.append("Camera")
        }
        if !hasScreenRecordingPermission {
            missing.append("Screen Recording")
        }
        
        return missing
    }
    
    func requestAllPermissions() {
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
        }
        if !hasInputMonitoringPermission {
            requestInputMonitoringPermission()
        }
        if !hasCameraPermission {
            requestCameraPermission()
        }
        if !hasScreenRecordingPermission {
            requestScreenRecordingPermission()
        }
    }
}