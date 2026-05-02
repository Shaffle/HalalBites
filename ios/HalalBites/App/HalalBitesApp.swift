import SwiftUI

@main
struct HalalBitesApp: App {
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(locationService)
                .environmentObject(APIClient())
                .onAppear {
                    locationService.requestPermission()
                }
        }
    }
}
