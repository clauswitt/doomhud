import Foundation
import os.log

struct DoomLogger {
    private static let subsystem = "com.clauswitt.doomhud"
    
    static let general = Logger(subsystem: subsystem, category: "general")
    static let tracking = Logger(subsystem: subsystem, category: "tracking")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let database = Logger(subsystem: subsystem, category: "database")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    static func logError(_ message: String, category: Logger = general) {
        category.error("\(message)")
        print("❌ ERROR: \(message)")
    }
    
    static func logInfo(_ message: String, category: Logger = general) {
        category.info("\(message)")
        print("ℹ️ INFO: \(message)")
    }
    
    static func logWarning(_ message: String, category: Logger = general) {
        category.warning("\(message)")
        print("⚠️ WARNING: \(message)")
    }
}