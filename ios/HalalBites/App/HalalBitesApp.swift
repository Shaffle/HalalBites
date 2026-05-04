import SwiftUI

@main
struct HalalBitesApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var notificationService = NotificationService()
    @State private var pendingItinerary: Itinerary?

    var body: some Scene {
        WindowGroup {
            SplashScreenView(pendingItinerary: $pendingItinerary)
                .environmentObject(locationService)
                .environmentObject(notificationService)
                .onAppear {
                    locationService.requestPermission()
                    notificationService.requestPermission()
                }
                .onOpenURL { url in
                    guard let code = ItineraryShareManager.parseShareCode(from: url) else { return }
                    Task {
                        if let itinerary = try? await CloudKitShareService.fetch(code: code) {
                            await MainActor.run {
                                pendingItinerary = itinerary
                            }
                        }
                    }
                }
        }
    }
}
