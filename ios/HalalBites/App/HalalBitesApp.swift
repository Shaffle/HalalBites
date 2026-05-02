import SwiftUI

@main
struct HalalBitesApp: App {
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(locationService)
                .onAppear {
                    locationService.requestPermission()
                }
        }
    }
}
