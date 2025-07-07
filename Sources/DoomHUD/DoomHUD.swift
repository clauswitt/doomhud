import SwiftUI

@main
struct DoomHUDApp: App {
    @StateObject private var databaseManager = DatabaseManager()
    
    var body: some Scene {
        HUDWindowGroup {
            ContentView()
                .environmentObject(databaseManager)
        }
    }
}