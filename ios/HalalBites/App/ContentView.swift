import SwiftUI

struct ContentView: View {
    @AppStorage("lightsOn") private var lightsOn = true
    @State private var showSideMenu = false
    @State private var itineraries: [Itinerary] = []
    @State private var favouriteIDs: Set<UUID> = []
    @State private var archivedItineraries: [Itinerary] = []
    @State private var recentlyDeleted: [Itinerary] = []

    var body: some View {
        ZStack {
            TabView {
                ExploreMapView(itineraries: $itineraries)
                    .tabItem {
                        Label("Explore", systemImage: "mappin.and.ellipse")
                    }

                ItineraryListView(
                    itineraries: $itineraries,
                    showSideMenu: $showSideMenu,
                    favouriteIDs: $favouriteIDs,
                    archivedItineraries: $archivedItineraries,
                    recentlyDeleted: $recentlyDeleted
                )
                .tabItem {
                    Label("Itineraries", systemImage: "map")
                }
            }
            .disabled(showSideMenu)

            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu = false
                        }
                    }
                    .zIndex(1)
            }

            SideMenuView(
                isShowing: $showSideMenu,
                itineraries: $itineraries,
                archivedItineraries: $archivedItineraries,
                recentlyDeleted: $recentlyDeleted,
                favouriteIDs: $favouriteIDs,
                onRestore: restoreItinerary
            )
            .zIndex(2)
        }
        .preferredColorScheme(lightsOn ? .light : .dark)
    }

    private func restoreItinerary(_ itinerary: Itinerary) {
        archivedItineraries.removeAll { $0.id == itinerary.id }
        recentlyDeleted.removeAll { $0.id == itinerary.id }
        if !itineraries.contains(where: { $0.id == itinerary.id }) {
            itineraries.insert(itinerary, at: 0)
        }
    }
}
