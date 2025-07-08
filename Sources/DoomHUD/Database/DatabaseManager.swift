import Foundation
import SQLite

class DatabaseManager: ObservableObject {
    private var db: Connection?
    private let dbPath: String
    
    // Tables
    private let metricsTable = Table("metrics")
    private let sessionsTable = Table("sessions")
    private let screenshotsTable = Table("screenshots")
    private let timelapsesTable = Table("timelapses")
    private let preferencesTable = Table("preferences")
    
    // Metrics columns
    private let metricId = Expression<String>("id")
    private let metricTimestamp = Expression<Date>("timestamp")
    private let mouseClicks = Expression<Int>("mouse_clicks")
    private let keystrokes = Expression<Int>("keystrokes")
    private let contextShifts = Expression<Int>("context_shifts")
    private let gitCommits = Expression<Int>("git_commits")
    private let sessionId = Expression<String>("session_id")
    private let isActive = Expression<Bool>("is_active")
    
    // Sessions columns
    private let sessionIdCol = Expression<String>("id")
    private let startTime = Expression<Date>("start_time")
    private let endTime = Expression<Date?>("end_time")
    private let dayOfWeek = Expression<Int>("day_of_week")
    private let totalMouseClicks = Expression<Int>("total_mouse_clicks")
    private let totalKeystrokes = Expression<Int>("total_keystrokes")
    private let totalContextShifts = Expression<Int>("total_context_shifts")
    private let totalGitCommits = Expression<Int>("total_git_commits")
    private let screenshotCount = Expression<Int>("screenshot_count")
    private let activeMinutes = Expression<Int>("active_minutes")
    
    // Screenshots columns
    private let screenshotId = Expression<String>("id")
    private let screenshotTimestamp = Expression<Date>("timestamp")
    private let filePath = Expression<String>("file_path")
    private let screenshotSessionId = Expression<String>("session_id")
    private let isMotionDetected = Expression<Bool>("is_motion_detected")
    private let fileSize = Expression<Int64>("file_size")
    
    // Timelapses columns
    private let timelapseId = Expression<String>("id")
    private let timelapseTimestamp = Expression<Date>("timestamp")
    private let timelapseFilePath = Expression<String>("file_path")
    private let timelapseSessionId = Expression<String>("session_id")
    private let duration = Expression<Double>("duration")
    private let frameCount = Expression<Int>("frame_count")
    private let timelapseFileSize = Expression<Int64>("file_size")
    
    // Preferences columns
    private let prefKey = Expression<String>("key")
    private let prefValue = Expression<String>("value")
    
    init() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let doomHudDir = appSupportDir.appendingPathComponent("DoomHUD")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: doomHudDir, withIntermediateDirectories: true)
        
        self.dbPath = doomHudDir.appendingPathComponent("database.sqlite").path
        
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            db = try Connection(dbPath)
            createTables()
        } catch {
            print("Database setup failed: \(error)")
        }
    }
    
    private func createTables() {
        guard let db = db else { return }
        
        do {
            // Create metrics table
            try db.run(metricsTable.create(ifNotExists: true) { t in
                t.column(metricId, primaryKey: true)
                t.column(metricTimestamp)
                t.column(mouseClicks)
                t.column(keystrokes)
                t.column(contextShifts)
                t.column(gitCommits)
                t.column(sessionId)
                t.column(isActive)
            })
            
            // Create sessions table
            try db.run(sessionsTable.create(ifNotExists: true) { t in
                t.column(sessionIdCol, primaryKey: true)
                t.column(startTime)
                t.column(endTime)
                t.column(dayOfWeek)
                t.column(totalMouseClicks)
                t.column(totalKeystrokes)
                t.column(totalContextShifts)
                t.column(totalGitCommits)
                t.column(screenshotCount)
                t.column(activeMinutes)
            })
            
            // Create screenshots table
            try db.run(screenshotsTable.create(ifNotExists: true) { t in
                t.column(screenshotId, primaryKey: true)
                t.column(screenshotTimestamp)
                t.column(filePath)
                t.column(screenshotSessionId)
                t.column(isMotionDetected)
                t.column(fileSize)
            })
            
            // Create timelapses table
            try db.run(timelapsesTable.create(ifNotExists: true) { t in
                t.column(timelapseId, primaryKey: true)
                t.column(timelapseTimestamp)
                t.column(timelapseFilePath)
                t.column(timelapseSessionId)
                t.column(duration)
                t.column(frameCount)
                t.column(timelapseFileSize)
            })
            
            // Create preferences table
            try db.run(preferencesTable.create(ifNotExists: true) { t in
                t.column(prefKey, primaryKey: true)
                t.column(prefValue)
            })
            
        } catch {
            print("Table creation failed: \(error)")
        }
    }
    
    // MARK: - Metrics Operations
    
    func saveMetric(_ metric: MetricData) {
        guard let db = db else { return }
        
        do {
            try db.run(metricsTable.insert(
                metricId <- metric.id.uuidString,
                metricTimestamp <- metric.timestamp,
                mouseClicks <- metric.mouseClicks,
                keystrokes <- metric.keystrokes,
                contextShifts <- metric.contextShifts,
                gitCommits <- metric.gitCommits,
                sessionId <- metric.sessionId.uuidString,
                isActive <- metric.isActive
            ))
        } catch {
            print("Failed to save metric: \(error)")
        }
    }
    
    func getMetricsForSession(_ sessionId: UUID) -> [MetricData] {
        guard let db = db else { return [] }
        
        do {
            let query = metricsTable.filter(self.sessionId == sessionId.uuidString)
            let rows = try db.prepare(query)
            
            return rows.compactMap { row in
                guard let id = UUID(uuidString: row[metricId]),
                      let sessionUUID = UUID(uuidString: row[self.sessionId]) else { return nil }
                
                return MetricData(
                    mouseClicks: row[mouseClicks],
                    keystrokes: row[keystrokes],
                    contextShifts: row[contextShifts],
                    gitCommits: row[gitCommits],
                    sessionId: sessionUUID,
                    isActive: row[isActive]
                )
            }
        } catch {
            print("Failed to get metrics: \(error)")
            return []
        }
    }
    
    // MARK: - Session Operations
    
    func saveSession(_ session: Session) {
        guard let db = db else { return }
        
        do {
            try db.run(sessionsTable.insert(or: .replace,
                sessionIdCol <- session.id.uuidString,
                startTime <- session.startTime,
                endTime <- session.endTime,
                dayOfWeek <- session.dayOfWeek,
                totalMouseClicks <- session.totalMouseClicks,
                totalKeystrokes <- session.totalKeystrokes,
                totalContextShifts <- session.totalContextShifts,
                totalGitCommits <- session.totalGitCommits,
                screenshotCount <- session.screenshotCount,
                activeMinutes <- session.activeMinutes
            ))
        } catch {
            print("Failed to save session: \(error)")
        }
    }
    
    func getCurrentSession() -> Session? {
        guard let db = db else { return nil }
        
        do {
            let query = sessionsTable.filter(endTime == nil).limit(1)
            let rows = try db.prepare(query)
            
            for row in rows {
                guard UUID(uuidString: row[sessionIdCol]) != nil else { continue }
                
                var session = Session()
                return session
            }
            
            return nil
        } catch {
            print("Failed to get current session: \(error)")
            return nil
        }
    }
    
    // MARK: - Screenshot Operations
    
    func saveScreenshot(_ screenshot: Screenshot) {
        guard let db = db else { return }
        
        do {
            try db.run(screenshotsTable.insert(
                screenshotId <- screenshot.id.uuidString,
                screenshotTimestamp <- screenshot.timestamp,
                filePath <- screenshot.filePath,
                screenshotSessionId <- screenshot.sessionId.uuidString,
                isMotionDetected <- screenshot.isMotionDetected,
                fileSize <- screenshot.fileSize
            ))
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }
    
    func getScreenshotsForSession(_ sessionId: UUID) -> [Screenshot] {
        guard let db = db else { return [] }
        
        do {
            let query = screenshotsTable.filter(screenshotSessionId == sessionId.uuidString)
            let rows = try db.prepare(query)
            
            return rows.compactMap { row in
                guard let _ = UUID(uuidString: row[screenshotId]),
                      let sessionUUID = UUID(uuidString: row[screenshotSessionId]) else { return nil }
                
                return Screenshot(
                    filePath: row[filePath],
                    sessionId: sessionUUID,
                    isMotionDetected: row[isMotionDetected],
                    fileSize: row[fileSize]
                )
            }
        } catch {
            print("Failed to get screenshots: \(error)")
            return []
        }
    }
    
    // MARK: - Preferences Operations
    
    func savePreferences(_ preferences: UserPreferences) {
        guard let db = db else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(preferences)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            
            try db.run(preferencesTable.insert(or: .replace,
                prefKey <- "user_preferences",
                prefValue <- jsonString
            ))
        } catch {
            print("Failed to save preferences: \(error)")
        }
    }
    
    func loadPreferences() -> UserPreferences {
        guard let db = db else { return UserPreferences.default }
        
        do {
            let query = preferencesTable.filter(prefKey == "user_preferences")
            let rows = try db.prepare(query)
            
            for row in rows {
                let jsonString = row[prefValue]
                if let data = jsonString.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let preferences = try decoder.decode(UserPreferences.self, from: data)
                    return preferences
                }
            }
            
            return UserPreferences.default
        } catch {
            print("Failed to load preferences: \(error)")
            return UserPreferences.default
        }
    }
    
    // MARK: - Timelapse Operations
    
    func saveTimelapse(_ timelapse: TimelapseVideo) {
        guard let db = db else { return }
        
        do {
            try db.run(timelapsesTable.insert(
                timelapseId <- timelapse.id.uuidString,
                timelapseTimestamp <- timelapse.timestamp,
                timelapseFilePath <- timelapse.filePath,
                timelapseSessionId <- timelapse.sessionId.uuidString,
                duration <- timelapse.duration,
                frameCount <- timelapse.frameCount,
                timelapseFileSize <- timelapse.fileSize
            ))
        } catch {
            print("Failed to save timelapse: \(error)")
        }
    }
    
    func getTimelapsesForSession(_ sessionId: UUID) -> [TimelapseVideo] {
        guard let db = db else { return [] }
        
        do {
            let query = timelapsesTable.filter(timelapseSessionId == sessionId.uuidString)
            let rows = try db.prepare(query)
            
            return rows.compactMap { row in
                guard let _ = UUID(uuidString: row[timelapseId]),
                      let sessionUUID = UUID(uuidString: row[timelapseSessionId]) else { return nil }
                
                return TimelapseVideo(
                    filePath: row[timelapseFilePath],
                    sessionId: sessionUUID,
                    duration: row[duration],
                    frameCount: row[frameCount],
                    fileSize: row[timelapseFileSize]
                )
            }
        } catch {
            print("Failed to get timelapses: \(error)")
            return []
        }
    }
    
    // MARK: - Time-based Metric Queries
    
    func getMetricsForToday() -> MetricValues {
        guard let db = db else { return .zero }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        return getMetricsForDateRange(from: startOfDay, to: Date())
    }
    
    func getMetricsForCurrentWeek() -> MetricValues {
        guard let db = db else { return .zero }
        
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return .zero
        }
        
        return getMetricsForDateRange(from: weekInterval.start, to: Date())
    }
    
    func getMetricsForDateRange(from startDate: Date, to endDate: Date) -> MetricValues {
        guard let db = db else { return .zero }
        
        do {
            // Get metrics within date range
            let metricsQuery = metricsTable.filter(
                metricTimestamp >= startDate && metricTimestamp <= endDate
            )
            
            var totalMouseClicks = 0
            var totalKeystrokes = 0
            var totalContextShifts = 0
            var totalGitCommits = 0
            
            // Sum up all metrics
            for row in try db.prepare(metricsQuery) {
                totalMouseClicks += row[mouseClicks]
                totalKeystrokes += row[keystrokes]
                totalContextShifts += row[contextShifts]
                totalGitCommits += row[gitCommits]
            }
            
            // Get screenshot count for date range
            let screenshotQuery = screenshotsTable.filter(
                screenshotTimestamp >= startDate && screenshotTimestamp <= endDate
            )
            let screenshotCount = try db.scalar(screenshotQuery.count)
            
            // Calculate duration from sessions
            let sessionQuery = sessionsTable.filter(
                startTime >= startDate || (endTime != nil && endTime >= startDate)
            )
            
            var totalDuration: TimeInterval = 0
            for row in try db.prepare(sessionQuery) {
                let sessionStart = max(row[startTime], startDate)
                let sessionEnd = row[endTime] ?? Date()
                let effectiveEnd = min(sessionEnd, endDate)
                
                if effectiveEnd > sessionStart {
                    totalDuration += effectiveEnd.timeIntervalSince(sessionStart)
                }
            }
            
            return MetricValues(
                mouseClicks: totalMouseClicks,
                keystrokes: totalKeystrokes,
                contextShifts: totalContextShifts,
                gitCommits: totalGitCommits,
                screenshots: screenshotCount,
                duration: totalDuration
            )
            
        } catch {
            print("Failed to get metrics for date range: \(error)")
            return .zero
        }
    }
    
    // Save current session metrics
    func saveCurrentMetrics(sessionId: UUID, metrics: MetricValues) {
        guard let db = db else { return }
        
        let metric = MetricData(
            mouseClicks: metrics.mouseClicks,
            keystrokes: metrics.keystrokes,
            contextShifts: metrics.contextShifts,
            gitCommits: metrics.gitCommits,
            sessionId: sessionId,
            isActive: true
        )
        
        saveMetric(metric)
    }
}