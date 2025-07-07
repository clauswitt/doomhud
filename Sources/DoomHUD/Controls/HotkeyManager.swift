import Foundation
import Carbon
import AppKit

struct ModifierKey: OptionSet, Codable {
    let rawValue: UInt32
    
    static let command = ModifierKey(rawValue: UInt32(cmdKey))
    static let shift = ModifierKey(rawValue: UInt32(shiftKey))
    static let option = ModifierKey(rawValue: UInt32(optionKey))
    static let control = ModifierKey(rawValue: UInt32(controlKey))
}

struct HotkeyConfig: Codable {
    let keyCode: Int
    let modifiers: ModifierKey
    
    var displayString: String {
        var result = ""
        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.control) { result += "⌃" }
        
        switch keyCode {
        case kVK_ANSI_P: result += "P"
        case kVK_ANSI_R: result += "R"
        case kVK_ANSI_T: result += "T"
        case kVK_ANSI_Q: result += "Q"
        case kVK_ANSI_S: result += "S"
        case kVK_ANSI_O: result += "O"
        default: result += "?"
        }
        
        return result
    }
}

class HotkeyManager: ObservableObject {
    @Published var isEnabled: Bool = true
    
    private var hotkeys: [String: EventHotKeyRef] = [:]
    private var hotkeyActions: [String: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    
    // Configurable hotkey combinations
    private var hotkeyConfigs: [String: HotkeyConfig] = [:]
    
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
            // Find the hotkey by signature and id
            for (hotkeyId, _) in hotkeys {
                var testHotkeyID = EventHotKeyID()
                switch hotkeyId {
                case "pause":
                    testHotkeyID.signature = OSType(0x50415553)
                    testHotkeyID.id = 1
                case "screenshot":
                    testHotkeyID.signature = OSType(0x53484F54)
                    testHotkeyID.id = 2
                case "openfolder":
                    testHotkeyID.signature = OSType(0x4F50454E)
                    testHotkeyID.id = 3
                case "quit":
                    testHotkeyID.signature = OSType(0x51554954)
                    testHotkeyID.id = 4
                default:
                    continue
                }
                
                if hotkeyID.signature == testHotkeyID.signature && hotkeyID.id == testHotkeyID.id {
                    if let action = hotkeyActions[hotkeyId] {
                        print("🔥 Executing hotkey action: \(hotkeyId)")
                        DispatchQueue.main.async {
                            action()
                        }
                        return noErr
                    }
                }
            }
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    func registerHotkeys(
        pauseConfig: HotkeyConfig, pauseAction: @escaping () -> Void,
        screenshotConfig: HotkeyConfig, screenshotAction: @escaping () -> Void,
        openFolderConfig: HotkeyConfig, openFolderAction: @escaping () -> Void,
        quitConfig: HotkeyConfig, quitAction: @escaping () -> Void
    ) {
        // Clear existing hotkeys
        unregisterAllHotkeys()
        
        // Store configurations
        hotkeyConfigs["pause"] = pauseConfig
        hotkeyConfigs["screenshot"] = screenshotConfig
        hotkeyConfigs["openfolder"] = openFolderConfig
        hotkeyConfigs["quit"] = quitConfig
        
        // Register new hotkeys
        registerHotkey(id: "pause", config: pauseConfig, action: pauseAction)
        registerHotkey(id: "screenshot", config: screenshotConfig, action: screenshotAction)
        registerHotkey(id: "openfolder", config: openFolderConfig, action: openFolderAction)
        registerHotkey(id: "quit", config: quitConfig, action: quitAction)
    }
    
    private func registerHotkey(id: String, config: HotkeyConfig, action: @escaping () -> Void) {
        
        var hotkeyID = EventHotKeyID()
        // Use simple, unique signatures based on the id string
        switch id {
        case "pause":
            hotkeyID.signature = OSType(0x50415553) // 'PAUS'
            hotkeyID.id = 1
        case "screenshot":
            hotkeyID.signature = OSType(0x53484F54) // 'SHOT'
            hotkeyID.id = 2
        case "openfolder":
            hotkeyID.signature = OSType(0x4F50454E) // 'OPEN'
            hotkeyID.id = 3
        case "quit":
            hotkeyID.signature = OSType(0x51554954) // 'QUIT'
            hotkeyID.id = 4
        default:
            hotkeyID.signature = OSType(0x44454641) // 'DEFA'
            hotkeyID.id = 99
        }
        
        print("🔧 Registering hotkey '\(id)' with signature: \(String(format: "0x%08X", hotkeyID.signature)), id: \(hotkeyID.id)")
        
        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(config.keyCode),
            config.modifiers.rawValue,
            hotkeyID,
            GetEventMonitorTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr, let hotkeyRef = hotkeyRef {
            hotkeys[id] = hotkeyRef
            hotkeyActions[id] = action  // Use the id directly as key
            print("✅ Registered hotkey: \(id)")
        } else {
            print("Failed to register hotkey: \(id), status: \(status)")
        }
    }
    
    private func unregisterAllHotkeys() {
        for (id, hotkeyRef) in hotkeys {
            UnregisterEventHotKey(hotkeyRef)
            print("🗑️ Unregistered hotkey: \(id)")
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
    
    func getAllHotkeys() -> [String: String] {
        return [
            "Pause Tracking": hotkeyConfigs["pause"]?.displayString ?? "Not configured",
            "Take Screenshot": hotkeyConfigs["screenshot"]?.displayString ?? "Not configured", 
            "Open Screenshots": hotkeyConfigs["openfolder"]?.displayString ?? "Not configured",
            "Quit Application": hotkeyConfigs["quit"]?.displayString ?? "Not configured"
        ]
    }
}