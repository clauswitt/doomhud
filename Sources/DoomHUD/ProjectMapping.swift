import Foundation

struct ProjectMapping: Codable, Identifiable {
    let id = UUID()
    let fullPath: String
    var customTitle: String?
    var isActive: Bool = true
    let dateAdded: Date = Date()
    
    var displayName: String {
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        // Extract folder name from full path
        return URL(fileURLWithPath: fullPath).lastPathComponent
    }
    
    var folderName: String {
        return URL(fileURLWithPath: fullPath).lastPathComponent
    }
    
    var parentPath: String {
        return URL(fileURLWithPath: fullPath).deletingLastPathComponent().path
    }
}

class ProjectMappingManager: ObservableObject {
    @Published var projectMappings: [ProjectMapping] = []
    
    private let userDefaults = UserDefaults.standard
    private let mappingsKey = "DoomHUD_ProjectMappings"
    
    init() {
        loadMappings()
    }
    
    func addProject(at path: String) -> ProjectMapping {
        // Check if project already exists
        if let existing = projectMappings.first(where: { $0.fullPath == path }) {
            return existing
        }
        
        let mapping = ProjectMapping(fullPath: path)
        projectMappings.append(mapping)
        saveMappings()
        
        print("📁 Added project mapping: \(mapping.displayName) at \(path)")
        return mapping
    }
    
    func updateCustomTitle(for path: String, title: String?) {
        if let index = projectMappings.firstIndex(where: { $0.fullPath == path }) {
            projectMappings[index] = ProjectMapping(
                fullPath: projectMappings[index].fullPath,
                customTitle: title,
                isActive: projectMappings[index].isActive
            )
            saveMappings()
            
            print("📝 Updated project title: \(path) -> \(title ?? "default")")
        }
    }
    
    func getDisplayName(for path: String) -> String {
        if let mapping = projectMappings.first(where: { $0.fullPath == path }) {
            return mapping.displayName
        }
        
        // Auto-add new project and return folder name
        let mapping = addProject(at: path)
        return mapping.displayName
    }
    
    func toggleProjectActive(for path: String) {
        if let index = projectMappings.firstIndex(where: { $0.fullPath == path }) {
            var mapping = projectMappings[index]
            mapping = ProjectMapping(
                fullPath: mapping.fullPath,
                customTitle: mapping.customTitle,
                isActive: !mapping.isActive
            )
            projectMappings[index] = mapping
            saveMappings()
        }
    }
    
    func removeProject(for path: String) {
        projectMappings.removeAll { $0.fullPath == path }
        saveMappings()
        
        print("🗑️ Removed project mapping: \(path)")
    }
    
    private func saveMappings() {
        do {
            let data = try JSONEncoder().encode(projectMappings)
            userDefaults.set(data, forKey: mappingsKey)
            print("💾 Saved \(projectMappings.count) project mappings")
        } catch {
            print("❌ Failed to save project mappings: \(error)")
        }
    }
    
    private func loadMappings() {
        guard let data = userDefaults.data(forKey: mappingsKey) else {
            print("📂 No existing project mappings found")
            return
        }
        
        do {
            projectMappings = try JSONDecoder().decode([ProjectMapping].self, from: data)
            print("📂 Loaded \(projectMappings.count) project mappings")
        } catch {
            print("❌ Failed to load project mappings: \(error)")
            projectMappings = []
        }
    }
}