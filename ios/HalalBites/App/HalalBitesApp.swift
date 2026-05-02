import SwiftUI

@main
struct HalalBitesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(LocationService())
                .environmentObject(APIClient())
        }
    }
}
