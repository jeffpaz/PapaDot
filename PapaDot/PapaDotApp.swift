import SwiftUI

@main
struct PapaDotApp: App {
    @State private var manager = GameManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
        }
    }
}
