import Foundation
import Carbon
import AppKit

class HotkeyManager: ObservableObject {
    @Published var isEnabled: Bool = true
    
    private var hotkeys: [String: EventHotKeyRef] = [:]
    private var hotkeyActions: [String: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    
    // Default hotkey combinations
    private let defaultHotkeys = [
        "pause": (keyCode: kVK_ANSI_P, modifiers: UInt32(cmdKey | shiftKey)),
        "resume": (keyCode: kVK_ANSI_R, modifiers: UInt32(cmdKey | shiftKey)),
        "timelapse": (keyCode: kVK_ANSI_T, modifiers: UInt32(cmdKey | shiftKey)),
        "quit": (keyCode: kVK_ANSI_Q, modifiers: UInt32(cmdKey | shiftKey))
    ]
    
    init() {
        setupEventHandler()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupEventHandler() {
        let eventTypes = [UInt32(kEventClassKeyboard)]
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetEventMonitorTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return hotkeyManager.handleHotkeyEvent(event: event)
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )
    }
    
    private func handleHotkeyEvent(event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )
        
        if status == noErr {
            let signature = String(bytes: withUnsafeBytes(of: hotkeyID.signature) { Data($0) }, encoding: .ascii) ?? ""
            if let action = hotkeyActions[signature] {
                DispatchQueue.main.async {
                    action()
                }
                return noErr
            }
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    func registerHotkeys(
        pauseAction: @escaping () -> Void,
        resumeAction: @escaping () -> Void,
        timelapseAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        // Clear existing hotkeys
        unregisterAllHotkeys()
        
        // Register new hotkeys
        registerHotkey(id: "pause", action: pauseAction)
        registerHotkey(id: "resume", action: resumeAction)
        registerHotkey(id: "timelapse", action: timelapseAction)
        registerHotkey(id: "quit", action: quitAction)
    }
    
    private func registerHotkey(id: String, action: @escaping () -> Void) {
        guard let config = defaultHotkeys[id] else { return }
        
        var hotkeyID = EventHotKeyID()
        hotkeyID.signature = OSType(id.prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0).data(using: .ascii)?.withUnsafeBytes { $0.load(as: UInt32.self) } ?? 0)
        hotkeyID.id = UInt32(id.hashValue)
        
        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(config.keyCode),
            config.modifiers,
            hotkeyID,
            GetEventMonitorTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr, let hotkeyRef = hotkeyRef {
            let signature = String(bytes: withUnsafeBytes(of: hotkeyID.signature) { Data($0) }, encoding: .ascii) ?? ""
            hotkeys[id] = hotkeyRef
            hotkeyActions[signature] = action
            print("Registered hotkey: \(id)")
        } else {
            print("Failed to register hotkey: \(id), status: \(status)")
        }
    }
    
    private func unregisterAllHotkeys() {
        for (id, hotkeyRef) in hotkeys {
            UnregisterEventHotKey(hotkeyRef)
            print("Unregistered hotkey: \(id)")
        }
        hotkeys.removeAll()
        hotkeyActions.removeAll()
    }
    
    func enable() {
        isEnabled = true
    }
    
    func disable() {
        isEnabled = false
    }
    
    private func cleanup() {
        unregisterAllHotkeys()
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
    
    // MARK: - Hotkey Information
    
    func getHotkeyDescription(for action: String) -> String {
        guard let config = defaultHotkeys[action] else { return "Not configured" }
        
        var description = ""
        
        if config.modifiers & UInt32(cmdKey) != 0 {
            description += "⌘"
        }
        if config.modifiers & UInt32(shiftKey) != 0 {
            description += "⇧"
        }
        if config.modifiers & UInt32(optionKey) != 0 {
            description += "⌥"
        }
        if config.modifiers & UInt32(controlKey) != 0 {
            description += "⌃"
        }
        
        // Convert virtual key code to character
        let keyChar = getKeyCharacter(for: config.keyCode)
        description += keyChar
        
        return description
    }
    
    private func getKeyCharacter(for keyCode: Int) -> String {
        switch keyCode {
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_Q: return "Q"
        default: return "?"
        }
    }
    
    func getAllHotkeys() -> [String: String] {
        return [
            "Pause Tracking": getHotkeyDescription(for: "pause"),
            "Resume Tracking": getHotkeyDescription(for: "resume"),
            "Generate Timelapse": getHotkeyDescription(for: "timelapse"),
            "Quit Application": getHotkeyDescription(for: "quit")
        ]
    }
}