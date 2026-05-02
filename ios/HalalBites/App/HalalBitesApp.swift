import SwiftUI

@main
struct HalalBitesApp: App {
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
                .environmentObject(APIClient())
                .onAppear {
                    // Request on launch so permission dialog fires immediately
                    locationService.requestPermission()
                }
        }
    }
}
