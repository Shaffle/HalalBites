import SwiftUI

@main
struct HalalBitesApp: App {
    @StateObject private var locationService = LocationService()
    @State private var pendingItinerary: Itinerary?

    var body: some Scene {
        WindowGroup {
            SplashScreenView(pendingItinerary: $pendingItinerary)
                .environmentObject(locationService)
                .onAppear {
                    locationService.requestPermission()
                }
                .onOpenURL { url in
                    if let itinerary = ItineraryShareManager.itinerary(from: url) {
                        pendingItinerary = itinerary
                    }
                }
        }
    }
}
