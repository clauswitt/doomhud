import Foundation

class GitTracker: ObservableObject {
    @Published var sessionCommits: Int = 0
    @Published var todayCommits: Int = 0
    @Published var weekCommits: Int = 0
    @Published var gitDirectories: [String] = []
    
    private var trackingTimer: Timer?
    private let fileManager = FileManager.default
    
    init() {
        loadGitDirectories()
        setupTrackingTimer()
        updateCommitCounts()
    }
    
    deinit {
        stopTracking()
    }
    
    private func loadGitDirectories() {
        if let data = UserDefaults.standard.data(forKey: "git_directories"),
           let directories = try? JSONDecoder().decode([String].self, from: data) {
            gitDirectories = directories
        }
    }
    
    private func saveGitDirectories() {
        if let data = try? JSONEncoder().encode(gitDirectories) {
            UserDefaults.standard.set(data, forKey: "git_directories")
        }
    }
    
    private func setupTrackingTimer() {
        // Check for new commits every 5 minutes
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateCommitCounts()
        }
    }
    
    func addGitDirectory(_ path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        // Verify it's a git repository
        if isGitRepository(at: expandedPath) {
            if !gitDirectories.contains(expandedPath) {
                gitDirectories.append(expandedPath)
                saveGitDirectories()
                updateCommitCounts()
            }
        }
    }
    
    func removeGitDirectory(_ path: String) {
        gitDirectories.removeAll { $0 == path }
        saveGitDirectories()
        updateCommitCounts()
    }
    
    private func isGitRepository(at path: String) -> Bool {
        let gitPath = "\(path)/.git"
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: gitPath, isDirectory: &isDirectory)
    }
    
    private func updateCommitCounts() {
        let today = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        var totalSessionCommits = 0
        var totalTodayCommits = 0
        var totalWeekCommits = 0
        
        for directory in gitDirectories {
            let sessionCommitsForRepo = getCommitCount(in: directory, since: GitAppState.shared.sessionStartTime)
            let todayCommitsForRepo = getCommitCount(in: directory, since: startOfDay)
            let weekCommitsForRepo = getCommitCount(in: directory, since: startOfWeek)
            
            totalSessionCommits += sessionCommitsForRepo
            totalTodayCommits += todayCommitsForRepo
            totalWeekCommits += weekCommitsForRepo
        }
        
        DispatchQueue.main.async {
            self.sessionCommits = totalSessionCommits
            self.todayCommits = totalTodayCommits
            self.weekCommits = totalWeekCommits
        }
    }
    
    private func getCommitCount(in directory: String, since date: Date) -> Int {
        let process = Process()
        process.currentDirectoryPath = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: date)
        
        process.arguments = [
            "log",
            "--oneline",
            "--since=\(dateString)",
            "--author=\(getCurrentGitUser(in: directory))"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Count non-empty lines
            let lines = output.components(separatedBy: .newlines)
            return lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        } catch {
            print("Error running git log: \(error)")
            return 0
        }
    }
    
    private func getCurrentGitUser(in directory: String) -> String {
        let process = Process()
        process.currentDirectoryPath = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "user.name"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }
    
    func startTracking() {
        if trackingTimer == nil {
            setupTrackingTimer()
        }
    }
    
    func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }
    
    func resetSessionCount() {
        sessionCommits = 0
    }
    
    func getSessionCount() -> Int {
        return sessionCommits
    }
}

// Simple app state to track session start time
class GitAppState {
    static let shared = GitAppState()
    let sessionStartTime = Date()
    
    private init() {}
}