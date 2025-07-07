import Foundation
import ApplicationServices

class MouseTracker: ObservableObject {
    @Published var leftClickCount: Int = 0
    @Published var rightClickCount: Int = 0
    @Published var totalClickCount: Int = 0
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    init() {
        setupEventTap()
    }
    
    deinit {
        stopTracking()
    }
    
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                
                let mouseTracker = Unmanaged<MouseTracker>.fromOpaque(refcon).takeUnretainedValue()
                mouseTracker.handleMouseEvent(type: type, event: event)
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func handleMouseEvent(type: CGEventType, event: CGEvent) {
        DispatchQueue.main.async {
            switch type {
            case .leftMouseDown:
                self.leftClickCount += 1
                self.totalClickCount += 1
            case .rightMouseDown:
                self.rightClickCount += 1
                self.totalClickCount += 1
            default:
                break
            }
        }
    }
    
    func startTracking() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    func stopTracking() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        CFMachPortInvalidate(eventTap)
        self.eventTap = nil
    }
    
    func resetCounters() {
        leftClickCount = 0
        rightClickCount = 0
        totalClickCount = 0
    }
    
    func getSessionCounts() -> (left: Int, right: Int, total: Int) {
        return (leftClickCount, rightClickCount, totalClickCount)
    }
}