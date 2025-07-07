import Foundation

struct MetricData: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let mouseClicks: Int
    let keystrokes: Int
    let contextShifts: Int
    let gitCommits: Int
    let sessionId: UUID
    let isActive: Bool
    
    init(mouseClicks: Int, keystrokes: Int, contextShifts: Int, gitCommits: Int, sessionId: UUID, isActive: Bool) {
        self.timestamp = Date()
        self.mouseClicks = mouseClicks
        self.keystrokes = keystrokes
        self.contextShifts = contextShifts
        self.gitCommits = gitCommits
        self.sessionId = sessionId
        self.isActive = isActive
    }
}

struct Session: Codable, Identifiable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    let dayOfWeek: Int
    var totalMouseClicks: Int = 0
    var totalKeystrokes: Int = 0
    var totalContextShifts: Int = 0
    var totalGitCommits: Int = 0
    var screenshotCount: Int = 0
    var activeMinutes: Int = 0
    
    init() {
        self.startTime = Date()
        self.dayOfWeek = Calendar.current.component(.weekday, from: startTime)
    }
    
    mutating func end() {
        self.endTime = Date()
    }
}

struct Screenshot: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let filePath: String
    let sessionId: UUID
    let isMotionDetected: Bool
    let fileSize: Int64
    
    init(filePath: String, sessionId: UUID, isMotionDetected: Bool, fileSize: Int64) {
        self.timestamp = Date()
        self.filePath = filePath
        self.sessionId = sessionId
        self.isMotionDetected = isMotionDetected
        self.fileSize = fileSize
    }
}

struct UserPreferences: Codable {
    var gitDirectories: [String] = []
    var screenshotInterval: TimeInterval = 60.0
    var inactivityThreshold: TimeInterval = 300.0 // 5 minutes
    var motionSensitivity: Double = 0.1
    var enableWebcam: Bool = true
    var enableScreenshots: Bool = true
    var autoGenerateTimelapses: Bool = true
    var hotkeyPause: String = "cmd+shift+p"
    var hotkeyResume: String = "cmd+shift+r"
    var hotkeyTimelapse: String = "cmd+shift+t"
    var hotkeyQuit: String = "cmd+shift+q"
    
    static let `default` = UserPreferences()
}

struct TimelapseVideo: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let filePath: String
    let sessionId: UUID
    let duration: TimeInterval
    let frameCount: Int
    let fileSize: Int64
    
    init(filePath: String, sessionId: UUID, duration: TimeInterval, frameCount: Int, fileSize: Int64) {
        self.timestamp = Date()
        self.filePath = filePath
        self.sessionId = sessionId
        self.duration = duration
        self.frameCount = frameCount
        self.fileSize = fileSize
    }
}