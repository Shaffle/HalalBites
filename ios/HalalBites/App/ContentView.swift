import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ItineraryListView()
                .tabItem {
                    Label("Itineraries", systemImage: "map")
                }

            ExploreMapView()
                .tabItem {
                    Label("Explore", systemImage: "mappin.and.ellipse")
                }
        }
    }
}
